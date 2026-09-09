# Flutter Rust bridge

`crate::api` is the only Dart-facing Rust namespace. It contains owned DTOs and
coarse-grained async use cases; internal domain, application, HTTP and storage
types are not generated into Dart.

The Flutter package pins `flutter_rust_bridge` and
`flutter_rust_bridge_hooks` to the same version as this crate. Its native-assets
build hook compiles and bundles this crate for desktop builds.

Regenerate bindings after changing `src/api.rs`:

```sh
cd apps/client_flutter
flutter_rust_bridge_codegen generate
```

Generated Rust and Dart files must not be edited by hand. Run Rust and Flutter
quality gates after regeneration.
