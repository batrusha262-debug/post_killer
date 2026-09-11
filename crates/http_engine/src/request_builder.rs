use super::*;
use std::sync::{Arc, OnceLock};

const MAX_MULTIPART_FILE_BYTES: u64 = 50 * 1024 * 1024;
static SESSION_COOKIE_JAR: OnceLock<Arc<reqwest::cookie::Jar>> = OnceLock::new();

fn session_cookie_jar() -> Arc<reqwest::cookie::Jar> {
    SESSION_COOKIE_JAR
        .get_or_init(|| Arc::new(reqwest::cookie::Jar::default()))
        .clone()
}

pub(super) fn build_request(
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
        // Kept in native process memory only. Cookies disappear when the app
        // exits and are never persisted/exported/recorded in history.
        .cookie_provider(session_cookie_jar())
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
    apply_body(builder, &request.body, has_content_type)
}

fn apply_body(
    mut builder: reqwest::RequestBuilder,
    body: &Body,
    has_content_type: bool,
) -> Result<reqwest::RequestBuilder, ExecuteError> {
    match body {
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
        Body::Multipart { fields, files } => {
            let mut form = enabled_pairs(fields)
                .into_iter()
                .fold(reqwest::multipart::Form::new(), |form, (key, value)| {
                    form.text(key.to_owned(), value.to_owned())
                });
            for file in files {
                let metadata =
                    std::fs::metadata(&file.path).map_err(|_| ExecuteError::MultipartFileRead)?;
                if metadata.len() > MAX_MULTIPART_FILE_BYTES {
                    return Err(ExecuteError::MultipartFileTooLarge {
                        limit: MAX_MULTIPART_FILE_BYTES as usize,
                    });
                }
                let bytes =
                    std::fs::read(&file.path).map_err(|_| ExecuteError::MultipartFileRead)?;
                let mut part = reqwest::multipart::Part::bytes(bytes);
                if let Some(file_name) = &file.file_name {
                    part = part.file_name(file_name.clone());
                }
                if let Some(content_type) = &file.content_type {
                    part = part.mime_str(content_type).map_err(|_| {
                        ExecuteError::InvalidHeaderValue {
                            name: "multipart content-type".to_owned(),
                        }
                    })?;
                }
                form = form.part(file.field_name.clone(), part);
            }
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
                let url_has_key = reqwest::Url::parse(request.url.trim())
                    .is_ok_and(|url| url.query_pairs().any(|(name, _)| name == key.as_str()));
                if !has_enabled_key(&request.query_params, key) && !url_has_key {
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
