//! Asynchronous HTTP request execution for the native application core.

use futures_util::StreamExt;
use post_killer_application::RequestExecutor;
use post_killer_domain::{
    ApiKeyPlacement, Body, RequestAuth, RequestDefinition, RequestMethod, ValidationError,
};
use reqwest::{
    Client,
    header::{CONTENT_TYPE, HeaderName, HeaderValue},
    redirect::Policy,
};
use serde::{Deserialize, Serialize};
use std::{fmt, time::Duration};
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);
const DEFAULT_MAX_RESPONSE_BYTES: usize = 10 * 1024 * 1024;
const DEFAULT_MAX_REDIRECTS: usize = 10;

/// Reqwest/Rustls outbound adapter. The application core only sees the
/// [`RequestExecutor`] port, never this concrete transport.
#[derive(Debug, Default, Clone, Copy)]
pub struct ReqwestRequestExecutor;

impl RequestExecutor for ReqwestRequestExecutor {
    type Options = ExecutionOptions;
    type Response = ExecutionResult;
    type Error = ExecuteError;

    async fn execute(
        &self,
        request: RequestDefinition,
        options: Self::Options,
    ) -> Result<Self::Response, Self::Error> {
        execute_with_options(request, options).await
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum RedirectPolicy {
    None,
    Follow { max_redirects: usize },
}

impl Default for RedirectPolicy {
    fn default() -> Self {
        Self::Follow {
            max_redirects: DEFAULT_MAX_REDIRECTS,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExecutionOptions {
    pub timeout: Duration,
    pub redirect_policy: RedirectPolicy,
    pub max_response_bytes: usize,
}

impl Default for ExecutionOptions {
    fn default() -> Self {
        Self {
            timeout: DEFAULT_TIMEOUT,
            redirect_policy: RedirectPolicy::default(),
            max_response_bytes: DEFAULT_MAX_RESPONSE_BYTES,
        }
    }
}

/// Header values remain bytes so unusual but valid values are not corrupted.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResponseHeader {
    pub name: String,
    pub value: Vec<u8>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResponsePayload {
    pub request_id: String,
    pub status: u16,
    pub headers: Vec<ResponseHeader>,
    pub body: Vec<u8>,
    pub effective_url: String,
    pub duration: Duration,
}

/// Events emitted by [`execute_streaming`]. Each started execution emits exactly
/// one terminal event: `completed`, `failed`, or `cancelled`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ExecutionEvent {
    ResponseStarted {
        execution_id: String,
        status: u16,
        headers: Vec<ResponseHeader>,
        effective_url: String,
    },
    BodyChunk {
        execution_id: String,
        bytes: Vec<u8>,
    },
    Completed {
        execution_id: String,
        duration_millis: u64,
    },
    Failed {
        execution_id: String,
        message: String,
    },
    Cancelled {
        execution_id: String,
    },
}

/// Compatibility name retained for callers of the original engine boundary.
pub type ExecutionResult = ResponsePayload;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransportErrorKind {
    Connect,
    Request,
    Decode,
    Other,
}

/// Failures never retain URLs, header values, or bodies, which may be sensitive.
#[derive(Debug, PartialEq, Eq)]
pub enum ExecuteError {
    InvalidRequest(ValidationError),
    InvalidUrl,
    InvalidHeaderName { name: String },
    InvalidHeaderValue { name: String },
    UnsupportedBody { body_kind: &'static str },
    Timeout,
    Cancelled,
    EventReceiverDropped,
    Transport(TransportErrorKind),
    ResponseTooLarge { limit: usize },
}

impl fmt::Display for ExecuteError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidRequest(error) => write!(formatter, "invalid request: {error}"),
            Self::InvalidUrl => formatter.write_str("request URL is invalid"),
            Self::InvalidHeaderName { name } => write!(formatter, "invalid header name: {name}"),
            Self::InvalidHeaderValue { name } => {
                write!(formatter, "invalid value for header: {name}")
            }
            Self::UnsupportedBody { body_kind } => {
                write!(formatter, "unsupported request body: {body_kind}")
            }
            Self::Timeout => formatter.write_str("request timed out"),
            Self::Cancelled => formatter.write_str("request was cancelled"),
            Self::EventReceiverDropped => {
                formatter.write_str("execution event receiver was dropped")
            }
            Self::Transport(kind) => write!(formatter, "HTTP transport failed: {kind:?}"),
            Self::ResponseTooLarge { limit } => {
                write!(formatter, "response exceeds the {limit}-byte limit")
            }
        }
    }
}

impl std::error::Error for ExecuteError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::InvalidRequest(error) => Some(error),
            _ => None,
        }
    }
}

