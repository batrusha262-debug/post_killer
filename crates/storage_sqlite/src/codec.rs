use super::*;

pub(super) fn validate_non_empty(
    entity: &'static str,
    field: &'static str,
    value: &str,
) -> Result<(), StorageError> {
    if value.trim().is_empty() {
        return Err(StorageError::InvalidInput { entity, field });
    }
    Ok(())
}

pub(super) fn ensure_workspace_exists(
    transaction: &Transaction<'_>,
    workspace_id: &str,
) -> Result<(), StorageError> {
    let exists = transaction
        .query_row(
            "SELECT 1 FROM workspaces WHERE id = ?1",
            [workspace_id],
            |_| Ok(()),
        )
        .optional()?
        .is_some();
    if !exists {
        return Err(StorageError::WorkspaceNotFound {
            id: workspace_id.to_owned(),
        });
    }
    Ok(())
}

pub(super) fn ensure_collection_exists(
    transaction: &Transaction<'_>,
    collection_id: &str,
) -> Result<(), StorageError> {
    let exists = transaction
        .query_row(
            "SELECT 1 FROM collections WHERE id = ?1",
            [collection_id],
            |_| Ok(()),
        )
        .optional()?
        .is_some();
    if !exists {
        return Err(StorageError::CollectionNotFound {
            id: collection_id.to_owned(),
        });
    }
    Ok(())
}

pub(super) fn ensure_request_exists(
    transaction: &Transaction<'_>,
    request_id: &str,
) -> Result<(), StorageError> {
    let exists = transaction
        .query_row("SELECT 1 FROM requests WHERE id = ?1", [request_id], |_| {
            Ok(())
        })
        .optional()?
        .is_some();
    if !exists {
        return Err(StorageError::RequestNotFound {
            id: request_id.to_owned(),
        });
    }
    Ok(())
}

pub(super) fn ensure_environment_exists(
    transaction: &Transaction<'_>,
    environment_id: &str,
) -> Result<(), StorageError> {
    let exists = transaction
        .query_row(
            "SELECT 1 FROM environments WHERE id = ?1",
            [environment_id],
            |_| Ok(()),
        )
        .optional()?
        .is_some();
    if !exists {
        return Err(StorageError::EnvironmentNotFound {
            id: environment_id.to_owned(),
        });
    }
    Ok(())
}

pub(super) fn ensure_folder_in_collection(
    transaction: &Transaction<'_>,
    folder_id: &str,
    collection_id: &str,
) -> Result<(), StorageError> {
    let folder_collection_id = transaction
        .query_row(
            "SELECT collection_id FROM folders WHERE id = ?1",
            [folder_id],
            |row| row.get::<_, String>(0),
        )
        .optional()?;
    match folder_collection_id {
        None => Err(StorageError::FolderNotFound {
            id: folder_id.to_owned(),
        }),
        Some(actual_collection_id) if actual_collection_id != collection_id => {
            Err(StorageError::RequestFolderCollectionMismatch {
                request_id: String::new(),
                folder_id: folder_id.to_owned(),
                collection_id: collection_id.to_owned(),
            })
        }
        Some(_) => Ok(()),
    }
}

pub(super) fn decode_folder(row: &rusqlite::Row<'_>) -> rusqlite::Result<Folder> {
    Ok(Folder {
        id: row.get(0)?,
        collection_id: row.get(1)?,
        parent_folder_id: row.get(2)?,
        name: row.get(3)?,
        sort_order: row.get(4)?,
    })
}

pub(super) fn decode_environment(row: &rusqlite::Row<'_>) -> rusqlite::Result<Environment> {
    Ok(Environment {
        id: row.get(0)?,
        workspace_id: row.get(1)?,
        name: row.get(2)?,
    })
}

pub(super) fn decode_environment_variable(
    row: &rusqlite::Row<'_>,
) -> rusqlite::Result<EnvironmentVariable> {
    Ok(EnvironmentVariable {
        id: row.get(0)?,
        environment_id: row.get(1)?,
        key: row.get(2)?,
        value: row.get(3)?,
        enabled: row.get(4)?,
    })
}

pub(super) type StoredRequestRow = (
    String,
    Option<String>,
    String,
    String,
    String,
    String,
    String,
    String,
    String,
    String,
);

pub(super) fn decode_stored_request(row: StoredRequestRow) -> Result<StoredRequest, StorageError> {
    let (collection_id, folder_id, id, name, method, url, query_params, headers, body, auth) = row;
    Ok(StoredRequest {
        collection_id,
        folder_id,
        definition: RequestDefinition {
            id,
            name,
            method: serde_json::from_str::<RequestMethod>(&method)
                .map_err(StorageError::Serialization)?,
            url,
            query_params: serde_json::from_str::<Vec<KeyValue>>(&query_params)
                .map_err(StorageError::Serialization)?,
            headers: serde_json::from_str::<Vec<KeyValue>>(&headers)
                .map_err(StorageError::Serialization)?,
            body: serde_json::from_str::<Body>(&body).map_err(StorageError::Serialization)?,
            auth: serde_json::from_str::<RequestAuth>(&auth)
                .map_err(StorageError::Serialization)?,
        },
    })
}

pub(super) type ExecutionHistoryRow = (
    String,
    String,
    i64,
    Option<i64>,
    i64,
    i64,
    String,
    Option<String>,
);

