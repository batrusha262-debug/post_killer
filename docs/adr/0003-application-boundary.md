# ADR 0003: application boundary and Flutter feature layers

## Status

Accepted.

## Decision

Rust uses hexagonal architecture: `domain` has transport-independent models;
`application` owns use-cases and port traits but has no adapter dependencies;
HTTP and SQLite crates are outbound adapters; FFI is the inbound adapter and
composition root. FFI must not gain persistence, HTTP policy or orchestration.

Flutter features use `presentation` (views), `application` (BLoC) and `data`
(repository plus FFI gateway). A view only dispatches typed events. A Bloc owns
immutable UI/draft state. A repository is the only
source for persisted or remotely-backed models. The current in-memory workspace
repository is a replaceable development adapter, not product storage.

SQLite writes use short `BEGIN IMMEDIATE` transactions after input validation
and before relational checks and mutation. They roll back on drop and commit
explicitly only after the whole operation succeeds. Connections enable foreign
keys, WAL and a bounded busy timeout. Network I/O, FFI callbacks and awaits are
forbidden while a SQLite transaction is open.

## Consequences

- The generated `flutter_rust_bridge` gateway becomes the only Flutter caller
  of Rust APIs.
- Tests inject fake repositories/gateways into a fresh Bloc rather than invoking
  SQLite or HTTP.
- Workspace lint policy is inherited by every Rust crate, preventing `unsafe`,
  `dbg!` and production `todo!` from silently entering an adapter.
- Storage models/errors, relation/codec helpers, repository operations and tests
  are separate modules; `pub(super)` keeps helpers private to the storage crate.
- `RequestExecutor` is an outbound application port. `ReqwestRequestExecutor`
  implements it; an application test uses a fake adapter without TCP or SQLite.
