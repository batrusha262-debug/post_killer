use super::api::*;
use post_killer_domain::{
    ApiKeyPlacement, Body, KeyValue, RequestAuth, RequestDefinition, RequestMethod, ValidationError,
};
use post_killer_http_engine::{
    ExecuteError, ExecutionOptions, RedirectPolicy, ResponsePayload, TransportErrorKind,
};
use post_killer_storage_sqlite::{Collection, StoredRequest, Workspace};
use std::time::Duration;

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

impl From<RequestMethod> for FfiRequestMethod {
    fn from(value: RequestMethod) -> Self {
        match value {
            RequestMethod::Get => Self::Get,
            RequestMethod::Post => Self::Post,
            RequestMethod::Put => Self::Put,
            RequestMethod::Patch => Self::Patch,
            RequestMethod::Delete => Self::Delete,
            RequestMethod::Head => Self::Head,
            RequestMethod::Options => Self::Options,
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

impl From<KeyValue> for FfiKeyValue {
    fn from(value: KeyValue) -> Self {
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

impl From<ApiKeyPlacement> for FfiApiKeyPlacement {
    fn from(value: ApiKeyPlacement) -> Self {
        match value {
            ApiKeyPlacement::Header => Self::Header,
            ApiKeyPlacement::Query => Self::Query,
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

impl From<StoredRequest> for FfiStoredRequest {
    fn from(value: StoredRequest) -> Self {
        Self {
            collection_id: value.collection_id,
            folder_id: value.folder_id,
            request: value.definition.into(),
        }
    }
}

impl From<RequestDefinition> for FfiRequest {
    fn from(value: RequestDefinition) -> Self {
        let body = match value.body {
            Body::Empty => FfiRequestBody {
                kind: FfiRequestBodyKind::Empty,
                content: String::new(),
                content_type: None,
                fields: vec![],
            },
            Body::Text {
                content,
                content_type,
            } => FfiRequestBody {
                kind: FfiRequestBodyKind::Text,
                content,
                content_type,
                fields: vec![],
            },
            Body::Json { content } => FfiRequestBody {
                kind: FfiRequestBodyKind::Json,
                content: content.to_string(),
                content_type: None,
                fields: vec![],
            },
            Body::FormUrlEncoded { fields } => FfiRequestBody {
                kind: FfiRequestBodyKind::FormUrlEncoded,
                content: String::new(),
                content_type: None,
                fields: fields.into_iter().map(Into::into).collect(),
            },
            Body::Multipart { fields } => FfiRequestBody {
                kind: FfiRequestBodyKind::Multipart,
                content: String::new(),
                content_type: None,
                fields: fields.into_iter().map(Into::into).collect(),
            },
        };
        Self {
            id: value.id,
            name: value.name,
            method: value.method.into(),
            url: value.url,
            query_params: value.query_params.into_iter().map(Into::into).collect(),
            headers: value.headers.into_iter().map(Into::into).collect(),
            body,
            auth: match value.auth {
                RequestAuth::None => FfiRequestAuth {
                    kind: FfiRequestAuthKind::None,
                    username: String::new(),
                    password: String::new(),
                    token: String::new(),
                    key: String::new(),
                    value: String::new(),
                    placement: FfiApiKeyPlacement::Header,
                },
                RequestAuth::Basic { username, password } => FfiRequestAuth {
                    kind: FfiRequestAuthKind::Basic,
                    username,
                    password,
                    token: String::new(),
                    key: String::new(),
                    value: String::new(),
                    placement: FfiApiKeyPlacement::Header,
                },
                RequestAuth::Bearer { token } => FfiRequestAuth {
                    kind: FfiRequestAuthKind::Bearer,
                    username: String::new(),
                    password: String::new(),
                    token,
                    key: String::new(),
                    value: String::new(),
                    placement: FfiApiKeyPlacement::Header,
                },
                RequestAuth::ApiKey {
                    key,
                    value,
                    placement,
                } => FfiRequestAuth {
                    kind: FfiRequestAuthKind::ApiKey,
                    username: String::new(),
                    password: String::new(),
                    token: String::new(),
                    key,
                    value,
                    placement: placement.into(),
                },
            },
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
