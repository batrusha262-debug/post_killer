use super::*;
use post_killer_domain::{ApiKeyPlacement, KeyValue, RequestAuth};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpListener,
    task::JoinHandle,
};

fn request(url: String) -> RequestDefinition {
    RequestDefinition {
        id: "request-1".into(),
        name: "Local test".into(),
        method: RequestMethod::Get,
        url,
        query_params: vec![],
        headers: vec![],
        body: Body::Empty,
        auth: RequestAuth::None,
    }
}

async fn local_server(response: Vec<u8>) -> (String, JoinHandle<Vec<u8>>) {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap();
    let handle = tokio::spawn(async move {
        let (mut socket, _) = listener.accept().await.unwrap();
        let mut received = Vec::new();
        let mut buffer = [0_u8; 1024];
        let header_end = loop {
            let read = socket.read(&mut buffer).await.unwrap();
            assert_ne!(read, 0, "client closed before sending complete headers");
            received.extend_from_slice(&buffer[..read]);
            if let Some(position) = received.windows(4).position(|part| part == b"\r\n\r\n") {
                break position + 4;
            }
        };
        let headers = String::from_utf8_lossy(&received[..header_end]);
        let content_length = headers
            .lines()
            .find_map(|line| {
                let (name, value) = line.split_once(':')?;
                name.eq_ignore_ascii_case("content-length")
                    .then(|| value.trim().parse::<usize>().unwrap())
            })
            .unwrap_or(0);
        while received.len() < header_end + content_length {
            let read = socket.read(&mut buffer).await.unwrap();
            assert_ne!(read, 0, "client closed before sending complete body");
            received.extend_from_slice(&buffer[..read]);
        }
        socket.write_all(&response).await.unwrap();
        received
    });
    (format!("http://{address}"), handle)
}