/// Executes using conservative defaults while retaining the original public signature.
pub async fn execute(request: RequestDefinition) -> Result<ExecutionResult, ExecuteError> {
    execute_with_options(request, ExecutionOptions::default()).await
}

pub async fn execute_with_options(
    request: RequestDefinition,
    options: ExecutionOptions,
) -> Result<ResponsePayload, ExecuteError> {
    request.validate().map_err(ExecuteError::InvalidRequest)?;

    let redirect = match options.redirect_policy {
        RedirectPolicy::None => Policy::none(),
        RedirectPolicy::Follow { max_redirects } => Policy::limited(max_redirects),
    };
    let client = Client::builder()
        .redirect(redirect)
        .timeout(options.timeout)
        .build()
        .map_err(classify_transport)?;
    let url = reqwest::Url::parse(request.url.trim()).map_err(|_| ExecuteError::InvalidUrl)?;
    if !matches!(url.scheme(), "http" | "https") {
        return Err(ExecuteError::InvalidUrl);
    }
    let method = match request.method {
        RequestMethod::Get => reqwest::Method::GET,
        RequestMethod::Post => reqwest::Method::POST,
        RequestMethod::Put => reqwest::Method::PUT,
        RequestMethod::Patch => reqwest::Method::PATCH,
        RequestMethod::Delete => reqwest::Method::DELETE,
        RequestMethod::Head => reqwest::Method::HEAD,
        RequestMethod::Options => reqwest::Method::OPTIONS,
    };
    let mut builder = client.request(method, url);
    let query = enabled_pairs(&request.query_params);
    if !query.is_empty() {
        builder = builder.query(&query);
    }

    let has_content_type = request
        .headers
        .iter()
        .any(|header| header.enabled && header.key.trim().eq_ignore_ascii_case("content-type"));
    for header in request.headers.iter().filter(|header| header.enabled) {
        let trimmed_name = header.key.trim();
        let name = HeaderName::from_bytes(trimmed_name.as_bytes()).map_err(|_| {
            ExecuteError::InvalidHeaderName {
                name: trimmed_name.to_owned(),
            }
        })?;
        let value =
            HeaderValue::from_str(&header.value).map_err(|_| ExecuteError::InvalidHeaderValue {
                name: trimmed_name.to_owned(),
            })?;
        builder = builder.header(name, value);
    }
    builder = apply_authentication(builder, &request)?;

    builder = match &request.body {
        Body::Empty => builder,
        Body::Text {
            content,
            content_type,
        } => {
            let mut builder = builder.body(content.clone());
            if !has_content_type && let Some(content_type) = content_type {
                let value = HeaderValue::from_str(content_type).map_err(|_| {
                    ExecuteError::InvalidHeaderValue {
                        name: "content-type".to_owned(),
                    }
                })?;
                builder = builder.header(CONTENT_TYPE, value);
            }
            builder
        }
        Body::Json { content } => {
            let encoded = serde_json::to_vec(content)
                .map_err(|_| ExecuteError::Transport(TransportErrorKind::Decode))?;
            let mut builder = builder.body(encoded);
            if !has_content_type {
                builder = builder.header(CONTENT_TYPE, "application/json");
            }
            builder
        }
        Body::FormUrlEncoded { fields } => builder.form(&enabled_pairs(fields)),
        Body::Multipart { fields } => {
            let form = enabled_pairs(fields)
                .into_iter()
                .fold(reqwest::multipart::Form::new(), |form, (key, value)| {
                    form.text(key.to_owned(), value.to_owned())
                });
            builder.multipart(form)
        }
    };

    let started_at = std::time::Instant::now();
    let response = builder.send().await.map_err(classify_transport)?;
    let status = response.status().as_u16();
    let effective_url = response.url().as_str().to_owned();
    let headers = response
        .headers()
        .iter()
        .map(|(name, value)| ResponseHeader {
            name: name.as_str().to_owned(),
            value: value.as_bytes().to_vec(),
        })
        .collect();
    if response
        .content_length()
        .is_some_and(|length| length > options.max_response_bytes as u64)
    {
        return Err(ExecuteError::ResponseTooLarge {
            limit: options.max_response_bytes,
        });
    }

    let mut body = Vec::new();
    let mut chunks = response.bytes_stream();
    while let Some(chunk) = chunks.next().await {
        let chunk = chunk.map_err(classify_transport)?;
        if chunk.len() > options.max_response_bytes.saturating_sub(body.len()) {
            return Err(ExecuteError::ResponseTooLarge {
                limit: options.max_response_bytes,
            });
        }
        body.extend_from_slice(&chunk);
    }
    Ok(ResponsePayload {
        request_id: request.id,
        status,
        headers,
        body,
        effective_url,
        duration: started_at.elapsed(),
    })
}

