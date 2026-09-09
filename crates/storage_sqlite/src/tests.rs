use super::*;

#[test]
fn fresh_database_is_migrated_and_supports_workspace_and_collection_crud() {
    let mut storage = SqliteStorage::open_in_memory().unwrap();

    let workspace = storage
        .create_workspace("workspace-1".into(), "Personal".into())
        .unwrap();
    let collection = storage
        .create_collection(
            "collection-1".into(),
            workspace.id.clone(),
            "Example API".into(),
        )
        .unwrap();

    assert_eq!(storage.list_workspaces().unwrap(), vec![workspace]);
    assert_eq!(
        storage.list_collections("workspace-1").unwrap(),
        vec![collection]
    );
    assert_eq!(
        storage
            .connection
            .query_row("SELECT COUNT(*) FROM schema_migrations", [], |row| row
                .get::<_, i64>(0))
            .unwrap(),
        5
    );
}

#[test]
fn collection_requires_an_existing_workspace() {
    let mut storage = SqliteStorage::open_in_memory().unwrap();

    let error = storage
        .create_collection(
            "collection-1".into(),
            "missing".into(),
            "Example API".into(),
        )
        .unwrap_err();

    assert!(matches!(
        error,
        StorageError::WorkspaceNotFound { id } if id == "missing"
    ));
}

#[test]
fn request_definition_round_trips_and_updates() {
    let mut storage = SqliteStorage::open_in_memory().unwrap();
    storage
        .create_workspace("workspace-1".into(), "Personal".into())
        .unwrap();
    storage
        .create_collection(
            "collection-1".into(),
            "workspace-1".into(),
            "Example API".into(),
        )
        .unwrap();

    let mut request = StoredRequest {
        collection_id: "collection-1".into(),
        folder_id: None,
        definition: RequestDefinition {
            id: "request-1".into(),
            name: "Create user".into(),
            method: RequestMethod::Post,
            url: "https://example.test/users".into(),
            query_params: vec![KeyValue {
                key: "dry_run".into(),
                value: "false".into(),
                enabled: true,
            }],
            headers: vec![KeyValue {
                key: "content-type".into(),
                value: "application/json".into(),
                enabled: true,
            }],
            body: Body::Json {
                content: serde_json::json!({"name": "Ada"}),
            },
            auth: RequestAuth::Bearer {
                token: "local-test-token".into(),
            },
        },
    };
    storage.save_request(request.clone()).unwrap();
    assert_eq!(
        storage.get_request("request-1").unwrap(),
        Some(request.clone())
    );

    request.definition.name = "Create an updated user".into();
    storage.save_request(request.clone()).unwrap();
    assert_eq!(storage.get_request("request-1").unwrap(), Some(request));
}

#[test]
fn v3_database_is_upgraded_without_losing_existing_requests() {
    let connection = Connection::open_in_memory().unwrap();
    connection
        .pragma_update(None, "foreign_keys", true)
        .unwrap();
    connection
        .execute_batch(
            "CREATE TABLE schema_migrations (\
                    version INTEGER PRIMARY KEY NOT NULL,\
                    name TEXT NOT NULL,\
                    applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP\
                 );",
        )
        .unwrap();
    connection.execute_batch(MIGRATION_V1).unwrap();
    connection.execute_batch(MIGRATION_V2).unwrap();
    connection.execute_batch(MIGRATION_V3).unwrap();
    connection
        .execute(
            "INSERT INTO schema_migrations (version, name) VALUES (1, 'initial')",
            [],
        )
        .unwrap();
    connection
        .execute(
            "INSERT INTO schema_migrations (version, name) VALUES (2, 'request_definition')",
            [],
        )
        .unwrap();
    connection
        .execute(
            "INSERT INTO schema_migrations (version, name) VALUES (3, 'relation_guards')",
            [],
        )
        .unwrap();
    connection
        .execute(
            "INSERT INTO workspaces (id, name) VALUES ('workspace-1', 'Personal')",
            [],
        )
        .unwrap();
    connection
            .execute(
                "INSERT INTO collections (id, workspace_id, name) VALUES ('collection-1', 'workspace-1', 'Example')",
                [],
            )
            .unwrap();
    connection
            .execute(
                "INSERT INTO requests (id, collection_id, name, method, url, query_params_json, headers_json, body_json) \
                 VALUES ('request-1', 'collection-1', 'Existing', '\"GET\"', 'https://example.test', '[]', '[]', '{\"kind\":\"empty\"}')",
                [],
            )
            .unwrap();

    let storage = SqliteStorage::from_connection(connection).unwrap();

    assert_eq!(storage.list_workspaces().unwrap().len(), 1);
    let stored = storage.get_request("request-1").unwrap().unwrap();
    assert_eq!(stored.definition.auth, RequestAuth::None);
    assert_eq!(
        storage
            .connection
            .query_row("SELECT COUNT(*) FROM schema_migrations", [], |row| row
                .get::<_, i64>(0))
            .unwrap(),
        5
    );
}

