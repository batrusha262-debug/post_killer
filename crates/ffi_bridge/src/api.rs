//! Stable Dart-facing request execution contract.
//!
//! This module only converts FFI-safe owned DTOs and composes the application
//! use-case with its HTTP adapter. Transport policy and orchestration remain in
//! their owning crates.

use post_killer_application::RequestExecutionService;
use post_killer_domain::{
    ApiKeyPlacement, Body, KeyValue, RequestAuth, RequestDefinition, RequestMethod, ValidationError,
};
use post_killer_http_engine::{
    ExecuteError, ExecutionOptions, RedirectPolicy, ReqwestRequestExecutor, ResponsePayload,
    TransportErrorKind,
};
use post_killer_storage_sqlite::{Collection, Repository, SqliteStorage, Workspace};
use std::{
    path::PathBuf,
    sync::{Mutex, OnceLock},
    time::{Duration, SystemTime, UNIX_EPOCH},
};

static WORKSPACE_STORAGE: OnceLock<Result<Mutex<SqliteStorage>, String>> = OnceLock::new();

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiWorkspace {
    pub id: String,
    pub name: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiCollection {
    pub id: String,
    pub workspace_id: String,
    pub name: String,
}

/// Lists persisted local workspaces. The database is owned exclusively by the
/// Rust storage adapter; Flutter only receives owned DTOs through FRB.
pub fn list_workspaces() -> Result<Vec<FfiWorkspace>, String> {
    with_storage(|storage| storage.list_workspaces().map_err(|error| error.to_string()))
        .map(|workspaces| workspaces.into_iter().map(Into::into).collect())
}

pub fn create_workspace(name: String) -> Result<FfiWorkspace, String> {
    let name = name.trim().to_owned();
    with_storage(|storage| {
        storage
            .create_workspace(next_id("workspace"), name)
            .map_err(|error| error.to_string())
    })
    .map(Into::into)
}

pub fn list_collections(workspace_id: String) -> Result<Vec<FfiCollection>, String> {
    with_storage(|storage| {
        storage
            .list_collections(&workspace_id)
            .map_err(|error| error.to_string())
    })
    .map(|collections| collections.into_iter().map(Into::into).collect())
}

pub fn create_collection(workspace_id: String, name: String) -> Result<FfiCollection, String> {
    let name = name.trim().to_owned();
    with_storage(|storage| {
        storage
            .create_collection(next_id("collection"), workspace_id, name)
            .map_err(|error| error.to_string())
    })
    .map(Into::into)
}

fn with_storage<T>(
    operation: impl FnOnce(&mut SqliteStorage) -> Result<T, String>,
) -> Result<T, String> {
    let storage = WORKSPACE_STORAGE.get_or_init(|| {
        let directory = app_data_directory()?;
        std::fs::create_dir_all(&directory)
            .map_err(|error| format!("cannot create local data directory: {error}"))?;
        SqliteStorage::open(directory.join("post-killer.sqlite3"))
            .map(Mutex::new)
            .map_err(|error| format!("cannot open local workspace storage: {error}"))
    });
    let storage = storage.as_ref().map_err(Clone::clone)?;
    let mut storage = storage
        .lock()
        .map_err(|_| "local workspace storage is unavailable".to_owned())?;
    operation(&mut storage)
}

fn app_data_directory() -> Result<PathBuf, String> {
    dirs_next::data_local_dir()
        .map(|directory| directory.join("Post Killer"))
        .ok_or_else(|| "cannot resolve the local application data directory".to_owned())
}

fn next_id(prefix: &str) -> String {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_nanos())
        .unwrap_or_default();
    format!("{prefix}-{nanos}")
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FfiRequestMethod {
    Get,
    Post,
    Put,
    Patch,
    Delete,
    Head,
    Options,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiKeyValue {
    pub key: String,
    pub value: String,
    pub enabled: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FfiRequestBodyKind {
    Empty,
    Text,
    Json,
    FormUrlEncoded,
    Multipart,
}

/// Flat body DTO keeps every Dart-facing field simple. Fields irrelevant to
/// `kind` are ignored during conversion.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiRequestBody {
    pub kind: FfiRequestBodyKind,
    pub content: String,
    pub content_type: Option<String>,
    pub fields: Vec<FfiKeyValue>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FfiRequestAuthKind {
    None,
    Basic,
    Bearer,
    ApiKey,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FfiApiKeyPlacement {
    Header,
    Query,
}

/// Credentials are deliberately input-only. They are never copied into an
/// execution response or error.
#[derive(Clone, PartialEq, Eq)]
pub struct FfiRequestAuth {
    pub kind: FfiRequestAuthKind,
    pub username: String,
    pub password: String,
    pub token: String,
    pub key: String,
    pub value: String,
    pub placement: FfiApiKeyPlacement,
}

impl std::fmt::Debug for FfiRequestAuth {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("FfiRequestAuth")
            .field("kind", &self.kind)
            .field("credentials", &"<redacted>")
            .finish()
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiRequest {
    pub id: String,
    pub name: String,
    pub method: FfiRequestMethod,
    pub url: String,
    pub query_params: Vec<FfiKeyValue>,
    pub headers: Vec<FfiKeyValue>,
    pub body: FfiRequestBody,
    pub auth: FfiRequestAuth,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FfiExecutionOptions {
    pub timeout_millis: u64,
    /// `None` disables redirects; otherwise this is the maximum followed count.
    pub max_redirects: Option<u32>,
    pub max_response_bytes: u64,
}

impl Default for FfiExecutionOptions {
    fn default() -> Self {
        Self {
            timeout_millis: 30_000,
            max_redirects: Some(10),
            max_response_bytes: 10 * 1024 * 1024,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiResponseHeader {
    pub name: String,
    pub value: Vec<u8>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiExecutionResponse {
    pub request_id: String,
    pub status: u16,
    pub headers: Vec<FfiResponseHeader>,
    pub body: Vec<u8>,
    pub effective_url: String,
    pub duration_millis: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FfiExecutionErrorKind {
    InvalidRequest,
    InvalidJsonBody,
    InvalidUrl,
    InvalidHeaderName,
    InvalidHeaderValue,
    UnsupportedBody,
    Timeout,
    Cancelled,
    TransportConnect,
    TransportRequest,
    TransportDecode,
    TransportOther,
    ResponseTooLarge,
    Internal,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiExecutionError {
    pub kind: FfiExecutionErrorKind,
    /// Privacy-safe user-facing summary; it never contains request credentials or body.
    pub message: String,
    /// Optional editor field to focus, such as `url`, `header`, or `body`.
    pub field: Option<String>,
    pub limit_bytes: Option<u64>,
}

/// Exactly one of `response` and `error` is populated.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiExecutionOutcome {
    pub response: Option<FfiExecutionResponse>,
    pub error: Option<FfiExecutionError>,
}

impl FfiExecutionOutcome {
    fn success(response: FfiExecutionResponse) -> Self {
        Self {
            response: Some(response),
            error: None,
        }
    }

    fn error(error: FfiExecutionError) -> Self {
        Self {
            response: None,
            error: Some(error),
        }
    }
}

/// Executes a request using conservative transport defaults. FRB maps this
/// `async fn` to a Dart `Future<FfiExecutionOutcome>`.
pub async fn execute_request(request: FfiRequest) -> FfiExecutionOutcome {
    execute_request_with_options(request, FfiExecutionOptions::default()).await
}

/// Executes with caller-controlled limits while retaining typed outcomes for
/// expected validation and transport failures.
pub async fn execute_request_with_options(
    request: FfiRequest,
    options: FfiExecutionOptions,
) -> FfiExecutionOutcome {
    let request = match RequestDefinition::try_from(request) {
        Ok(request) => request,
        Err(error) => return FfiExecutionOutcome::error(error),
    };
    let options = match ExecutionOptions::try_from(options) {
        Ok(options) => options,
        Err(error) => return FfiExecutionOutcome::error(error),
    };

    match RequestExecutionService::new(ReqwestRequestExecutor)
        .execute(request, options)
        .await
    {
        Ok(response) => FfiExecutionOutcome::success(response.into()),
        Err(error) => FfiExecutionOutcome::error(error.into()),
    }
}

impl TryFrom<FfiRequest> for RequestDefinition {
    type Error = FfiExecutionError;

    fn try_from(value: FfiRequest) -> Result<Self, Self::Error> {
        let body = match value.body.kind {
            FfiRequestBodyKind::Empty => Body::Empty,
            FfiRequestBodyKind::Text => Body::Text {
                content: value.body.content,
                content_type: value.body.content_type,
            },
            FfiRequestBodyKind::Json => Body::Json {
                content: serde_json::from_str(&value.body.content).map_err(|_| {
                    FfiExecutionError {
                        kind: FfiExecutionErrorKind::InvalidJsonBody,
                        message: "request JSON body is malformed".to_owned(),
                        field: Some("body".to_owned()),
                        limit_bytes: None,
                    }
                })?,
            },
            FfiRequestBodyKind::FormUrlEncoded => Body::FormUrlEncoded {
                fields: value.body.fields.into_iter().map(Into::into).collect(),
            },
            FfiRequestBodyKind::Multipart => Body::Multipart {
                fields: value.body.fields.into_iter().map(Into::into).collect(),
            },
        };
        let auth = match value.auth.kind {
            FfiRequestAuthKind::None => RequestAuth::None,
            FfiRequestAuthKind::Basic => RequestAuth::Basic {
                username: value.auth.username,
                password: value.auth.password,
            },
            FfiRequestAuthKind::Bearer => RequestAuth::Bearer {
                token: value.auth.token,
            },
            FfiRequestAuthKind::ApiKey => RequestAuth::ApiKey {
                key: value.auth.key,
                value: value.auth.value,
                placement: value.auth.placement.into(),
            },
        };

        Ok(Self {
            id: value.id,
            name: value.name,
            method: value.method.into(),
            url: value.url,
            query_params: value.query_params.into_iter().map(Into::into).collect(),
            headers: value.headers.into_iter().map(Into::into).collect(),
            body,
            auth,
        })
    }
}

impl TryFrom<FfiExecutionOptions> for ExecutionOptions {
    type Error = FfiExecutionError;

    fn try_from(value: FfiExecutionOptions) -> Result<Self, Self::Error> {
        let max_response_bytes =
            usize::try_from(value.max_response_bytes).map_err(|_| FfiExecutionError {
                kind: FfiExecutionErrorKind::InvalidRequest,
                message: "response byte limit is unsupported on this platform".to_owned(),
                field: Some("max_response_bytes".to_owned()),
                limit_bytes: None,
            })?;
        let redirect_policy = match value.max_redirects {
            Some(max_redirects) => RedirectPolicy::Follow {
                max_redirects: max_redirects as usize,
            },
            None => RedirectPolicy::None,
        };
        Ok(Self {
            timeout: Duration::from_millis(value.timeout_millis),
            redirect_policy,
            max_response_bytes,
        })
    }
}

impl From<FfiRequestMethod> for RequestMethod {
    fn from(value: FfiRequestMethod) -> Self {
        match value {
            FfiRequestMethod::Get => Self::Get,
            FfiRequestMethod::Post => Self::Post,
            FfiRequestMethod::Put => Self::Put,
            FfiRequestMethod::Patch => Self::Patch,
            FfiRequestMethod::Delete => Self::Delete,
            FfiRequestMethod::Head => Self::Head,
            FfiRequestMethod::Options => Self::Options,
        }
    }
}

impl From<FfiKeyValue> for KeyValue {
    fn from(value: FfiKeyValue) -> Self {
        Self {
            key: value.key,
            value: value.value,
            enabled: value.enabled,
        }
    }
}

impl From<FfiApiKeyPlacement> for ApiKeyPlacement {
    fn from(value: FfiApiKeyPlacement) -> Self {
        match value {
            FfiApiKeyPlacement::Header => Self::Header,
            FfiApiKeyPlacement::Query => Self::Query,
        }
    }
}

impl From<Workspace> for FfiWorkspace {
    fn from(value: Workspace) -> Self {
        Self {
            id: value.id,
            name: value.name,
        }
    }
}

impl From<Collection> for FfiCollection {
    fn from(value: Collection) -> Self {
        Self {
            id: value.id,
            workspace_id: value.workspace_id,
            name: value.name,
        }
    }
}

impl From<ResponsePayload> for FfiExecutionResponse {
    fn from(value: ResponsePayload) -> Self {
        Self {
            request_id: value.request_id,
            status: value.status,
            headers: value
                .headers
                .into_iter()
                .map(|header| FfiResponseHeader {
                    name: header.name,
                    value: header.value,
                })
                .collect(),
            body: value.body,
            effective_url: value.effective_url,
            duration_millis: value.duration.as_millis().try_into().unwrap_or(u64::MAX),
        }
    }
}

impl From<ExecuteError> for FfiExecutionError {
    fn from(value: ExecuteError) -> Self {
        let message = value.to_string();
        let (kind, field, limit_bytes) = match value {
            ExecuteError::InvalidRequest(error) => (
                FfiExecutionErrorKind::InvalidRequest,
                validation_field(&error),
                None,
            ),
            ExecuteError::InvalidUrl => (
                FfiExecutionErrorKind::InvalidUrl,
                Some("url".to_owned()),
                None,
            ),
            ExecuteError::InvalidHeaderName { .. } => (
                FfiExecutionErrorKind::InvalidHeaderName,
                Some("header".to_owned()),
                None,
            ),
            ExecuteError::InvalidHeaderValue { .. } => (
                FfiExecutionErrorKind::InvalidHeaderValue,
                Some("header".to_owned()),
                None,
            ),
            ExecuteError::UnsupportedBody { .. } => (
                FfiExecutionErrorKind::UnsupportedBody,
                Some("body".to_owned()),
                None,
            ),
            ExecuteError::Timeout => (FfiExecutionErrorKind::Timeout, None, None),
            ExecuteError::Cancelled => (FfiExecutionErrorKind::Cancelled, None, None),
            ExecuteError::EventReceiverDropped => (FfiExecutionErrorKind::Internal, None, None),
            ExecuteError::Transport(transport) => {
                let kind = match transport {
                    TransportErrorKind::Connect => FfiExecutionErrorKind::TransportConnect,
                    TransportErrorKind::Request => FfiExecutionErrorKind::TransportRequest,
                    TransportErrorKind::Decode => FfiExecutionErrorKind::TransportDecode,
                    TransportErrorKind::Other => FfiExecutionErrorKind::TransportOther,
                };
                (kind, None, None)
            }
            ExecuteError::ResponseTooLarge { limit } => (
                FfiExecutionErrorKind::ResponseTooLarge,
                None,
                Some(limit as u64),
            ),
        };
        Self {
            kind,
            message,
            field,
            limit_bytes,
        }
    }
}

fn validation_field(error: &ValidationError) -> Option<String> {
    match error {
        ValidationError::EmptyUrl => Some("url".to_owned()),
        ValidationError::EmptyEnabledKey { field_kind } => Some((*field_kind).to_owned()),
        ValidationError::EmptyAuthenticationField { field, .. } => Some(format!("auth.{field}")),
    }
}

#[cfg(test)]
mod tests {
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
}
