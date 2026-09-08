use post_killer_domain::{RequestDefinition, ValidationError};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Workspace {
    pub id: String,
    pub name: String,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Collection {
    pub id: String,
    pub workspace_id: String,
    pub name: String,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Folder {
    pub id: String,
    pub collection_id: String,
    pub parent_folder_id: Option<String>,
    pub name: String,
    pub sort_order: i64,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Environment {
    pub id: String,
    pub workspace_id: String,
    pub name: String,
}
/// Values intentionally contain no secret-store integration.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EnvironmentVariable {
    pub id: String,
    pub environment_id: String,
    pub key: String,
    pub value: String,
    pub enabled: bool,
}
#[derive(Debug, Clone, PartialEq)]
pub struct StoredRequest {
    pub collection_id: String,
    pub folder_id: Option<String>,
    pub definition: RequestDefinition,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExecutionResultKind {
    Response,
    Error,
    Cancelled,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExecutionErrorCategory {
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
/// Privacy-safe execution metadata: no payloads, URLs, headers, cookies or secrets.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExecutionHistoryRecord {
    pub execution_id: String,
    pub request_id: String,
    pub executed_at_unix_ms: i64,
    pub status_code: Option<u16>,
    pub duration_ms: u64,
    pub response_size_bytes: u64,
    pub result_kind: ExecutionResultKind,
    pub error_category: Option<ExecutionErrorCategory>,
}

#[derive(Debug)]
pub enum StorageError {
    InvalidInput {
        entity: &'static str,
        field: &'static str,
    },
    AlreadyExists {
        entity: &'static str,
        id: String,
    },
    WorkspaceNotFound {
        id: String,
    },
    CollectionNotFound {
        id: String,
    },
    FolderNotFound {
        id: String,
    },
    RequestNotFound {
        id: String,
    },
    EnvironmentNotFound {
        id: String,
    },
    EnvironmentVariableNotFound {
        id: String,
    },
    ExecutionHistoryNotFound {
        execution_id: String,
        request_id: String,
    },
    ParentFolderCollectionMismatch {
        folder_id: String,
        parent_folder_id: String,
    },
    RequestFolderCollectionMismatch {
        request_id: String,
        folder_id: String,
        collection_id: String,
    },
    InvalidRequest(ValidationError),
    Serialization(serde_json::Error),
    Database(rusqlite::Error),
}
impl std::fmt::Display for StorageError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidInput { entity, field } => write!(f, "{entity} {field} must not be empty"),
            Self::AlreadyExists { entity, id } => {
                write!(f, "{entity} with id '{id}' already exists")
            }
            Self::WorkspaceNotFound { id } => write!(f, "workspace with id '{id}' does not exist"),
            Self::CollectionNotFound { id } => {
                write!(f, "collection with id '{id}' does not exist")
            }
            Self::FolderNotFound { id } => write!(f, "folder with id '{id}' does not exist"),
            Self::RequestNotFound { id } => write!(f, "request with id '{id}' does not exist"),
            Self::EnvironmentNotFound { id } => {
                write!(f, "environment with id '{id}' does not exist")
            }
            Self::EnvironmentVariableNotFound { id } => {
                write!(f, "environment variable with id '{id}' does not exist")
            }
            Self::ExecutionHistoryNotFound {
                execution_id,
                request_id,
            } => write!(
                f,
                "execution history entry '{execution_id}' does not exist for request '{request_id}'"
            ),
            Self::ParentFolderCollectionMismatch {
                folder_id,
                parent_folder_id,
            } => write!(
                f,
                "folder '{folder_id}' and parent folder '{parent_folder_id}' must belong to the same collection"
            ),
            Self::RequestFolderCollectionMismatch {
                request_id,
                folder_id,
                collection_id,
            } => write!(
                f,
                "request '{request_id}' cannot use folder '{folder_id}' outside collection '{collection_id}'"
            ),
            Self::InvalidRequest(error) => write!(f, "invalid request: {error}"),
            Self::Serialization(error) => write!(f, "request data is invalid: {error}"),
            Self::Database(error) => write!(f, "SQLite error: {error}"),
        }
    }
}
impl std::error::Error for StorageError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Database(error) => Some(error),
            Self::Serialization(error) => Some(error),
            Self::InvalidRequest(error) => Some(error),
            _ => None,
        }
    }
}
impl From<rusqlite::Error> for StorageError {
    fn from(error: rusqlite::Error) -> Self {
        Self::Database(error)
    }
}