fn request(id: &str, collection_id: &str, folder_id: Option<&str>) -> StoredRequest {
    StoredRequest {
        collection_id: collection_id.into(),
        folder_id: folder_id.map(str::to_owned),
        definition: RequestDefinition {
            id: id.into(),
            name: "Example".into(),
            method: RequestMethod::Get,
            url: "https://example.test".into(),
            query_params: vec![],
            headers: vec![],
            body: Body::Empty,
            auth: RequestAuth::None,
        },
    }
}

fn storage_with_two_collections() -> SqliteStorage {
    let mut storage = SqliteStorage::open_in_memory().unwrap();
    storage
        .create_workspace("workspace-1".into(), "Personal".into())
        .unwrap();
    storage
        .create_collection("collection-1".into(), "workspace-1".into(), "One".into())
        .unwrap();
    storage
        .create_collection("collection-2".into(), "workspace-1".into(), "Two".into())
        .unwrap();
    storage
}

#[test]
fn folders_enforce_collection_and_parent_relations() {
    let mut storage = storage_with_two_collections();
    let root = Folder {
        id: "folder-root".into(),
        collection_id: "collection-1".into(),
        parent_folder_id: None,
        name: "Root".into(),
        sort_order: 0,
    };
    storage.save_folder(root.clone()).unwrap();
    let child = Folder {
        id: "folder-child".into(),
        collection_id: "collection-1".into(),
        parent_folder_id: Some(root.id.clone()),
        name: "Child".into(),
        sort_order: 2,
    };
    storage.save_folder(child.clone()).unwrap();
    assert_eq!(
        storage.list_folders("collection-1").unwrap(),
        vec![root, child]
    );

    let error = storage
        .save_folder(Folder {
            id: "wrong-parent".into(),
            collection_id: "collection-2".into(),
            parent_folder_id: Some("folder-root".into()),
            name: "Invalid".into(),
            sort_order: 0,
        })
        .unwrap_err();
    assert!(matches!(
        error,
        StorageError::ParentFolderCollectionMismatch { .. }
    ));
}

#[test]
fn environments_and_variables_round_trip_and_cascade() {
    let mut storage = SqliteStorage::open_in_memory().unwrap();
    storage
        .create_workspace("workspace-1".into(), "Personal".into())
        .unwrap();
    let environment = Environment {
        id: "environment-1".into(),
        workspace_id: "workspace-1".into(),
        name: "Local".into(),
    };
    storage.save_environment(environment.clone()).unwrap();
    let variable = EnvironmentVariable {
        id: "variable-1".into(),
        environment_id: environment.id.clone(),
        key: "base_url".into(),
        value: "https://localhost".into(),
        enabled: true,
    };
    storage.save_environment_variable(variable.clone()).unwrap();
    assert_eq!(
        storage.get_environment("environment-1").unwrap(),
        Some(environment)
    );
    assert_eq!(
        storage.list_environment_variables("environment-1").unwrap(),
        vec![variable]
    );
    storage.delete_environment("environment-1").unwrap();
    assert!(
        storage
            .list_environment_variables("environment-1")
            .unwrap()
            .is_empty()
    );
}

