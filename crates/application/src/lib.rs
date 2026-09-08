//! Hexagonal application core: use-cases depend on ports, never adapters.

use post_killer_domain::{RequestDefinition, ValidationError};
use std::future::Future;

/// Outbound port for request transport. Each adapter owns its protocol-specific
/// options, response and error types; the use-case only owns orchestration.
pub trait RequestExecutor {
    type Options;
    type Response;
    type Error;

    fn execute(
        &self,
        request: RequestDefinition,
        options: Self::Options,
    ) -> impl Future<Output = Result<Self::Response, Self::Error>> + Send;
}

/// Coarse-grained request use-case, generic over an injected outbound adapter.
#[derive(Debug, Clone)]
pub struct RequestExecutionService<E> {
    executor: E,
}

impl<E> RequestExecutionService<E> {
    pub fn new(executor: E) -> Self {
        Self { executor }
    }

    pub fn validate(&self, request: &RequestDefinition) -> Result<(), ValidationError> {
        request.validate()
    }
}

impl<E: RequestExecutor> RequestExecutionService<E> {
    pub async fn execute(
        &self,
        request: RequestDefinition,
        options: E::Options,
    ) -> Result<E::Response, E::Error> {
        self.executor.execute(request, options).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use post_killer_domain::{Body, RequestAuth, RequestMethod};

    #[derive(Debug)]
    struct FakeExecutor;

    impl RequestExecutor for FakeExecutor {
        type Options = ();
        type Response = &'static str;
        type Error = ();

        async fn execute(
            &self,
            _request: RequestDefinition,
            _options: Self::Options,
        ) -> Result<Self::Response, Self::Error> {
            Ok("fake-response")
        }
    }

    fn request() -> RequestDefinition {
        RequestDefinition {
            id: "request-1".into(),
            name: "Example".into(),
            method: RequestMethod::Get,
            url: "https://example.test".into(),
            query_params: vec![],
            headers: vec![],
            body: Body::Empty,
            auth: RequestAuth::None,
        }
    }

    #[tokio::test]
    async fn use_case_runs_against_a_fake_without_http_or_database() {
        let service = RequestExecutionService::new(FakeExecutor);
        assert_eq!(service.execute(request(), ()).await, Ok("fake-response"));
    }
}
