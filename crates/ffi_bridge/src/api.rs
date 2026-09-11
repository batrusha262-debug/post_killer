//! Stable Dart-facing request execution contract.
//!
//! This module only converts FFI-safe owned DTOs and composes the application
//! use-case with its HTTP adapter. Transport policy and orchestration remain in
//! their owning crates.

use post_killer_application::RequestExecutionService;
use post_killer_domain::RequestDefinition;
use post_killer_http_engine::{ExecutionOptions, ReqwestRequestExecutor};
use post_killer_storage_sqlite::{
    Environment, EnvironmentVariable, ExecutionHistoryRecord, Repository, SqliteStorage,
    StoredRequest,
};
use std::collections::BTreeMap;
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiEnvironment {
    pub id: String,
    pub workspace_id: String,
    pub name: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiEnvironmentVariable {
    pub id: String,
    pub environment_id: String,
    pub key: String,
    pub value: String,
    pub enabled: bool,
}

/// Privacy-safe execution metadata. It intentionally has no URL, request or
/// response body, headers, cookies, credentials or raw error text.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiExecutionHistoryRecord {
    pub execution_id: String,
    pub request_id: String,
    pub executed_at_unix_ms: i64,
    pub status_code: Option<u16>,
    pub duration_ms: u64,
    pub response_size_bytes: u64,
    pub result_kind: FfiExecutionHistoryResultKind,
    pub error_category: Option<FfiExecutionHistoryErrorCategory>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FfiExecutionHistoryResultKind {
    Response,
    Error,
    Cancelled,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FfiExecutionHistoryErrorCategory {
    Timeout,
    Dns,
    Connection,
    Tls,
    Proxy,
    Redirect,
    RequestBody,
    ResponseBody,
    Other,
}

/// A complete saved request. Keeping the collection association alongside the
/// request lets Flutter show a saved request in its folder and reopen it with
/// all fields intact.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiStoredRequest {
    pub collection_id: String,
    pub folder_id: Option<String>,
    pub request: FfiRequest,
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

/// Deletes a workspace and all of its local collections, requests and
/// environments through the database's foreign-key cascade.
pub fn delete_workspace(id: String) -> Result<(), String> {
    with_storage(|storage| {
        storage
            .delete_workspace(&id)
            .map_err(|error| error.to_string())
    })
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

/// Deletes a collection and all saved requests in it.
pub fn delete_collection(id: String) -> Result<(), String> {
    with_storage(|storage| {
        storage
            .delete_collection(&id)
            .map_err(|error| error.to_string())
    })
}

/// Lists environment profiles stored locally for one workspace. Values are
/// returned only to the local Flutter process and never added to history.
pub fn list_environments(workspace_id: String) -> Result<Vec<FfiEnvironment>, String> {
    with_storage(|storage| {
        storage
            .list_environments(&workspace_id)
            .map_err(|error| error.to_string())
    })
    .map(|environments| environments.into_iter().map(Into::into).collect())
}

pub fn create_environment(workspace_id: String, name: String) -> Result<FfiEnvironment, String> {
    let name = name.trim().to_owned();
    with_storage(|storage| {
        let environment = Environment {
            id: next_id("environment"),
            workspace_id,
            name,
        };
        storage
            .save_environment(environment.clone())
            .map_err(|error| error.to_string())?;
        Ok(environment)
    })
    .map(Into::into)
}

pub fn delete_environment(id: String) -> Result<(), String> {
    with_storage(|storage| {
        storage
            .delete_environment(&id)
            .map_err(|error| error.to_string())
    })
}

pub fn list_environment_variables(
    environment_id: String,
) -> Result<Vec<FfiEnvironmentVariable>, String> {
    with_storage(|storage| {
        storage
            .list_environment_variables(&environment_id)
            .map_err(|error| error.to_string())
    })
    .map(|variables| variables.into_iter().map(Into::into).collect())
}

pub fn save_environment_variable(
    variable: FfiEnvironmentVariable,
) -> Result<FfiEnvironmentVariable, String> {
    let variable = EnvironmentVariable::try_from(variable).map_err(|error| error.message)?;
    with_storage(|storage| {
        storage
            .save_environment_variable(variable.clone())
            .map_err(|error| error.to_string())?;
        Ok(variable)
    })
    .map(Into::into)
}

pub fn delete_environment_variable(id: String) -> Result<(), String> {
    with_storage(|storage| {
        storage
            .delete_environment_variable(&id)
            .map_err(|error| error.to_string())
    })
}

pub fn list_requests(collection_id: String) -> Result<Vec<FfiStoredRequest>, String> {
    with_storage(|storage| {
        storage
            .list_requests(&collection_id)
            .map_err(|error| error.to_string())
    })
    .map(|requests| requests.into_iter().map(Into::into).collect())
}

/// Deletes one saved request. Its local execution history is cascaded too.
pub fn delete_request(id: String) -> Result<(), String> {
    with_storage(|storage| {
        storage
            .delete_request(&id)
            .map_err(|error| error.to_string())
    })
}

/// Records only sanitized execution metadata for a saved request. Drafts are
/// intentionally never accepted by storage because they have no persisted ID.
pub fn save_execution_history(record: FfiExecutionHistoryRecord) -> Result<(), String> {
    let record = ExecutionHistoryRecord::try_from(record).map_err(|error| error.message)?;
    with_storage(|storage| {
        storage
            .append_execution_history(record)
            .map_err(|error| error.to_string())
    })
}

/// Returns workspace-wide execution metadata, newest first. The bridge never
/// returns request content, URL or any authentication material here.
pub fn list_workspace_execution_history(
    workspace_id: String,
) -> Result<Vec<FfiExecutionHistoryRecord>, String> {
    with_storage(|storage| {
        storage
            .list_workspace_execution_history(&workspace_id)
            .map_err(|error| error.to_string())
    })
    .map(|records| records.into_iter().map(Into::into).collect())
}

pub fn clear_workspace_execution_history(workspace_id: String) -> Result<u64, String> {
    with_storage(|storage| {
        storage
            .clear_workspace_execution_history(&workspace_id)
            .map_err(|error| error.to_string())
    })
    .and_then(|count| u64::try_from(count).map_err(|_| "history count is too large".to_owned()))
}

/// Creates or updates a request in the selected collection/folder.
pub fn save_request(
    collection_id: String,
    folder_id: Option<String>,
    request: FfiRequest,
) -> Result<FfiStoredRequest, String> {
    let definition = RequestDefinition::try_from(request).map_err(|error| error.message)?;
    let stored = StoredRequest {
        collection_id,
        folder_id,
        definition,
    };
    with_storage(|storage| {
        storage
            .save_request(stored.clone())
            .map_err(|error| error.to_string())
    })?;
    Ok(stored.into())
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

/// Executes a request after resolving enabled variables from the selected local
/// environment. Resolution is pure: neither the stored request nor the
/// environment values are written into execution history or diagnostic output.
pub async fn execute_request_with_variables(
    request: FfiRequest,
    variables: Vec<FfiKeyValue>,
) -> FfiExecutionOutcome {
    let request = match RequestDefinition::try_from(request) {
        Ok(request) => request,
        Err(error) => return FfiExecutionOutcome::error(error),
    };
    let variables = variables
        .into_iter()
        .filter(|variable| variable.enabled)
        .map(|variable| (variable.key, variable.value))
        .collect::<BTreeMap<_, _>>();
    let request = match request.resolve_variables(&variables) {
        Ok(request) => request,
        Err(error) => {
            return FfiExecutionOutcome::error(FfiExecutionError {
                kind: FfiExecutionErrorKind::InvalidRequest,
                message: format!("request variables are invalid: {error}"),
                field: None,
                limit_bytes: None,
            });
        }
    };

    match RequestExecutionService::new(ReqwestRequestExecutor)
        .execute(request, ExecutionOptions::default())
        .await
    {
        Ok(response) => FfiExecutionOutcome::success(response.into()),
        Err(error) => FfiExecutionOutcome::error(error.into()),
    }
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
