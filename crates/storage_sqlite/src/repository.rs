use super::*;

impl Repository for SqliteStorage {
    fn create_workspace(&mut self, id: String, name: String) -> Result<Workspace, StorageError> {
        validate_non_empty("workspace", "id", &id)?;
        validate_non_empty("workspace", "name", &name)?;

        let workspace = Workspace { id, name };
        let transaction = self.begin_write()?;
        let result = transaction.execute(
            "INSERT INTO workspaces (id, name) VALUES (?1, ?2)",
            (&workspace.id, &workspace.name),
        );
        map_insert_result(result, "workspace", &workspace.id)?;
        transaction.commit()?;
        Ok(workspace)
    }

    fn list_workspaces(&self) -> Result<Vec<Workspace>, StorageError> {
        let mut statement = self
            .connection
            .prepare("SELECT id, name FROM workspaces ORDER BY created_at ASC, id ASC")?;
        let workspaces = statement
            .query_map([], |row| {
                Ok(Workspace {
                    id: row.get(0)?,
                    name: row.get(1)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(workspaces)
    }

    fn delete_workspace(&mut self, id: &str) -> Result<(), StorageError> {
        validate_non_empty("workspace", "id", id)?;
        let changed = self
            .connection
            .execute("DELETE FROM workspaces WHERE id = ?1", [id])?;
        if changed == 0 {
            return Err(StorageError::WorkspaceNotFound { id: id.to_owned() });
        }
        Ok(())
    }

    fn create_collection(
        &mut self,
        id: String,
        workspace_id: String,
        name: String,
    ) -> Result<Collection, StorageError> {
        validate_non_empty("collection", "id", &id)?;
        validate_non_empty("collection", "workspace_id", &workspace_id)?;
        validate_non_empty("collection", "name", &name)?;

        let collection = Collection {
            id,
            workspace_id,
            name,
        };
        let transaction = self.begin_write()?;
        ensure_workspace_exists(&transaction, &collection.workspace_id)?;
        let result = transaction.execute(
            "INSERT INTO collections (id, workspace_id, name) VALUES (?1, ?2, ?3)",
            (&collection.id, &collection.workspace_id, &collection.name),
        );
        map_insert_result(result, "collection", &collection.id)?;
        transaction.commit()?;
        Ok(collection)
    }

    fn list_collections(&self, workspace_id: &str) -> Result<Vec<Collection>, StorageError> {
        validate_non_empty("collection", "workspace_id", workspace_id)?;

        let mut statement = self.connection.prepare(
            "SELECT id, workspace_id, name FROM collections \
             WHERE workspace_id = ?1 ORDER BY created_at ASC, id ASC",
        )?;
        let collections = statement
            .query_map([workspace_id], |row| {
                Ok(Collection {
                    id: row.get(0)?,
                    workspace_id: row.get(1)?,
                    name: row.get(2)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(collections)
    }

    fn delete_collection(&mut self, id: &str) -> Result<(), StorageError> {
        validate_non_empty("collection", "id", id)?;
        let changed = self
            .connection
            .execute("DELETE FROM collections WHERE id = ?1", [id])?;
        if changed == 0 {
            return Err(StorageError::CollectionNotFound { id: id.to_owned() });
        }
        Ok(())
    }

    fn save_folder(&mut self, folder: Folder) -> Result<(), StorageError> {
        validate_non_empty("folder", "id", &folder.id)?;
        validate_non_empty("folder", "collection_id", &folder.collection_id)?;
        validate_non_empty("folder", "name", &folder.name)?;

        let transaction = self.begin_write()?;
        ensure_collection_exists(&transaction, &folder.collection_id)?;
        validate_folder_links(&transaction, &folder)?;
        if let Some(parent_folder_id) = &folder.parent_folder_id {
            validate_non_empty("folder", "parent_folder_id", parent_folder_id)?;
            if parent_folder_id == &folder.id {
                return Err(StorageError::ParentFolderCollectionMismatch {
                    folder_id: folder.id.clone(),
                    parent_folder_id: parent_folder_id.clone(),
                });
            }
            ensure_folder_in_collection(&transaction, parent_folder_id, &folder.collection_id)
                .map_err(|error| match error {
                    StorageError::RequestFolderCollectionMismatch { .. } => {
                        StorageError::ParentFolderCollectionMismatch {
                            folder_id: folder.id.clone(),
                            parent_folder_id: parent_folder_id.clone(),
                        }
                    }
                    other => other,
                })?;
        }
        transaction.execute(
            "INSERT INTO folders (id, collection_id, parent_folder_id, name, sort_order) \
             VALUES (?1, ?2, ?3, ?4, ?5) \
             ON CONFLICT(id) DO UPDATE SET collection_id = excluded.collection_id, \
             parent_folder_id = excluded.parent_folder_id, name = excluded.name, \
             sort_order = excluded.sort_order, updated_at = CURRENT_TIMESTAMP",
            (
                &folder.id,
                &folder.collection_id,
                &folder.parent_folder_id,
                &folder.name,
                folder.sort_order,
            ),
        )?;
        transaction.commit()?;
        Ok(())
    }

    fn get_folder(&self, id: &str) -> Result<Option<Folder>, StorageError> {
        validate_non_empty("folder", "id", id)?;
        self.connection.query_row(
            "SELECT id, collection_id, parent_folder_id, name, sort_order FROM folders WHERE id = ?1",
            [id],
            decode_folder,
        ).optional().map_err(StorageError::Database)
    }

    fn list_folders(&self, collection_id: &str) -> Result<Vec<Folder>, StorageError> {
        validate_non_empty("folder", "collection_id", collection_id)?;
        let mut statement = self.connection.prepare(
            "SELECT id, collection_id, parent_folder_id, name, sort_order FROM folders \
             WHERE collection_id = ?1 ORDER BY sort_order ASC, created_at ASC, id ASC",
        )?;
        statement
            .query_map([collection_id], decode_folder)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(StorageError::Database)
    }

    fn delete_folder(&mut self, id: &str) -> Result<(), StorageError> {
        validate_non_empty("folder", "id", id)?;
        let changed = self
            .connection
            .execute("DELETE FROM folders WHERE id = ?1", [id])?;
        if changed == 0 {
            return Err(StorageError::FolderNotFound { id: id.to_owned() });
        }
        Ok(())
    }

    fn save_environment(&mut self, environment: Environment) -> Result<(), StorageError> {
        validate_non_empty("environment", "id", &environment.id)?;
        validate_non_empty("environment", "workspace_id", &environment.workspace_id)?;
        validate_non_empty("environment", "name", &environment.name)?;
        let transaction = self.begin_write()?;
        ensure_workspace_exists(&transaction, &environment.workspace_id)?;
        transaction.execute(
            "INSERT INTO environments (id, workspace_id, name) VALUES (?1, ?2, ?3) \
             ON CONFLICT(id) DO UPDATE SET workspace_id = excluded.workspace_id, name = excluded.name, updated_at = CURRENT_TIMESTAMP",
            (&environment.id, &environment.workspace_id, &environment.name),
        )?;
        transaction.commit()?;
        Ok(())
    }

    fn get_environment(&self, id: &str) -> Result<Option<Environment>, StorageError> {
        validate_non_empty("environment", "id", id)?;
        self.connection
            .query_row(
                "SELECT id, workspace_id, name FROM environments WHERE id = ?1",
                [id],
                decode_environment,
            )
            .optional()
            .map_err(StorageError::Database)
    }

    fn list_environments(&self, workspace_id: &str) -> Result<Vec<Environment>, StorageError> {
        validate_non_empty("environment", "workspace_id", workspace_id)?;
        let mut statement = self.connection.prepare(
            "SELECT id, workspace_id, name FROM environments WHERE workspace_id = ?1 ORDER BY created_at ASC, id ASC",
        )?;
        statement
            .query_map([workspace_id], decode_environment)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(StorageError::Database)
    }

    fn delete_environment(&mut self, id: &str) -> Result<(), StorageError> {
        validate_non_empty("environment", "id", id)?;
        let changed = self
            .connection
            .execute("DELETE FROM environments WHERE id = ?1", [id])?;
        if changed == 0 {
            return Err(StorageError::EnvironmentNotFound { id: id.to_owned() });
        }
        Ok(())
    }

    fn save_environment_variable(
        &mut self,
        variable: EnvironmentVariable,
    ) -> Result<(), StorageError> {
        validate_non_empty("environment variable", "id", &variable.id)?;
        validate_non_empty(
            "environment variable",
            "environment_id",
            &variable.environment_id,
        )?;
        validate_non_empty("environment variable", "key", &variable.key)?;
        let transaction = self.begin_write()?;
        ensure_environment_exists(&transaction, &variable.environment_id)?;
        transaction.execute(
            "INSERT INTO environment_variables (id, environment_id, key, value, enabled) VALUES (?1, ?2, ?3, ?4, ?5) \
             ON CONFLICT(id) DO UPDATE SET environment_id = excluded.environment_id, key = excluded.key, \
             value = excluded.value, enabled = excluded.enabled, updated_at = CURRENT_TIMESTAMP",
            (&variable.id, &variable.environment_id, &variable.key, &variable.value, variable.enabled),
        )?;
        transaction.commit()?;
        Ok(())
    }

    fn list_environment_variables(
        &self,
        environment_id: &str,
    ) -> Result<Vec<EnvironmentVariable>, StorageError> {
        validate_non_empty("environment variable", "environment_id", environment_id)?;
        let mut statement = self.connection.prepare(
            "SELECT id, environment_id, key, value, enabled FROM environment_variables \
             WHERE environment_id = ?1 ORDER BY created_at ASC, id ASC",
        )?;
        statement
            .query_map([environment_id], decode_environment_variable)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(StorageError::Database)
    }

    fn delete_environment_variable(&mut self, id: &str) -> Result<(), StorageError> {
        validate_non_empty("environment variable", "id", id)?;
        let changed = self
            .connection
            .execute("DELETE FROM environment_variables WHERE id = ?1", [id])?;
        if changed == 0 {
            return Err(StorageError::EnvironmentVariableNotFound { id: id.to_owned() });
        }
        Ok(())
    }

    fn save_request(&mut self, request: StoredRequest) -> Result<(), StorageError> {
        validate_non_empty("request", "collection_id", &request.collection_id)?;
        request
            .definition
            .validate()
            .map_err(StorageError::InvalidRequest)?;
        validate_non_empty("request", "id", &request.definition.id)?;
        validate_non_empty("request", "name", &request.definition.name)?;

        let query_params = serde_json::to_string(&request.definition.query_params)
            .map_err(StorageError::Serialization)?;
        let headers = serde_json::to_string(&request.definition.headers)
            .map_err(StorageError::Serialization)?;
        let body =
            serde_json::to_string(&request.definition.body).map_err(StorageError::Serialization)?;
        let auth =
            serde_json::to_string(&request.definition.auth).map_err(StorageError::Serialization)?;
        let method = serde_json::to_string(&request.definition.method)
            .map_err(StorageError::Serialization)?;

        let transaction = self.begin_write()?;
        ensure_collection_exists(&transaction, &request.collection_id)?;
        if let Some(folder_id) = &request.folder_id {
            validate_non_empty("request", "folder_id", folder_id)?;
            ensure_folder_in_collection(&transaction, folder_id, &request.collection_id).map_err(
                |error| match error {
                    StorageError::RequestFolderCollectionMismatch { .. } => {
                        StorageError::RequestFolderCollectionMismatch {
                            request_id: request.definition.id.clone(),
                            folder_id: folder_id.clone(),
                            collection_id: request.collection_id.clone(),
                        }
                    }
                    other => other,
                },
            )?;
        }
        transaction.execute(
            "INSERT INTO requests (id, collection_id, folder_id, name, method, url, query_params_json, headers_json, body_json, auth_json) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10) \
             ON CONFLICT(id) DO UPDATE SET \
             collection_id = excluded.collection_id, folder_id = excluded.folder_id, \
             name = excluded.name, method = excluded.method, url = excluded.url, \
             query_params_json = excluded.query_params_json, headers_json = excluded.headers_json, \
             body_json = excluded.body_json, auth_json = excluded.auth_json, updated_at = CURRENT_TIMESTAMP",
            (
                &request.definition.id,
                &request.collection_id,
                &request.folder_id,
                &request.definition.name,
                method,
                &request.definition.url,
                query_params,
                headers,
                body,
                auth,
            ),
        )?;
        transaction.commit()?;
        Ok(())
    }

    fn get_request(&self, id: &str) -> Result<Option<StoredRequest>, StorageError> {
        validate_non_empty("request", "id", id)?;

        self.connection
            .query_row(
                "SELECT collection_id, folder_id, id, name, method, url, query_params_json, headers_json, body_json, auth_json \
                 FROM requests WHERE id = ?1",
                [id],
                |row| {
                    let method: String = row.get(4)?;
                    let query_params: String = row.get(6)?;
                    let headers: String = row.get(7)?;
                    let body: String = row.get(8)?;
                    let auth: String = row.get(9)?;
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, Option<String>>(1)?,
                        row.get::<_, String>(2)?,
                        row.get::<_, String>(3)?,
                        method,
                        row.get::<_, String>(5)?,
                        query_params,
                        headers,
                        body,
                        auth,
                    ))
                },
            )
            .optional()?
            .map(decode_stored_request)
            .transpose()
    }

    fn list_requests(&self, collection_id: &str) -> Result<Vec<StoredRequest>, StorageError> {
        validate_non_empty("request", "collection_id", collection_id)?;
        let mut statement = self.connection.prepare(
            "SELECT collection_id, folder_id, id, name, method, url, query_params_json, headers_json, body_json, auth_json \
             FROM requests WHERE collection_id = ?1 ORDER BY sort_order ASC, created_at ASC, id ASC",
        )?;
        statement
            .query_map([collection_id], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, Option<String>>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, String>(3)?,
                    row.get::<_, String>(4)?,
                    row.get::<_, String>(5)?,
                    row.get::<_, String>(6)?,
                    row.get::<_, String>(7)?,
                    row.get::<_, String>(8)?,
                    row.get::<_, String>(9)?,
                ))
            })?
            .map(|row| {
                row.map_err(StorageError::Database)
                    .and_then(decode_stored_request)
            })
            .collect()
    }

    fn delete_request(&mut self, id: &str) -> Result<(), StorageError> {
        validate_non_empty("request", "id", id)?;
        let changed = self
            .connection
            .execute("DELETE FROM requests WHERE id = ?1", [id])?;
        if changed == 0 {
            return Err(StorageError::RequestNotFound { id: id.to_owned() });
        }
        Ok(())
    }

    fn move_request(&mut self, id: &str, folder_id: Option<String>) -> Result<(), StorageError> {
        validate_non_empty("request", "id", id)?;
        let transaction = self.begin_write()?;
        let collection_id = transaction
            .query_row(
                "SELECT collection_id FROM requests WHERE id = ?1",
                [id],
                |row| row.get::<_, String>(0),
            )
            .optional()?
            .ok_or_else(|| StorageError::RequestNotFound { id: id.to_owned() })?;
        if let Some(folder_id) = &folder_id {
            validate_non_empty("request", "folder_id", folder_id)?;
            ensure_folder_in_collection(&transaction, folder_id, &collection_id).map_err(
                |error| match error {
                    StorageError::RequestFolderCollectionMismatch { .. } => {
                        StorageError::RequestFolderCollectionMismatch {
                            request_id: id.to_owned(),
                            folder_id: folder_id.clone(),
                            collection_id: collection_id.clone(),
                        }
                    }
                    other => other,
                },
            )?;
        }
        transaction.execute(
            "UPDATE requests SET folder_id = ?1, updated_at = CURRENT_TIMESTAMP WHERE id = ?2",
            (&folder_id, id),
        )?;
        transaction.commit()?;
        Ok(())
    }

    fn append_execution_history(
        &mut self,
        record: ExecutionHistoryRecord,
    ) -> Result<(), StorageError> {
        SqliteStorage::append_execution_history(self, record)
    }

    fn list_execution_history(
        &self,
        request_id: &str,
    ) -> Result<Vec<ExecutionHistoryRecord>, StorageError> {
        SqliteStorage::list_execution_history(self, request_id)
    }

    fn delete_execution_history(
        &mut self,
        request_id: &str,
        execution_id: &str,
    ) -> Result<(), StorageError> {
        SqliteStorage::delete_execution_history(self, request_id, execution_id)
    }

    fn clear_execution_history(&mut self, request_id: &str) -> Result<usize, StorageError> {
        SqliteStorage::clear_execution_history(self, request_id)
    }
}
