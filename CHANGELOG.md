# Changelog

All notable user-facing changes are documented here. Releases follow semantic
versioning; package signatures and notarization are introduced only after their
respective signing authorities are configured.

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
