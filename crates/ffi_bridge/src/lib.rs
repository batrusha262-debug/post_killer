//! Stable application-facing Rust API. flutter_rust_bridge code generation is intentionally
//! deferred until the Flutter shell and domain contract are established.

use post_killer_application::RequestExecutionService;
use post_killer_domain::{RequestDefinition, ValidationError};
use post_killer_http_engine::{
    ExecuteError, ExecutionOptions, ExecutionResult, ReqwestRequestExecutor,
};

pub fn validate_request(request: &RequestDefinition) -> Result<(), ValidationError> {
    RequestExecutionService::new(ReqwestRequestExecutor).validate(request)
}

pub async fn execute_request(request: RequestDefinition) -> Result<ExecutionResult, ExecuteError> {
    RequestExecutionService::new(ReqwestRequestExecutor)
        .execute(request, ExecutionOptions::default())
        .await
}

/// Executes with caller-controlled transport limits. This remains a typed boundary
/// so generated Flutter bindings do not need to know about reqwest.
pub async fn execute_request_with_options(
    request: RequestDefinition,
    options: ExecutionOptions,
) -> Result<ExecutionResult, ExecuteError> {
    RequestExecutionService::new(ReqwestRequestExecutor)
        .execute(request, options)
        .await
}

#[cfg(test)]
mod tests {
    use super::*;
    use post_killer_domain::{Body, RequestAuth, RequestMethod};

    #[test]
    fn validation_is_exposed_without_starting_transport() {
        let request = RequestDefinition {
            id: "request-1".into(),
            name: "Example".into(),
            method: RequestMethod::Get,
            url: String::new(),
            query_params: vec![],
            headers: vec![],
            body: Body::Empty,
            auth: RequestAuth::None,
        };

        assert!(validate_request(&request).is_err());
    }
}
