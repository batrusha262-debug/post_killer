# ADR 0001: local-first Rust core and Flutter UI

**Status:** accepted  
**Date:** 2026-09-08

## Context

Post Killer executes potentially sensitive HTTP requests that may contain API
keys, cookies, local files and private endpoints. A browser-only client cannot
reliably support this because of CORS, TLS and proxy restrictions. We need a
cross-platform desktop application without letting an intermediary service see
the request payload.

## Decision

- Flutter owns rendering, navigation, keyboard interaction and short-lived UI
  state. BLoC is the application state-management layer.
- Rust owns domain validation, request execution, persistent data, cookies,
  network and all secret-adjacent operations.
- Flutter communicates with Rust only through a typed
  `flutter_rust_bridge` API. It must not open the application SQLite database
  or run HTTP requests directly.
- The first deliverable targets macOS, Windows and Linux. Mobile is added after
  the desktop execution and storage contract is stable. Web is not a supported
  request-execution target for the MVP.
- User request payloads never transit Vercel or another project-operated proxy.
  Any future sync service stores client-side encrypted data only.

## Consequences

- Native platform CI runners are required for release artefacts.
- The Rust FFI contract is a compatibility boundary and receives contract tests.
- Network execution may evolve independently of the Flutter widget tree.
- Cloud collaboration and JavaScript request scripts are explicitly deferred
  beyond the MVP.