#[test]
fn request_can_only_move_inside_its_collection_or_to_root() {
    let mut storage = storage_with_two_collections();
    storage
        .save_folder(Folder {
            id: "folder-1".into(),
            collection_id: "collection-1".into(),
            parent_folder_id: None,
            name: "One".into(),
            sort_order: 0,
        })
        .unwrap();
    storage
        .save_folder(Folder {
            id: "folder-2".into(),
            collection_id: "collection-2".into(),
            parent_folder_id: None,
            name: "Two".into(),
            sort_order: 0,
        })
        .unwrap();
    storage
        .save_request(request("request-1", "collection-1", None))
        .unwrap();
    storage
        .move_request("request-1", Some("folder-1".into()))
        .unwrap();
    assert_eq!(
        storage
            .get_request("request-1")
            .unwrap()
            .unwrap()
            .folder_id
            .as_deref(),
        Some("folder-1")
    );
    let error = storage
        .move_request("request-1", Some("folder-2".into()))
        .unwrap_err();
    assert!(
        matches!(error, StorageError::RequestFolderCollectionMismatch { request_id, .. } if request_id == "request-1")
    );
    storage.move_request("request-1", None).unwrap();
    assert_eq!(storage.list_requests("collection-1").unwrap().len(), 1);
    storage.delete_request("request-1").unwrap();
    assert!(storage.get_request("request-1").unwrap().is_none());
}

#[test]
fn execution_history_round_trips_metadata_without_payload_fields() {
    let mut storage = storage_with_two_collections();
    storage
        .save_request(request("request-1", "collection-1", None))
        .unwrap();
    let completed = ExecutionHistoryRecord {
        execution_id: "execution-2".into(),
        request_id: "request-1".into(),
        executed_at_unix_ms: 200,
        status_code: Some(201),
        duration_ms: 42,
        response_size_bytes: 512,
        result_kind: ExecutionResultKind::Response,
        error_category: None,
    };
    let failed = ExecutionHistoryRecord {
        execution_id: "execution-1".into(),
        request_id: "request-1".into(),
        executed_at_unix_ms: 100,
        status_code: None,
        duration_ms: 5,
        response_size_bytes: 0,
        result_kind: ExecutionResultKind::Error,
        error_category: Some(ExecutionErrorCategory::Timeout),
    };
    storage.append_execution_history(failed.clone()).unwrap();
    storage.append_execution_history(completed.clone()).unwrap();

    assert_eq!(
        storage.list_execution_history("request-1").unwrap(),
        vec![completed.clone(), failed]
    );
    storage
        .delete_execution_history("request-1", "execution-2")
        .unwrap();
    assert_eq!(storage.clear_execution_history("request-1").unwrap(), 1);
    assert!(
        storage
            .list_execution_history("request-1")
            .unwrap()
            .is_empty()
    );
}

#[test]
fn execution_history_rejects_invalid_result_metadata() {
    let mut storage = storage_with_two_collections();
    storage
        .save_request(request("request-1", "collection-1", None))
        .unwrap();
    let error = storage
        .append_execution_history(ExecutionHistoryRecord {
            execution_id: "execution-1".into(),
            request_id: "request-1".into(),
            executed_at_unix_ms: 0,
            status_code: Some(500),
            duration_ms: 0,
            response_size_bytes: 0,
            result_kind: ExecutionResultKind::Error,
            error_category: None,
        })
        .unwrap_err();
    assert!(matches!(
        error,
        StorageError::InvalidInput {
            entity: "execution history",
            field: "result_kind"
        }
    ));
}

#[test]
fn folder_updates_reject_cycles_and_cross_collection_descendants() {
    let mut storage = SqliteStorage::open_in_memory().unwrap();
    storage
        .create_workspace("w".into(), "Workspace".into())
        .unwrap();
    for id in ["c1", "c2"] {
        storage
            .create_collection(id.into(), "w".into(), id.into())
            .unwrap();
    }
    let parent = Folder {
        id: "parent".into(),
        collection_id: "c1".into(),
        parent_folder_id: None,
        name: "Parent".into(),
        sort_order: 0,
    };
    let child = Folder {
        id: "child".into(),
        parent_folder_id: Some("parent".into()),
        ..parent.clone()
    };
    storage.save_folder(parent.clone()).unwrap();
    storage.save_folder(child).unwrap();
    assert!(
        storage
            .save_folder(Folder {
                parent_folder_id: Some("child".into()),
                ..parent.clone()
            })
            .is_err()
    );
    assert!(
        storage
            .save_folder(Folder {
                collection_id: "c2".into(),
                ..parent.clone()
            })
            .is_err()
    );
    assert_eq!(storage.get_folder("parent").unwrap(), Some(parent));
}