#[tokio::test]
async fn executes_json_request_and_receives_response() {
    let response = b"HTTP/1.1 201 Created\r\nContent-Type: application/json\r\nContent-Length: 11\r\nConnection: close\r\n\r\n{\"ok\":true}".to_vec();
    let (url, server) = local_server(response).await;
    let mut request = request(url);
    request.method = RequestMethod::Post;
    request.query_params = vec![KeyValue {
        key: "page".into(),
        value: "one two".into(),
        enabled: true,
    }];
    request.headers = vec![KeyValue {
        key: "X-Test".into(),
        value: "present".into(),
        enabled: true,
    }];
    request.body = Body::Json {
        content: serde_json::json!({"sent": true}),
    };

    let payload = execute(request).await.unwrap();
    let received = String::from_utf8(server.await.unwrap()).unwrap();
    assert_eq!(payload.status, 201);
    assert_eq!(payload.body, br#"{"ok":true}"#);
    assert!(payload.effective_url.contains("page=one+two"));
    assert!(received.starts_with("POST /?page=one+two HTTP/1.1\r\n"));
    assert!(received.to_ascii_lowercase().contains("x-test: present"));
    assert!(
        received
            .to_ascii_lowercase()
            .contains("content-type: application/json")
    );
    assert!(received.ends_with(r#"{"sent":true}"#));
}

#[tokio::test]
async fn enforces_timeout() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap());
    let server = tokio::spawn(async move {
        let (_socket, _) = listener.accept().await.unwrap();
        tokio::time::sleep(Duration::from_millis(75)).await;
    });
    let options = ExecutionOptions {
        timeout: Duration::from_millis(15),
        ..ExecutionOptions::default()
    };
    let result = execute_with_options(request(url), options).await;
    server.await.unwrap();
    assert_eq!(result.unwrap_err(), ExecuteError::Timeout);
}

#[tokio::test]
async fn rejects_response_larger_than_limit() {
    let response =
        b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\nConnection: close\r\n\r\n12345".to_vec();
    let (url, server) = local_server(response).await;
    let options = ExecutionOptions {
        max_response_bytes: 4,
        ..ExecutionOptions::default()
    };
    let result = execute_with_options(request(url), options).await;
    server.await.unwrap();
    assert_eq!(
        result.unwrap_err(),
        ExecuteError::ResponseTooLarge { limit: 4 }
    );
}

#[tokio::test]
async fn rejects_invalid_input_before_transport() {
    assert_eq!(
        execute(request(String::new())).await.unwrap_err(),
        ExecuteError::InvalidRequest(ValidationError::EmptyUrl)
    );
}

#[tokio::test]
async fn executes_text_multipart_request() {
    let response =
        b"HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_vec();
    let (url, server) = local_server(response).await;
    let mut multipart = request(url);
    multipart.method = RequestMethod::Post;
    multipart.body = Body::Multipart {
        fields: vec![
            KeyValue {
                key: "name".into(),
                value: "Ada".into(),
                enabled: true,
            },
            KeyValue {
                key: "ignored".into(),
                value: "disabled".into(),
                enabled: false,
            },
        ],
    };

    let payload = execute(multipart).await.unwrap();
    let received = String::from_utf8(server.await.unwrap()).unwrap();

    assert_eq!(payload.status, 204);
    assert!(
        received
            .to_ascii_lowercase()
            .contains("content-type: multipart/form-data; boundary=")
    );
    assert!(received.contains("name=\"name\""));
    assert!(received.contains("Ada"));
    assert!(!received.contains("disabled"));
}

#[tokio::test]
async fn applies_basic_bearer_and_api_key_authentication() {
    let response =
        b"HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_vec();
    let (url, server) = local_server(response).await;
    let mut basic = request(url);
    basic.auth = RequestAuth::Basic {
        username: "ada".into(),
        password: "secret".into(),
    };
    execute(basic).await.unwrap();
    let received = String::from_utf8(server.await.unwrap()).unwrap();
    assert!(
        received
            .to_ascii_lowercase()
            .contains("authorization: basic ywrhonnly3jlda==")
    );

    let response =
        b"HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_vec();
    let (url, server) = local_server(response).await;
    let mut bearer = request(url);
    bearer.auth = RequestAuth::Bearer {
        token: "bearer-token".into(),
    };
    execute(bearer).await.unwrap();
    let received = String::from_utf8(server.await.unwrap()).unwrap();
    assert!(received.contains("authorization: Bearer bearer-token"));

    let response =
        b"HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_vec();
    let (url, server) = local_server(response).await;
    let mut api_key = request(url);
    api_key.auth = RequestAuth::ApiKey {
        key: "X-API-Key".into(),
        value: "api-secret".into(),
        placement: ApiKeyPlacement::Header,
    };
    execute(api_key).await.unwrap();
    let received = String::from_utf8(server.await.unwrap()).unwrap();
    assert!(
        received
            .to_ascii_lowercase()
            .contains("x-api-key: api-secret")
    );
}

#[tokio::test]
async fn user_defined_authentication_locations_win_over_generated_authentication() {
    let response =
        b"HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_vec();
    let (url, server) = local_server(response).await;
    let mut bearer_request = request(url);
    bearer_request.headers = vec![KeyValue {
        key: "Authorization".into(),
        value: "Custom scheme-value".into(),
        enabled: true,
    }];
    bearer_request.auth = RequestAuth::Bearer {
        token: "must-not-be-used".into(),
    };
    execute(bearer_request).await.unwrap();
    let received = String::from_utf8(server.await.unwrap()).unwrap();
    assert!(received.contains("authorization: Custom scheme-value"));
    assert!(!received.contains("must-not-be-used"));

    let response =
        b"HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_vec();
    let (url, server) = local_server(response).await;
    let mut api_key_request = request(url);
    api_key_request.headers = vec![KeyValue {
        key: "x-api-key".into(),
        value: "editor-value".into(),
        enabled: true,
    }];
    api_key_request.auth = RequestAuth::ApiKey {
        key: "X-API-Key".into(),
        value: "generated-value".into(),
        placement: ApiKeyPlacement::Header,
    };
    execute(api_key_request).await.unwrap();
    let received = String::from_utf8(server.await.unwrap()).unwrap();
    assert!(
        received
            .to_ascii_lowercase()
            .contains("x-api-key: editor-value")
    );
    assert!(!received.contains("generated-value"));
}

#[tokio::test]
async fn api_key_query_authentication_is_added_unless_user_configured_the_same_key() {
    let response =
        b"HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_vec();
    let (url, server) = local_server(response).await;
    let mut generated_query_request = request(url);
    generated_query_request.auth = RequestAuth::ApiKey {
        key: "api_key".into(),
        value: "generated-value".into(),
        placement: ApiKeyPlacement::Query,
    };
    execute(generated_query_request).await.unwrap();
    let received = String::from_utf8(server.await.unwrap()).unwrap();
    assert!(received.starts_with("GET /?api_key=generated-value HTTP/1.1"));

    let response =
        b"HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_vec();
    let (url, server) = local_server(response).await;
    let mut explicit_query_request = request(url);
    explicit_query_request.query_params = vec![KeyValue {
        key: "api_key".into(),
        value: "editor-value".into(),
        enabled: true,
    }];
    explicit_query_request.auth = RequestAuth::ApiKey {
        key: "api_key".into(),
        value: "generated-value".into(),
        placement: ApiKeyPlacement::Query,
    };
    execute(explicit_query_request).await.unwrap();
    let received = String::from_utf8(server.await.unwrap()).unwrap();
    assert!(received.starts_with("GET /?api_key=editor-value HTTP/1.1"));
    assert!(!received.contains("generated-value"));
}

#[tokio::test]
async fn streaming_emits_ordered_events_and_one_completed_terminal_event() {
    let response =
        b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\nConnection: close\r\n\r\nhello".to_vec();
    let (url, server) = local_server(response).await;
    let (sender, mut receiver) = mpsc::channel(8);

    let result = execute_streaming(
        request(url),
        ExecutionOptions::default(),
        CancellationToken::new(),
        sender,
    )
    .await
    .unwrap();
    server.await.unwrap();

    assert_eq!(result.body, b"hello");
    assert!(matches!(
        receiver.recv().await,
        Some(ExecutionEvent::ResponseStarted { execution_id, status: 200, .. })
            if execution_id == "request-1"
    ));
    assert_eq!(
        receiver.recv().await,
        Some(ExecutionEvent::BodyChunk {
            execution_id: "request-1".into(),
            bytes: b"hello".to_vec(),
        })
    );
    assert!(matches!(
        receiver.recv().await,
        Some(ExecutionEvent::Completed { execution_id, .. }) if execution_id == "request-1"
    ));
    assert_eq!(receiver.recv().await, None);
}

#[tokio::test]
async fn already_cancelled_execution_emits_only_cancelled_terminal_event() {
    let (sender, mut receiver) = mpsc::channel(2);
    let cancellation = CancellationToken::new();
    cancellation.cancel();

    let result = execute_streaming(
        request("http://127.0.0.1:1".into()),
        ExecutionOptions::default(),
        cancellation,
        sender,
    )
    .await;

    assert_eq!(result.unwrap_err(), ExecuteError::Cancelled);
    assert_eq!(
        receiver.recv().await,
        Some(ExecutionEvent::Cancelled {
            execution_id: "request-1".into(),
        })
    );
    assert_eq!(receiver.recv().await, None);
}

/// Opt-in smoke test for the actual public internet. It is intentionally
/// ignored in CI; run it when diagnosing DNS/TLS behavior on a desktop.
#[tokio::test]
#[ignore = "requires outbound access to httpbin.org"]
async fn live_https_request_uses_the_host_certificate_store() {
    let response = execute(request("https://httpbin.org/get".into()))
        .await
        .expect("HTTPS request to httpbin.org should succeed");
    assert_eq!(response.status, 200);
}

#[tokio::test]
async fn cancellation_does_not_hang_on_a_full_event_channel() {
    let (sender, _receiver) = mpsc::channel(1);
    sender
        .send(ExecutionEvent::Cancelled {
            execution_id: "previous".into(),
        })
        .await
        .unwrap();
    let cancellation = CancellationToken::new();
    cancellation.cancel();
    let result = tokio::time::timeout(
        Duration::from_secs(1),
        execute_streaming(
            request("http://127.0.0.1:1".into()),
            ExecutionOptions {
                timeout: Duration::from_millis(20),
                ..ExecutionOptions::default()
            },
            cancellation,
            sender,
        ),
    )
    .await
    .expect("terminal delivery must be bounded");
    assert_eq!(result, Err(ExecuteError::Timeout));
}

#[tokio::test]
async fn streaming_and_buffered_requests_share_body_and_auth_encoding() {
    for streaming in [false, true] {
        let (url, server) =
            local_server(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok".to_vec()).await;
        let mut input = request(url);
        input.method = RequestMethod::Post;
        input.body = Body::Text {
            content: "hello".into(),
            content_type: Some("text/plain".into()),
        };
        input.auth = RequestAuth::Bearer {
            token: "test-token".into(),
        };
        let response = if streaming {
            let (sender, _receiver) = mpsc::channel(10);
            execute_streaming(
                input,
                ExecutionOptions::default(),
                CancellationToken::new(),
                sender,
            )
            .await
            .unwrap()
        } else {
            execute(input).await.unwrap()
        };
        assert_eq!(response.body, b"ok");
        let received = String::from_utf8(server.await.unwrap())
            .unwrap()
            .to_lowercase();
        assert!(received.contains("authorization: bearer test-token"));
        assert!(received.contains("content-type: text/plain"));
        assert!(received.ends_with("hello"));
    }
}

#[test]
fn explicit_url_query_takes_precedence_over_generated_api_key() {
    let mut input = request("https://example.test/?api_key=explicit".into());
    input.auth = RequestAuth::ApiKey {
        key: "api_key".into(),
        value: "generated".into(),
        placement: ApiKeyPlacement::Query,
    };
    let built = build_request(&input, ExecutionOptions::default())
        .unwrap()
        .build()
        .unwrap();
    assert_eq!(built.url().query(), Some("api_key=explicit"));
}