pub(super) fn decode_execution_history(
    row: ExecutionHistoryRow,
) -> Result<ExecutionHistoryRecord, StorageError> {
    let (
        execution_id,
        request_id,
        executed_at_unix_ms,
        status_code,
        duration_ms,
        response_size_bytes,
        result_kind,
        error_category,
    ) = row;
    let status_code = status_code
        .map(|value| u16::try_from(value).map_err(|_| invalid_history_field("status_code")))
        .transpose()?;
    let duration_ms =
        u64::try_from(duration_ms).map_err(|_| invalid_history_field("duration_ms"))?;
    let response_size_bytes = u64::try_from(response_size_bytes)
        .map_err(|_| invalid_history_field("response_size_bytes"))?;
    let result_kind = match result_kind.as_str() {
        "response" => ExecutionResultKind::Response,
        "error" => ExecutionResultKind::Error,
        "cancelled" => ExecutionResultKind::Cancelled,
        _ => return Err(invalid_history_field("result_kind")),
    };
    let error_category = error_category
        .map(|value| match value.as_str() {
            "timeout" => Ok(ExecutionErrorCategory::Timeout),
            "dns" => Ok(ExecutionErrorCategory::Dns),
            "connection" => Ok(ExecutionErrorCategory::Connection),
            "tls" => Ok(ExecutionErrorCategory::Tls),
            "proxy" => Ok(ExecutionErrorCategory::Proxy),
            "redirect" => Ok(ExecutionErrorCategory::Redirect),
            "request_body" => Ok(ExecutionErrorCategory::RequestBody),
            "response_body" => Ok(ExecutionErrorCategory::ResponseBody),
            "other" => Ok(ExecutionErrorCategory::Other),
            _ => Err(invalid_history_field("error_category")),
        })
        .transpose()?;
    let record = ExecutionHistoryRecord {
        execution_id,
        request_id,
        executed_at_unix_ms,
        status_code,
        duration_ms,
        response_size_bytes,
        result_kind,
        error_category,
    };
    validate_execution_history(&record)?;
    Ok(record)
}

pub(super) fn validate_execution_history(
    record: &ExecutionHistoryRecord,
) -> Result<(), StorageError> {
    validate_non_empty("execution history", "execution_id", &record.execution_id)?;
    validate_non_empty("execution history", "request_id", &record.request_id)?;
    if record.executed_at_unix_ms < 0 {
        return Err(invalid_history_field("executed_at_unix_ms"));
    }
    match (
        record.result_kind,
        record.status_code,
        record.error_category,
    ) {
        (ExecutionResultKind::Response, _, None)
        | (ExecutionResultKind::Error, None, Some(_))
        | (ExecutionResultKind::Cancelled, None, None) => Ok(()),
        _ => Err(invalid_history_field("result_kind")),
    }
}

pub(super) fn invalid_history_field(field: &'static str) -> StorageError {
    StorageError::InvalidInput {
        entity: "execution history",
        field,
    }
}

pub(super) fn sqlite_integer(
    entity: &'static str,
    field: &'static str,
    value: u64,
) -> Result<i64, StorageError> {
    i64::try_from(value).map_err(|_| StorageError::InvalidInput { entity, field })
}

pub(super) fn execution_result_kind_sql(kind: ExecutionResultKind) -> &'static str {
    match kind {
        ExecutionResultKind::Response => "response",
        ExecutionResultKind::Error => "error",
        ExecutionResultKind::Cancelled => "cancelled",
    }
}

pub(super) fn execution_error_category_sql(category: ExecutionErrorCategory) -> &'static str {
    match category {
        ExecutionErrorCategory::Timeout => "timeout",
        ExecutionErrorCategory::Dns => "dns",
        ExecutionErrorCategory::Connection => "connection",
        ExecutionErrorCategory::Tls => "tls",
        ExecutionErrorCategory::Proxy => "proxy",
        ExecutionErrorCategory::Redirect => "redirect",
        ExecutionErrorCategory::RequestBody => "request_body",
        ExecutionErrorCategory::ResponseBody => "response_body",
        ExecutionErrorCategory::Other => "other",
    }
}

pub(super) fn map_insert_result(
    result: Result<usize, rusqlite::Error>,
    entity: &'static str,
    id: &str,
) -> Result<(), StorageError> {
    match result {
        Ok(_) => Ok(()),
        Err(rusqlite::Error::SqliteFailure(error, _))
            if error.code == ErrorCode::ConstraintViolation =>
        {
            Err(StorageError::AlreadyExists {
                entity,
                id: id.to_owned(),
            })
        }
        Err(error) => Err(StorageError::Database(error)),
    }
}

/// Validate both ancestor cycles and reverse links before changing a folder.
pub(super) fn validate_folder_links(
    transaction: &Transaction<'_>,
    folder: &Folder,
) -> Result<(), StorageError> {
    let cycle: bool = transaction.query_row(
        "WITH RECURSIVE ancestors(id) AS (          SELECT ?1 UNION SELECT parent_folder_id FROM folders JOIN ancestors ON folders.id = ancestors.id        ) SELECT EXISTS(SELECT 1 FROM ancestors WHERE id = ?2)",
        (&folder.parent_folder_id, &folder.id),
        |row| row.get(0),
    )?;
    if cycle {
        return Err(StorageError::InvalidInput {
            entity: "folder",
            field: "parent_folder_id",
        });
    }
    let invalid_children: bool = transaction.query_row(
        "SELECT EXISTS(SELECT 1 FROM folders WHERE parent_folder_id = ?1 AND collection_id != ?2)         OR EXISTS(SELECT 1 FROM requests WHERE folder_id = ?1 AND collection_id != ?2)",
        (&folder.id, &folder.collection_id),
        |row| row.get(0),
    )?;
    if invalid_children {
        return Err(StorageError::InvalidInput {
            entity: "folder",
            field: "collection_id",
        });
    }
    Ok(())
}