/// Streams response metadata and chunks to a caller-owned channel. The caller
/// owns the task that awaits this function; no background task is detached.
pub async fn execute_streaming(
    request: RequestDefinition,
    options: ExecutionOptions,
    cancellation: CancellationToken,
    events: mpsc::Sender<ExecutionEvent>,
) -> Result<ResponsePayload, ExecuteError> {
    let execution_id = request.id.clone();
    let result = execute_streaming_inner(&request, options, &cancellation, &events).await;

    let terminal_event = match &result {
        Ok(payload) => ExecutionEvent::Completed {
            execution_id,
            duration_millis: payload.duration.as_millis().try_into().unwrap_or(u64::MAX),
        },
        Err(ExecuteError::Cancelled) => ExecutionEvent::Cancelled { execution_id },
        Err(error) => ExecutionEvent::Failed {
            execution_id,
            message: error.to_string(),
        },
    };
    send_terminal_event(&events, terminal_event).await?;
    result
}

async fn execute_streaming_inner(
    request: &RequestDefinition,
    options: ExecutionOptions,
    cancellation: &CancellationToken,
    events: &mpsc::Sender<ExecutionEvent>,
) -> Result<ResponsePayload, ExecuteError> {
    request.validate().map_err(ExecuteError::InvalidRequest)?;
    check_cancelled(cancellation)?;

    let builder = build_request(request, options)?;
    let started_at = std::time::Instant::now();
    let response = tokio::select! {
        _ = cancellation.cancelled() => return Err(ExecuteError::Cancelled),
        result = builder.send() => result.map_err(classify_transport)?,
    };
    let status = response.status().as_u16();
    let effective_url = response.url().as_str().to_owned();
    let headers: Vec<_> = response
        .headers()
        .iter()
        .map(|(name, value)| ResponseHeader {
            name: name.as_str().to_owned(),
            value: value.as_bytes().to_vec(),
        })
        .collect();
    if response
        .content_length()
        .is_some_and(|length| length > options.max_response_bytes as u64)
    {
        return Err(ExecuteError::ResponseTooLarge {
            limit: options.max_response_bytes,
        });
    }
    send_stream_event(
        events,
        cancellation,
        ExecutionEvent::ResponseStarted {
            execution_id: request.id.clone(),
            status,
            headers: headers.clone(),
            effective_url: effective_url.clone(),
        },
    )
    .await?;

    let mut body = Vec::new();
    let mut chunks = response.bytes_stream();
    loop {
        let next_chunk = tokio::select! {
            _ = cancellation.cancelled() => return Err(ExecuteError::Cancelled),
            chunk = chunks.next() => chunk,
        };
        let Some(chunk) = next_chunk else {
            break;
        };
        let chunk = chunk.map_err(classify_transport)?;
        if chunk.len() > options.max_response_bytes.saturating_sub(body.len()) {
            return Err(ExecuteError::ResponseTooLarge {
                limit: options.max_response_bytes,
            });
        }
        body.extend_from_slice(&chunk);
        send_stream_event(
            events,
            cancellation,
            ExecutionEvent::BodyChunk {
                execution_id: request.id.clone(),
                bytes: chunk.to_vec(),
            },
        )
        .await?;
    }
    Ok(ResponsePayload {
        request_id: request.id.clone(),
        status,
        headers,
        body,
        effective_url,
        duration: started_at.elapsed(),
    })
}

