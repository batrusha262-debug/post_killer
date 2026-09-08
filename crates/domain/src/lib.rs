//! Shared, transport-independent request and collection domain types.

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
            Body::FormUrlEncoded { fields } | Body::Multipart { fields } => {
                validate_keys("body field", fields)?;
            }
            Body::Empty | Body::Text { .. } | Body::Json { .. } => {}
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
        for field in &mut resolved.query_params {
            if !field.enabled {
                continue;
            }
            field.key = resolve_template(&field.key, variables)?;
            field.value = resolve_template(&field.value, variables)?;
        }
        for field in &mut resolved.headers {
            if !field.enabled {
                continue;
            }
            field.key = resolve_template(&field.key, variables)?;
            field.value = resolve_template(&field.value, variables)?;
        }
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

fn resolve_auth(
    auth: &RequestAuth,
    variables: &BTreeMap<String, String>,
) -> Result<RequestAuth, VariableResolutionError> {
    match auth {
        RequestAuth::None => Ok(RequestAuth::None),
        RequestAuth::Basic { username, password } => Ok(RequestAuth::Basic {
            username: resolve_template(username, variables)?,
            password: resolve_template(password, variables)?,
        }),
        RequestAuth::Bearer { token } => Ok(RequestAuth::Bearer {
            token: resolve_template(token, variables)?,
        }),
        RequestAuth::ApiKey {
            key,
            value,
            placement,
        } => Ok(RequestAuth::ApiKey {
            key: resolve_template(key, variables)?,
            value: resolve_template(value, variables)?,
            placement: *placement,
        }),
    }
}

fn resolve_body(
    body: &Body,
    variables: &BTreeMap<String, String>,
) -> Result<Body, VariableResolutionError> {
    match body {
        Body::Empty => Ok(Body::Empty),
        Body::Text {
            content,
            content_type,
        } => Ok(Body::Text {
            content: resolve_template(content, variables)?,
            content_type: content_type
                .as_deref()
                .map(|value| resolve_template(value, variables))
                .transpose()?,
        }),
        Body::Json { content } => Ok(Body::Json {
            content: resolve_json_value(content, variables)?,
        }),
        Body::FormUrlEncoded { fields } => Ok(Body::FormUrlEncoded {
            fields: resolve_fields(fields, variables)?,
        }),
        Body::Multipart { fields } => Ok(Body::Multipart {
            fields: resolve_fields(fields, variables)?,
        }),
    }
}

fn resolve_fields(
    fields: &[KeyValue],
    variables: &BTreeMap<String, String>,
) -> Result<Vec<KeyValue>, VariableResolutionError> {
    fields
        .iter()
        .map(|field| {
            if !field.enabled {
                return Ok(field.clone());
            }
            Ok(KeyValue {
                key: resolve_template(&field.key, variables)?,
                value: resolve_template(&field.value, variables)?,
                enabled: field.enabled,
            })
        })
        .collect()
}

fn resolve_json_value(
    value: &serde_json::Value,
    variables: &BTreeMap<String, String>,
) -> Result<serde_json::Value, VariableResolutionError> {
    match value {
        serde_json::Value::String(value) => Ok(serde_json::Value::String(resolve_template(
            value, variables,
        )?)),
        serde_json::Value::Array(values) => values
            .iter()
            .map(|value| resolve_json_value(value, variables))
            .collect::<Result<Vec<_>, _>>()
            .map(serde_json::Value::Array),
        serde_json::Value::Object(values) => values
            .iter()
            .map(|(key, value)| Ok((key.clone(), resolve_json_value(value, variables)?)))
            .collect::<Result<serde_json::Map<_, _>, _>>()
            .map(serde_json::Value::Object),
        other => Ok(other.clone()),
    }
}

