//! Shared, transport-independent request and collection domain types.

mod variables;
use variables::*;

use serde::{Deserialize, Serialize};
use std::{collections::BTreeMap, fmt};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "UPPERCASE")]
pub enum RequestMethod {
    #[default]
    Get,
    Post,
    Put,
    Patch,
    Delete,
    Head,
    Options,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct KeyValue {
    pub key: String,
    pub value: String,
    #[serde(default = "enabled_by_default")]
    pub enabled: bool,
}

/// An explicit local attachment reference. File contents are read only by the
/// native transport at send time; neither SQLite history nor diagnostics own
/// those bytes.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MultipartFile {
    pub field_name: String,
    pub path: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub file_name: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub content_type: Option<String>,
}

const fn enabled_by_default() -> bool {
    true
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Body {
    #[default]
    Empty,
    Text {
        content: String,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        content_type: Option<String>,
    },
    Json {
        content: serde_json::Value,
    },
    FormUrlEncoded {
        fields: Vec<KeyValue>,
    },
    Multipart {
        fields: Vec<KeyValue>,
        #[serde(default)]
        files: Vec<MultipartFile>,
    },
}

/// Where an API key is injected when request authentication is enabled.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum ApiKeyPlacement {
    #[default]
    Header,
    Query,
}

/// Request-scoped authentication. These are owned, serializable configuration
/// values; callers must ensure secrets are redacted before any diagnostic output.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum RequestAuth {
    #[default]
    None,
    Basic {
        username: String,
        password: String,
    },
    Bearer {
        token: String,
    },
    ApiKey {
        key: String,
        value: String,
        placement: ApiKeyPlacement,
    },
}

impl fmt::Debug for RequestAuth {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let kind = match self {
            Self::None => "None",
            Self::Basic { .. } => "Basic",
            Self::Bearer { .. } => "Bearer",
            Self::ApiKey { .. } => "ApiKey",
        };
        formatter
            .debug_struct(kind)
            .field("credentials", &"<redacted>")
            .finish()
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RequestDefinition {
    pub id: String,
    pub name: String,
    pub method: RequestMethod,
    pub url: String,
    #[serde(default)]
    pub query_params: Vec<KeyValue>,
    #[serde(default)]
    pub headers: Vec<KeyValue>,
    #[serde(default)]
    pub body: Body,
    /// Absent authentication in existing imports and stored JSON means no auth.
    #[serde(default)]
    pub auth: RequestAuth,
}

impl RequestDefinition {
    /// Performs inexpensive validation safe to run before handing a request to a transport.
    pub fn validate(&self) -> Result<(), ValidationError> {
        if self.url.trim().is_empty() {
            return Err(ValidationError::EmptyUrl);
        }

        validate_keys("query parameter", &self.query_params)?;
        validate_keys("header", &self.headers)?;

        match &self.body {
            Body::FormUrlEncoded { fields } | Body::Multipart { fields, .. } => {
                validate_keys("body field", fields)?;
            }
            Body::Empty | Body::Text { .. } | Body::Json { .. } => {}
        }

        if let Body::Multipart { files, .. } = &self.body
            && files
                .iter()
                .any(|file| file.field_name.trim().is_empty() || file.path.trim().is_empty())
        {
            return Err(ValidationError::EmptyMultipartFileField);
        }

        validate_auth(&self.auth)?;

        Ok(())
    }

    /// Returns a request copy with `{{variable}}` placeholders resolved from the
    /// selected environment. Resolution is pure: it never reads storage or logs
    /// values, so callers can use it for previews and execution alike.
    pub fn resolve_variables(
        &self,
        variables: &BTreeMap<String, String>,
    ) -> Result<Self, VariableResolutionError> {
        let mut resolved = self.clone();
        resolved.url = resolve_template(&resolved.url, variables)?;
        resolved.query_params = resolve_fields(&resolved.query_params, variables)?;
        resolved.headers = resolve_fields(&resolved.headers, variables)?;
        resolved.body = resolve_body(&resolved.body, variables)?;
        resolved.auth = resolve_auth(&resolved.auth, variables)?;
        resolved
            .validate()
            .map_err(VariableResolutionError::InvalidRequest)?;
        Ok(resolved)
    }
}

fn validate_auth(auth: &RequestAuth) -> Result<(), ValidationError> {
    let empty = |scheme, field| ValidationError::EmptyAuthenticationField { scheme, field };
    match auth {
        RequestAuth::None => Ok(()),
        RequestAuth::Basic { username, password } => {
            if username.trim().is_empty() {
                Err(empty("basic", "username"))
            } else if password.trim().is_empty() {
                Err(empty("basic", "password"))
            } else {
                Ok(())
            }
        }
        RequestAuth::Bearer { token } if token.trim().is_empty() => Err(empty("bearer", "token")),
        RequestAuth::Bearer { .. } => Ok(()),
        RequestAuth::ApiKey { key, value, .. } => {
            if key.trim().is_empty() {
                Err(empty("api_key", "key"))
            } else if value.trim().is_empty() {
                Err(empty("api_key", "value"))
            } else {
                Ok(())
            }
        }
    }
}

fn validate_keys(field_kind: &'static str, fields: &[KeyValue]) -> Result<(), ValidationError> {
    if fields
        .iter()
        .any(|field| field.enabled && field.key.trim().is_empty())
    {
        return Err(ValidationError::EmptyEnabledKey { field_kind });
    }
    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ValidationError {
    EmptyUrl,
    EmptyEnabledKey {
        field_kind: &'static str,
    },
    EmptyAuthenticationField {
        scheme: &'static str,
        field: &'static str,
    },
    EmptyMultipartFileField,
}

impl fmt::Display for ValidationError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyUrl => formatter.write_str("request URL must not be empty"),
            Self::EmptyEnabledKey { field_kind } => {
                write!(formatter, "enabled {field_kind} must have a key")
            }
            Self::EmptyAuthenticationField { scheme, field } => {
                write!(
                    formatter,
                    "{scheme} authentication {field} must not be empty"
                )
            }
            Self::EmptyMultipartFileField => {
                formatter.write_str("multipart file field and path must not be empty")
            }
        }
    }
}

impl std::error::Error for ValidationError {}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum VariableResolutionError {
    EmptyReference,
    UnterminatedReference,
    MissingVariable { name: String },
    InvalidRequest(ValidationError),
}

impl fmt::Display for VariableResolutionError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyReference => formatter.write_str("variable reference must have a name"),
            Self::UnterminatedReference => formatter.write_str("unterminated variable reference"),
            Self::MissingVariable { name } => write!(formatter, "variable '{name}' is not defined"),
            Self::InvalidRequest(error) => {
                write!(formatter, "resolved request is invalid: {error}")
            }
        }
    }
}

impl std::error::Error for VariableResolutionError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::InvalidRequest(error) => Some(error),
            Self::EmptyReference | Self::UnterminatedReference | Self::MissingVariable { .. } => {
                None
            }
        }
    }
}

#[cfg(test)]
#[path = "tests.rs"]
mod tests;
