# Changelog

All notable user-facing changes are documented here. Releases follow semantic
versioning; package signatures and notarization are introduced only after their
respective signing authorities are configured.

## [0.2.27]

### Changed

- Matched the desktop workbench to the supplied API-client reference at the
  layout level: a 134 px activity rail, 522 px collection area, larger command
  chrome, 96 px request tabs, a 72 px request composer and aligned request /
  response inspectors.
- Reworked the parameter table and response status area to preserve the exact
  dense, structured workbench hierarchy while retaining the real request,
  collection and response behaviour.

## [0.2.26]

### Changed

- Recreated the desktop workspace around the light, request-first layout:
  a macOS-integrated top bar, collection rail, request tabs, request composer
  and permanent response inspector now match one coherent workbench.
- The top command field now filters the live collection tree, while existing
  Send, authentication, request-body, network and response controls retain
  their real local-first behaviour.

## [0.2.25]

### Changed

- Rebuilt the desktop API workspace as a dense terminal workbench: a command
  bar, compact collection controls, high-contrast code surfaces and an
  always-visible response inspector now keep requests and results together.
- Refined the dark palette to graphite and arctic blue, reserving outcome
  colours for HTTP status instead of using them as a global accent.

## [0.2.23]

### Changed

- Redesigned the desktop workspace around a clearer request-first flow: an
  action-led collections pane, visual navigation, calmer surfaces, improved
  tab hierarchy, and a focused request composer.
- Localized the primary workspace controls, navigation, history and variables
  to Russian for a more consistent, approachable interface.

## [0.2.22]

### Added

- A complete local-first API workbench: collections, multiple request tabs,
  environments, variable substitution, privacy-safe history, OpenAPI and
  Postman import, local collection export, multipart files, session cookies,
  runtime proxy and custom CA controls.
- A response workbench with JSON/text/binary views, search and highlighting,
  image preview and explicit binary-response saving.
- System-keyring storage for secret-like environment values, draft-only
  credentials, sensitive-field redaction, bounded imports/uploads/responses
  and typed safe errors.
- A macOS desktop E2E workflow that exercises Send → BLoC → FRB → Rust transport
  → Response UI against a deterministic loopback HTTP service.
- SPDX SBOM, SHA-256 checksums and GitHub build-provenance attestations for
  every published desktop package.

### Changed

- Release assets now exclude the AppImage packaging helper; only installable
  DMG, EXE, DEB and Post Killer AppImage files are published.

### Security

- GitHub Actions provenance can be verified with:

  ```sh
  gh attestation verify <downloaded-package> \
    --repo batrusha262-debug/post_killer
  ```

  Compare the package SHA-256 digest with the accompanying `SHA256SUMS.txt`.