fn resolve_template(
    template: &str,
    variables: &BTreeMap<String, String>,
) -> Result<String, VariableResolutionError> {
    let mut resolved = String::with_capacity(template.len());
    let mut remaining = template;
    while let Some(open_index) = remaining.find("{{") {
        resolved.push_str(&remaining[..open_index]);
        let after_open = &remaining[open_index + 2..];
        let Some(close_index) = after_open.find("}}") else {
            return Err(VariableResolutionError::UnterminatedReference);
        };
        let name = after_open[..close_index].trim();
        if name.is_empty() {
            return Err(VariableResolutionError::EmptyReference);
        }
        let value =
            variables
                .get(name)
                .ok_or_else(|| VariableResolutionError::MissingVariable {
                    name: name.to_owned(),
                })?;
        resolved.push_str(value);
        remaining = &after_open[close_index + 2..];
    }
    resolved.push_str(remaining);
    Ok(resolved)
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
mod tests {
    use super::*;

    fn valid_request() -> RequestDefinition {
        RequestDefinition {
            id: "request-1".into(),
            name: "Example".into(),
            method: RequestMethod::Get,
            url: "https://example.com".into(),
            query_params: vec![],
            headers: vec![],
            body: Body::Empty,
            auth: RequestAuth::None,
        }
    }

    #[test]
    fn methods_serialize_as_http_tokens() {
        assert_eq!(
            serde_json::to_string(&RequestMethod::Patch).unwrap(),
            "\"PATCH\""
        );
    }

    #[test]
    fn valid_request_passes_validation() {
        assert_eq!(valid_request().validate(), Ok(()));
    }

    #[test]
    fn empty_url_is_rejected() {
        let mut request = valid_request();
        request.url = "  ".into();
        assert_eq!(request.validate(), Err(ValidationError::EmptyUrl));
    }

    #[test]
    fn enabled_empty_header_key_is_rejected() {
        let mut request = valid_request();
        request.headers.push(KeyValue {
            key: String::new(),
            value: "application/json".into(),
            enabled: true,
        });

        assert_eq!(
            request.validate(),
            Err(ValidationError::EmptyEnabledKey {
                field_kind: "header"
            })
        );
    }

    #[test]
    fn disabled_empty_key_is_allowed() {
        let mut request = valid_request();
        request.query_params.push(KeyValue {
            key: String::new(),
            value: String::new(),
            enabled: false,
        });
        assert_eq!(request.validate(), Ok(()));
    }

    #[test]
    fn resolves_request_variables_without_mutating_the_original() {
        let mut request = valid_request();
        request.url = "https://{{host}}/users/{{user_id}}".into();
        request.query_params = vec![KeyValue {
            key: "filter".into(),
            value: "{{user_id}}".into(),
            enabled: true,
        }];
        request.headers = vec![KeyValue {
            key: "authorization".into(),
            value: "Bearer {{token}}".into(),
            enabled: true,
        }];
        request.body = Body::Json {
            content: serde_json::json!({"id": "{{user_id}}", "nested": ["{{host}}"]}),
        };
        request.auth = RequestAuth::Bearer {
            token: "{{token}}".into(),
        };
        let variables = BTreeMap::from([
            ("host".into(), "api.example.test".into()),
            ("user_id".into(), "42".into()),
            ("token".into(), "secret-value".into()),
        ]);

        let resolved = request.resolve_variables(&variables).unwrap();

        assert_eq!(request.url, "https://{{host}}/users/{{user_id}}");
        assert_eq!(resolved.url, "https://api.example.test/users/42");
        assert_eq!(resolved.query_params[0].value, "42");
        assert_eq!(resolved.headers[0].value, "Bearer secret-value");
        assert_eq!(
            resolved.auth,
            RequestAuth::Bearer {
                token: "secret-value".into()
            }
        );
        assert_eq!(
            resolved.body,
            Body::Json {
                content: serde_json::json!({"id": "42", "nested": ["api.example.test"]}),
            }
        );
    }

    #[test]
    fn reports_missing_and_malformed_variable_references() {
        let mut request = valid_request();
        request.url = "https://{{missing}}.example.test".into();
        assert_eq!(
            request.resolve_variables(&BTreeMap::new()),
            Err(VariableResolutionError::MissingVariable {
                name: "missing".into(),
            })
        );

        request.url = "https://example.test/{{unterminated".into();
        assert_eq!(
            request.resolve_variables(&BTreeMap::new()),
            Err(VariableResolutionError::UnterminatedReference)
        );
    }

    #[test]
    fn authentication_requires_all_enabled_scheme_fields() {
        let mut request = valid_request();
        request.auth = RequestAuth::Basic {
            username: "ada".into(),
            password: " ".into(),
        };
        assert_eq!(
            request.validate(),
            Err(ValidationError::EmptyAuthenticationField {
                scheme: "basic",
                field: "password"
            })
        );

        request.auth = RequestAuth::ApiKey {
            key: "X-API-Key".into(),
            value: String::new(),
            placement: ApiKeyPlacement::Header,
        };
        assert_eq!(
            request.validate(),
            Err(ValidationError::EmptyAuthenticationField {
                scheme: "api_key",
                field: "value"
            })
        );
    }

    #[test]
    fn missing_authentication_field_deserializes_to_none() {
        let serialized = serde_json::json!({
            "id": "request-1", "name": "Example", "method": "GET",
            "url": "https://example.test"
        });
        let request: RequestDefinition = serde_json::from_value(serialized).unwrap();
        assert_eq!(request.auth, RequestAuth::None);
    }

    #[test]
    fn authentication_debug_output_redacts_credentials() {
        let auth = RequestAuth::Bearer {
            token: "never-log-this-token".into(),
        };
        assert!(!format!("{auth:?}").contains("never-log-this-token"));
    }
}
