use super::*;

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
/// one terminal event when the receiver drains within the configured timeout.
/// A stalled/dropped receiver instead receives a typed error from the task.
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
    MultipartFileRead,
    MultipartFileTooLarge { limit: usize },
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
            Self::MultipartFileRead => formatter.write_str("multipart file cannot be read"),
            Self::MultipartFileTooLarge { limit } => {
                write!(formatter, "multipart file exceeds the {limit}-byte limit")
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
