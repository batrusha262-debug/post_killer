//! Asynchronous HTTP request execution for the native application core.

use futures_util::StreamExt;
use post_killer_application::RequestExecutor;
use post_killer_domain::{
    ApiKeyPlacement, Body, RequestAuth, RequestDefinition, RequestMethod, ValidationError,
};
use reqwest::{
    Client,
    header::{CONTENT_TYPE, HeaderName, HeaderValue},
    redirect::Policy,
};
use serde::{Deserialize, Serialize};
use std::{fmt, time::Duration};
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

mod types;
pub use types::*;
mod request_builder;
use request_builder::build_request;
mod streaming;
pub use streaming::execute_streaming;

const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);
const DEFAULT_MAX_RESPONSE_BYTES: usize = 10 * 1024 * 1024;
const DEFAULT_MAX_REDIRECTS: usize = 10;

/// Reqwest/Rustls outbound adapter. The application core only sees the
/// [`RequestExecutor`] port, never this concrete transport.
#[derive(Debug, Default, Clone, Copy)]
pub struct ReqwestRequestExecutor;

impl RequestExecutor for ReqwestRequestExecutor {
    type Options = ExecutionOptions;
    type Response = ExecutionResult;
    type Error = ExecuteError;

    async fn execute(
        &self,
        request: RequestDefinition,
        options: Self::Options,
    ) -> Result<Self::Response, Self::Error> {
        execute_with_options(request, options).await
    }
}

/// Executes using conservative defaults while retaining the original public signature.
pub async fn execute(request: RequestDefinition) -> Result<ExecutionResult, ExecuteError> {
    execute_with_options(request, ExecutionOptions::default()).await
}

pub async fn execute_with_options(
    request: RequestDefinition,
    options: ExecutionOptions,
) -> Result<ResponsePayload, ExecuteError> {
    request.validate().map_err(ExecuteError::InvalidRequest)?;

    let builder = build_request(&request, options)?;

    let started_at = std::time::Instant::now();
    let response = builder.send().await.map_err(classify_transport)?;
    let status = response.status().as_u16();
    let effective_url = response.url().as_str().to_owned();
    let headers = response
        .headers()
        .iter()
        .map(|(name, value)| ResponseHeader {
            name: name.as_str().to_owned(),
            value: value.as_bytes().to_vec(),
        })
        .collect();
    if response
        .content_length()
        .is_some_and(|length| length > options.max_response_bytes as u64)
    {
        return Err(ExecuteError::ResponseTooLarge {
            limit: options.max_response_bytes,
        });
    }

    let mut body = Vec::new();
    let mut chunks = response.bytes_stream();
    while let Some(chunk) = chunks.next().await {
        let chunk = chunk.map_err(classify_transport)?;
        if chunk.len() > options.max_response_bytes.saturating_sub(body.len()) {
            return Err(ExecuteError::ResponseTooLarge {
                limit: options.max_response_bytes,
            });
        }
        body.extend_from_slice(&chunk);
    }
    Ok(ResponsePayload {
        request_id: request.id,
        status,
        headers,
        body,
        effective_url,
        duration: started_at.elapsed(),
    })
}

fn classify_transport(error: reqwest::Error) -> ExecuteError {
    if error.is_timeout() {
        ExecuteError::Timeout
    } else if error.is_connect() {
        ExecuteError::Transport(TransportErrorKind::Connect)
    } else if error.is_request() || error.is_builder() {
        ExecuteError::Transport(TransportErrorKind::Request)
    } else if error.is_decode() {
        ExecuteError::Transport(TransportErrorKind::Decode)
    } else {
        ExecuteError::Transport(TransportErrorKind::Other)
    }
}

#[cfg(test)]
#[path = "tests.rs"]
mod tests;
