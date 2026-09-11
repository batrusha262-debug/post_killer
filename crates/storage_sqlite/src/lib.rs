//! SQLite persistence for Post Killer's local-first data.

use std::{path::Path, time::Duration};

use post_killer_domain::{Body, KeyValue, RequestAuth, RequestDefinition, RequestMethod};
use rusqlite::{Connection, ErrorCode, OptionalExtension, Transaction, TransactionBehavior};

mod types;
pub use types::*;
mod codec;
use codec::*;

const MIGRATION_V1: &str = include_str!("../migrations/0001_initial.sql");
const MIGRATION_V2: &str = include_str!("../migrations/0002_request_definition.sql");
const MIGRATION_V3: &str = include_str!("../migrations/0003_relation_guards.sql");
const MIGRATION_V4: &str = include_str!("../migrations/0004_request_authentication.sql");
const MIGRATION_V5: &str = include_str!("../migrations/0005_execution_history.sql");

const MIGRATIONS: &[(i64, &str, &str)] = &[
    (1, "initial", MIGRATION_V1),
    (2, "request_definition", MIGRATION_V2),
    (3, "relation_guards", MIGRATION_V3),
    (4, "request_authentication", MIGRATION_V4),
    (5, "execution_history", MIGRATION_V5),
];

pub trait Repository {
    fn create_workspace(&mut self, id: String, name: String) -> Result<Workspace, StorageError>;
    fn list_workspaces(&self) -> Result<Vec<Workspace>, StorageError>;
    fn delete_workspace(&mut self, id: &str) -> Result<(), StorageError>;
    fn create_collection(
        &mut self,
        id: String,
        workspace_id: String,
        name: String,
    ) -> Result<Collection, StorageError>;
    fn list_collections(&self, workspace_id: &str) -> Result<Vec<Collection>, StorageError>;
    fn delete_collection(&mut self, id: &str) -> Result<(), StorageError>;
    fn save_folder(&mut self, folder: Folder) -> Result<(), StorageError>;
    fn get_folder(&self, id: &str) -> Result<Option<Folder>, StorageError>;
    fn list_folders(&self, collection_id: &str) -> Result<Vec<Folder>, StorageError>;
    fn delete_folder(&mut self, id: &str) -> Result<(), StorageError>;
    fn save_environment(&mut self, environment: Environment) -> Result<(), StorageError>;
    fn get_environment(&self, id: &str) -> Result<Option<Environment>, StorageError>;
    fn list_environments(&self, workspace_id: &str) -> Result<Vec<Environment>, StorageError>;
    fn delete_environment(&mut self, id: &str) -> Result<(), StorageError>;
    fn save_environment_variable(
        &mut self,
        variable: EnvironmentVariable,
    ) -> Result<(), StorageError>;
    fn list_environment_variables(
        &self,
        environment_id: &str,
    ) -> Result<Vec<EnvironmentVariable>, StorageError>;
    fn delete_environment_variable(&mut self, id: &str) -> Result<(), StorageError>;
    fn save_request(&mut self, request: StoredRequest) -> Result<(), StorageError>;
    fn get_request(&self, id: &str) -> Result<Option<StoredRequest>, StorageError>;
    fn list_requests(&self, collection_id: &str) -> Result<Vec<StoredRequest>, StorageError>;
    fn delete_request(&mut self, id: &str) -> Result<(), StorageError>;
    fn move_request(&mut self, id: &str, folder_id: Option<String>) -> Result<(), StorageError>;
    fn append_execution_history(
        &mut self,
        record: ExecutionHistoryRecord,
    ) -> Result<(), StorageError>;
    fn list_execution_history(
        &self,
        request_id: &str,
    ) -> Result<Vec<ExecutionHistoryRecord>, StorageError>;
    fn list_workspace_execution_history(
        &self,
        workspace_id: &str,
    ) -> Result<Vec<ExecutionHistoryRecord>, StorageError>;
    fn delete_execution_history(
        &mut self,
        request_id: &str,
        execution_id: &str,
    ) -> Result<(), StorageError>;
    fn clear_execution_history(&mut self, request_id: &str) -> Result<usize, StorageError>;
    fn clear_workspace_execution_history(
        &mut self,
        workspace_id: &str,
    ) -> Result<usize, StorageError>;
}

pub struct SqliteStorage {
    connection: Connection,
}

impl SqliteStorage {
    pub fn open(path: impl AsRef<Path>) -> Result<Self, StorageError> {
        Self::from_connection(Connection::open(path)?)
    }

    pub fn open_in_memory() -> Result<Self, StorageError> {
        Self::from_connection(Connection::open_in_memory()?)
    }

    fn from_connection(connection: Connection) -> Result<Self, StorageError> {
        connection.pragma_update(None, "foreign_keys", true)?;
        connection.pragma_update(None, "journal_mode", "WAL")?;
        connection.busy_timeout(Duration::from_secs(5))?;
        let mut storage = Self { connection };
        storage.migrate()?;
        Ok(storage)
    }

    /// Every multi-statement mutation starts a short write transaction before
    /// validating relational invariants. `IMMEDIATE` avoids discovering a write
    /// lock only after work has already been performed; dropping rolls back.
    fn begin_write(&mut self) -> Result<Transaction<'_>, StorageError> {
        self.connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(StorageError::Database)
    }

    fn migrate(&mut self) -> Result<(), StorageError> {
        self.connection.execute_batch(
            "CREATE TABLE IF NOT EXISTS schema_migrations (\
                 version INTEGER PRIMARY KEY NOT NULL,\
                 name TEXT NOT NULL,\
                 applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP\
             );",
        )?;

        let transaction = self.begin_write()?;
        for (version, name, sql) in MIGRATIONS {
            let applied = transaction
                .query_row(
                    "SELECT 1 FROM schema_migrations WHERE version = ?1",
                    [version],
                    |_| Ok(()),
                )
                .optional()?
                .is_some();

            if !applied {
                transaction.execute_batch(sql)?;
                transaction.execute(
                    "INSERT INTO schema_migrations (version, name) VALUES (?1, ?2)",
                    (version, name),
                )?;
            }
        }

        transaction.commit()?;
        Ok(())
    }
}

mod history;
mod repository;

#[cfg(test)]
mod tests;