fn check_cancelled(cancellation: &CancellationToken) -> Result<(), ExecuteError> {
    if cancellation.is_cancelled() {
        Err(ExecuteError::Cancelled)
    } else {
        Ok(())
    }
}

async fn send_stream_event(
    events: &mpsc::Sender<ExecutionEvent>,
    cancellation: &CancellationToken,
    event: ExecutionEvent,
) -> Result<(), ExecuteError> {
    tokio::select! {
        _ = cancellation.cancelled() => Err(ExecuteError::Cancelled),
        result = events.send(event) => result.map_err(|_| ExecuteError::EventReceiverDropped),
    }
}

async fn send_terminal_event(
    events: &mpsc::Sender<ExecutionEvent>,
    event: ExecutionEvent,
) -> Result<(), ExecuteError> {
    events
        .send(event)
        .await
        .map_err(|_| ExecuteError::EventReceiverDropped)
}

fn build_request(
    request: &RequestDefinition,
    options: ExecutionOptions,
) -> Result<reqwest::RequestBuilder, ExecuteError> {
    let redirect = match options.redirect_policy {
        RedirectPolicy::None => Policy::none(),
        RedirectPolicy::Follow { max_redirects } => Policy::limited(max_redirects),
    };
    let client = Client::builder()
        .redirect(redirect)
        .timeout(options.timeout)
        .build()
        .map_err(classify_transport)?;
    let url = reqwest::Url::parse(request.url.trim()).map_err(|_| ExecuteError::InvalidUrl)?;
    if !matches!(url.scheme(), "http" | "https") {
        return Err(ExecuteError::InvalidUrl);
    }
    let method = match request.method {
        RequestMethod::Get => reqwest::Method::GET,
        RequestMethod::Post => reqwest::Method::POST,
        RequestMethod::Put => reqwest::Method::PUT,
        RequestMethod::Patch => reqwest::Method::PATCH,
        RequestMethod::Delete => reqwest::Method::DELETE,
        RequestMethod::Head => reqwest::Method::HEAD,
        RequestMethod::Options => reqwest::Method::OPTIONS,
    };
    let mut builder = client.request(method, url);
    let query = enabled_pairs(&request.query_params);
    if !query.is_empty() {
        builder = builder.query(&query);
    }
    let has_content_type = request
        .headers
        .iter()
        .any(|header| header.enabled && header.key.trim().eq_ignore_ascii_case("content-type"));
    for header in request.headers.iter().filter(|header| header.enabled) {
        let trimmed_name = header.key.trim();
        let name = HeaderName::from_bytes(trimmed_name.as_bytes()).map_err(|_| {
            ExecuteError::InvalidHeaderName {
                name: trimmed_name.to_owned(),
            }
        })?;
        let value =
            HeaderValue::from_str(&header.value).map_err(|_| ExecuteError::InvalidHeaderValue {
                name: trimmed_name.to_owned(),
            })?;
        builder = builder.header(name, value);
    }
    builder = apply_authentication(builder, request)?;
    match &request.body {
        Body::Empty => Ok(builder),
        Body::Text {
            content,
            content_type,
        } => {
            let mut builder = builder.body(content.clone());
            if !has_content_type && let Some(content_type) = content_type {
                let value = HeaderValue::from_str(content_type).map_err(|_| {
                    ExecuteError::InvalidHeaderValue {
                        name: "content-type".to_owned(),
                    }
                })?;
                builder = builder.header(CONTENT_TYPE, value);
            }
            Ok(builder)
        }
        Body::Json { content } => {
            let encoded = serde_json::to_vec(content)
                .map_err(|_| ExecuteError::Transport(TransportErrorKind::Decode))?;
            if !has_content_type {
                builder = builder.header(CONTENT_TYPE, "application/json");
            }
            Ok(builder.body(encoded))
        }
        Body::FormUrlEncoded { fields } => Ok(builder.form(&enabled_pairs(fields))),
        Body::Multipart { fields } => {
            let form = enabled_pairs(fields)
                .into_iter()
                .fold(reqwest::multipart::Form::new(), |form, (key, value)| {
                    form.text(key.to_owned(), value.to_owned())
                });
            Ok(builder.multipart(form))
        }
    }
}

