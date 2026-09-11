use super::*;

pub(super) fn resolve_auth(
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

pub(super) fn resolve_body(
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
        Body::Multipart { fields, files } => Ok(Body::Multipart {
            fields: resolve_fields(fields, variables)?,
            files: files
                .iter()
                .map(|file| {
                    Ok(MultipartFile {
                        field_name: resolve_template(&file.field_name, variables)?,
                        path: resolve_template(&file.path, variables)?,
                        file_name: file
                            .file_name
                            .as_deref()
                            .map(|value| resolve_template(value, variables))
                            .transpose()?,
                        content_type: file
                            .content_type
                            .as_deref()
                            .map(|value| resolve_template(value, variables))
                            .transpose()?,
                    })
                })
                .collect::<Result<Vec<_>, VariableResolutionError>>()?,
        }),
    }
}

pub(super) fn resolve_fields(
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

pub(super) fn resolve_json_value(
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

pub(super) fn resolve_template(
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
