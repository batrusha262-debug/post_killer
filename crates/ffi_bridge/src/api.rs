//! Stable Dart-facing request execution contract.
//!
//! This module only converts FFI-safe owned DTOs and composes the application
//! use-case with its HTTP adapter. Transport policy and orchestration remain in
//! their owning crates.

use post_killer_application::RequestExecutionService;
use post_killer_domain::RequestDefinition;
use post_killer_http_engine::{ExecutionOptions, ReqwestRequestExecutor};
use post_killer_storage_sqlite::{Repository, SqliteStorage};
use std::{
    path::PathBuf,
    sync::{Mutex, OnceLock},
    time::{SystemTime, UNIX_EPOCH},
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

#[cfg(test)]
#[path = "api_tests.rs"]
mod tests;