/// Adds configured authentication only when the request does not explicitly set
/// the same location. An enabled user `Authorization` header always wins over
/// Basic/Bearer generation; an enabled user API-key header or query parameter
/// with the same key likewise wins. This keeps request-editor intent explicit.
fn apply_authentication(
    mut builder: reqwest::RequestBuilder,
    request: &RequestDefinition,
) -> Result<reqwest::RequestBuilder, ExecuteError> {
    match &request.auth {
        RequestAuth::None => Ok(builder),
        RequestAuth::Basic { username, password } => {
            if !has_enabled_header(&request.headers, "authorization") {
                builder = builder.basic_auth(username, Some(password));
            }
            Ok(builder)
        }
        RequestAuth::Bearer { token } => {
            if !has_enabled_header(&request.headers, "authorization") {
                builder = builder.bearer_auth(token);
            }
            Ok(builder)
        }
        RequestAuth::ApiKey {
            key,
            value,
            placement,
        } => match placement {
            ApiKeyPlacement::Header => {
                if has_enabled_header(&request.headers, key) {
                    return Ok(builder);
                }
                let name = HeaderName::from_bytes(key.trim().as_bytes()).map_err(|_| {
                    ExecuteError::InvalidHeaderName {
                        name: key.trim().to_owned(),
                    }
                })?;
                let value =
                    HeaderValue::from_str(value).map_err(|_| ExecuteError::InvalidHeaderValue {
                        name: key.trim().to_owned(),
                    })?;
                Ok(builder.header(name, value))
            }
            ApiKeyPlacement::Query => {
                if !has_enabled_key(&request.query_params, key) {
                    builder = builder.query(&[(key.as_str(), value.as_str())]);
                }
                Ok(builder)
            }
        },
    }
}

fn has_enabled_header(headers: &[post_killer_domain::KeyValue], name: &str) -> bool {
    headers
        .iter()
        .any(|header| header.enabled && header.key.trim().eq_ignore_ascii_case(name.trim()))
}

fn has_enabled_key(fields: &[post_killer_domain::KeyValue], key: &str) -> bool {
    fields.iter().any(|field| field.enabled && field.key == key)
}

fn enabled_pairs(fields: &[post_killer_domain::KeyValue]) -> Vec<(&str, &str)> {
    fields
        .iter()
        .filter(|field| field.enabled)
        .map(|field| (field.key.as_str(), field.value.as_str()))
        .collect()
}

fn classify_transport(error: reqwest::Error) -> ExecuteError {
    if error.is_timeout() {
        ExecuteError::Timeout
    } else if error.is_connect() {
        ExecuteError::Transport(TransportErrorKind::Connect)
    } else if error.is_request() || error.is_builder() {
        ExecuteError::Transport(TransportErrorKind::Request)
    } else if error.is_decode() {
        ExecuteError::Transport(TransportErrorKind::Decode)
    } else {
        ExecuteError::Transport(TransportErrorKind::Other)
    }
}

#[cfg(test)]
mod tests {
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
}
