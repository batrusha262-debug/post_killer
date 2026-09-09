use super::*;
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpListener,
};

fn request(url: String) -> FfiRequest {
    FfiRequest {
        id: "ffi-request-1".to_owned(),
        name: "FFI request".to_owned(),
        method: FfiRequestMethod::Get,
        url,
        query_params: vec![],
        headers: vec![],
        body: FfiRequestBody {
            kind: FfiRequestBodyKind::Empty,
            content: String::new(),
            content_type: None,
            fields: vec![],
        },
        auth: FfiRequestAuth {
            kind: FfiRequestAuthKind::None,
            username: String::new(),
            password: String::new(),
            token: String::new(),
            key: String::new(),
            value: String::new(),
            placement: FfiApiKeyPlacement::Header,
        },
    }
}

#[tokio::test]
async fn executes_real_http_through_application_boundary() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap());
    let server = tokio::spawn(async move {
        let (mut socket, _) = listener.accept().await.unwrap();
        let mut received = [0_u8; 1024];
        let count = socket.read(&mut received).await.unwrap();
        socket
            .write_all(
                b"HTTP/1.1 202 Accepted\r\nContent-Type: text/plain\r\nContent-Length: 8\r\nConnection: close\r\n\r\naccepted",
            )
            .await
            .unwrap();
        String::from_utf8_lossy(&received[..count]).into_owned()
    });

    let outcome = execute_request(request(url)).await;
    let response = outcome.response.expect("response");
    assert!(outcome.error.is_none());
    assert_eq!(response.status, 202);
    assert_eq!(response.body, b"accepted");
    assert!(server.await.unwrap().starts_with("GET / HTTP/1.1\r\n"));
}

#[tokio::test]
async fn returns_typed_validation_error_without_transport() {
    let outcome = execute_request(request("  ".to_owned())).await;
    let error = outcome.error.expect("error");
    assert!(outcome.response.is_none());
    assert_eq!(error.kind, FfiExecutionErrorKind::InvalidRequest);
    assert_eq!(error.field.as_deref(), Some("url"));
}

#[tokio::test]
async fn rejects_malformed_json_as_a_typed_boundary_error() {
    let mut input = request("https://example.test".to_owned());
    input.body = FfiRequestBody {
        kind: FfiRequestBodyKind::Json,
        content: "{".to_owned(),
        content_type: None,
        fields: vec![],
    };

    let outcome = execute_request(input).await;
    let error = outcome.error.expect("error");
    assert_eq!(error.kind, FfiExecutionErrorKind::InvalidJsonBody);
    assert_eq!(error.field.as_deref(), Some("body"));
}
