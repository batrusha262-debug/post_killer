use super::*;

impl SqliteStorage {
    pub(super) fn append_execution_history(
        &mut self,
        record: ExecutionHistoryRecord,
    ) -> Result<(), StorageError> {
        validate_execution_history(&record)?;
        let duration_ms = sqlite_integer("execution history", "duration_ms", record.duration_ms)?;
        let response_size_bytes = sqlite_integer(
            "execution history",
            "response_size_bytes",
            record.response_size_bytes,
        )?;
        let transaction = self.begin_write()?;
        ensure_request_exists(&transaction, &record.request_id)?;
        let result = transaction.execute(
            "INSERT INTO execution_history (execution_id, request_id, executed_at_unix_ms, status_code, duration_ms, response_size_bytes, result_kind, error_category) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            (
                &record.execution_id,
                &record.request_id,
                record.executed_at_unix_ms,
                record.status_code.map(i64::from),
                duration_ms,
                response_size_bytes,
                execution_result_kind_sql(record.result_kind),
                record.error_category.map(execution_error_category_sql),
            ),
        );
        map_insert_result(result, "execution history", &record.execution_id)?;
        transaction.commit()?;
        Ok(())
    }

    pub(super) fn list_execution_history(
        &self,
        request_id: &str,
    ) -> Result<Vec<ExecutionHistoryRecord>, StorageError> {
        validate_non_empty("execution history", "request_id", request_id)?;
        let mut statement = self.connection.prepare(
            "SELECT execution_id, request_id, executed_at_unix_ms, status_code, duration_ms, response_size_bytes, result_kind, error_category \
             FROM execution_history WHERE request_id = ?1 ORDER BY executed_at_unix_ms DESC, execution_id DESC",
        )?;
        statement
            .query_map([request_id], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, i64>(2)?,
                    row.get::<_, Option<i64>>(3)?,
                    row.get::<_, i64>(4)?,
                    row.get::<_, i64>(5)?,
                    row.get::<_, String>(6)?,
                    row.get::<_, Option<String>>(7)?,
                ))
            })?
            .map(|row| {
                row.map_err(StorageError::Database)
                    .and_then(decode_execution_history)
            })
            .collect()
    }

    pub(super) fn delete_execution_history(
        &mut self,
        request_id: &str,
        execution_id: &str,
    ) -> Result<(), StorageError> {
        validate_non_empty("execution history", "request_id", request_id)?;
        validate_non_empty("execution history", "execution_id", execution_id)?;
        let changed = self.connection.execute(
            "DELETE FROM execution_history WHERE request_id = ?1 AND execution_id = ?2",
            (request_id, execution_id),
        )?;
        if changed == 0 {
            return Err(StorageError::ExecutionHistoryNotFound {
                execution_id: execution_id.to_owned(),
                request_id: request_id.to_owned(),
            });
        }
        Ok(())
    }

    pub(super) fn clear_execution_history(
        &mut self,
        request_id: &str,
    ) -> Result<usize, StorageError> {
        validate_non_empty("execution history", "request_id", request_id)?;
        let transaction = self.begin_write()?;
        ensure_request_exists(&transaction, request_id)?;
        let changed = transaction.execute(
            "DELETE FROM execution_history WHERE request_id = ?1",
            [request_id],
        )?;
        transaction.commit()?;
        Ok(changed)
    }
}
