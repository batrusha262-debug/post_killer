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
