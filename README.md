# Post Killer

Local-first, cross-platform API client. Flutter renders the desktop/mobile
interface; Rust owns request execution, local SQLite data and future secret
storage. User HTTP requests never pass through a project-operated proxy.

## Current capability

- Rust workspace with shared request models.
- SQLite migrations and CRUD for workspaces, collections, folders, requests and
  environments.
- HTTP MVP with Rustls, redirects, timeout, caller-owned cancellation, bounded
  response streaming, JSON/text/form/text-multipart bodies and typed errors.
- Basic, Bearer and API-key authentication; environment variable preview and
  versioned persistence of request auth.
- Privacy-safe execution history: timestamps, status, duration, response size
  and error category only; never bodies, headers, URLs, cookies or credentials.
- Flutter desktop shell is pending a working Flutter SDK installation.

The live feature status is in [DEVELOPMENT.md](DEVELOPMENT.md). Contributor and
agent rules are in [CLAUDE.md](CLAUDE.md).

## Rust quality checks

```sh
cargo fmt --all --check
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
```

The HTTP integration tests bind only to `127.0.0.1`; some restricted execution
environments require local-network permission for that command.

## Repository layout

```text
crates/domain/          Shared request and collection models
crates/storage_sqlite/  Versioned local persistence
crates/http_engine/     Native HTTP execution engine
crates/ffi_bridge/      Flutter-facing Rust API boundary
docs/adr/               Architecture decisions
```
