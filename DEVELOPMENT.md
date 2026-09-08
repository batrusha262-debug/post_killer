# Post Killer — план разработки

Этот файл — живой план. После приемки задача переносится в «Готово» и не
дублируется в активном плане.

## Цель MVP

Нативное desktop-приложение (macOS, Windows, Linux), в котором можно создать
коллекцию HTTP-запросов, выполнить запрос через Rust core, изучить ответ и
безопасно сохранить историю. Flutter отвечает за интерфейс, Rust — за модели,
сетевой движок, хранилище и секреты. Web не является целью MVP.

## Активный план

### Foundation

### Данные и редактор запросов

- [ ] Реализовать auth form поверх локального request draft state.
- [ ] Подключить UI к Rust через `flutter_rust_bridge`: collections, tabs,
  request drafts и сохранение без прямого доступа Flutter к SQLite/HTTP.

### HTTP execution

- [ ] Добавить Flutter JSON/text/binary viewer, поиск и отображение privacy-safe
  истории запусков.
- [ ] Добавить cookie jar, file multipart, proxy и custom CA settings.

### Interoperability и hardening

- [ ] Импорт Postman Collection v2.1 и OpenAPI; экспорт собственного формата.
- [ ] Хранение секретов через системный secure storage, redaction и limits.
- [ ] Rust/Flutter unit, widget, integration и desktop E2E tests.

### Release

- [ ] GitHub Actions для macOS, Windows и Linux; signing/notarization.
- [ ] DMG/MSIX/AppImage/DEB, updater и release notes.
- [ ] Отдельно решить необходимость E2EE cloud sync; не проксировать запросы
  пользователя через Vercel.

## Готово

- Создан Rust workspace (`domain`, `http_engine`, `ffi_bridge`) с
  сериализуемыми моделями запросов, базовой валидацией и устойчивым API
  execution boundary. В `domain` добавлено пять unit tests.
- Добавлены `.gitignore` для build/IDE/service artifacts и
  `rust-toolchain.toml` (`stable`, `clippy`, `rustfmt`).
- Принят ADR 0001: Flutter — UI, Rust — сеть/данные/секреты; приложение
  local-first и desktop-first.
- Выполнена статическая проверка `git diff --check`.
- Rust toolchain установлен; `cargo fmt --check`, `cargo test --workspace`
  (5 tests) и `cargo clippy -- -D warnings` проходят.
- Добавлен `CLAUDE.md`: правила Rust, Flutter state management, FFI, security, quality
  gates и ссылки на проверенные первичные рекомендации.
- Добавлена crate `storage_sqlite`: versioned forward-only migration v1 для
  workspace/collection/folder/request/environment, typed storage errors и
  create/list API для workspace и collection. Fresh-DB и foreign-key сценарии
  покрыты тестами.
- После storage-изменения проходят `cargo fmt --check`, `cargo test --workspace`
  (7 tests) и `cargo clippy -- -D warnings`.
- Добавлена migration v2 и storage API `save_request`/`get_request`: полная
  `RequestDefinition` сериализуется без потери query, headers и body; upgrade
  v1 → v2 и update существующего request покрыты тестами.
- После request persistence проходят `cargo fmt --check`, `cargo test --workspace`
  (9 tests), `cargo clippy -- -D warnings` и `git diff --check`.
- Добавлена migration v3 и SQLite CRUD для folder, environment и environment
  variables, а также list/delete/move для requests. API и SQLite triggers
  запрещают cross-collection folder/request links; fresh, upgrade и invalid
  relation scenarios покрыты 12 storage tests.
- Реализован HTTP MVP на `reqwest`/Rustls: timeout, redirect policy, bounded
  response body, metadata, query/headers и Empty/Text/JSON/Form bodies. Multipart
  пока возвращает typed `UnsupportedBody`; локальные TCP tests покрывают JSON,
  timeout, response limit и invalid input.
- FFI facade проксирует validate и execution options без раскрытия деталей
  `reqwest`; добавлен baseline GitHub Actions quality workflow для Rust.
- Общий Rust workspace quality gate проходит: `cargo fmt --check`, 18 tests,
  Clippy `-D warnings` и `git diff --check`.
- Добавлены caller-owned cancellation и streaming events: один execution
  выпускает `response_started`, body chunks и ровно один terminal event;
  cancellation покрыт тестом. Также добавлено pure preview-разрешение
  `{{variables}}` для URL/query/headers/body/auth без мутации исходного request.
- Text multipart добавлен в HTTP engine. File multipart отложен до появления
  безопасной модели local file reference.
- Реализован сквозной auth MVP: `None`/Basic/Bearer/API key (header/query),
  typed validation, secret-redacted `Debug`, variable resolution и migration v4
  для `auth_json`. Явно заданные пользователем Authorization/API-key header или
  query parameter имеют приоритет над генерируемым auth.
- После streaming, variable resolution и auth проходят `cargo fmt --check`,
  `cargo test --workspace` (28 tests), Clippy `-D warnings` и `git diff --check`.
- Добавлена migration v5 и privacy-first execution history API: append/list/delete/
  clear сохраняют только IDs, timestamp, status, duration, response size и typed
  error category. Request/response payloads, headers, cookies, URLs, credentials
  и raw errors отсутствуют в схеме и public record. Решение закреплено ADR 0002.
- После history implementation проходят `cargo fmt --check`, `cargo test --workspace`
  (30 tests), Clippy `-D warnings` и `git diff --check`.
- Установлен Flutter SDK 3.47.2 stable (Dart 3.13.2) в
  `/Users/adt/development/flutter`; создан `apps/client_flutter` для macOS,
  Windows и Linux. Выполнены `flutter pub get`, `flutter analyze` (без замечаний)
  и baseline widget test (1 passed).
- Настроен единый Flutter quality gate: `make flutter-check` запускает
  форматирование, анализ и тесты; добавлен изолированный GitHub Actions workflow
  `Flutter quality`. Локально gate проходит с путями установленного SDK.
- Реализована Flutter desktop workspace-основа: navigation rail,
  collections pane, создание/закрытие/переключение вкладок и URL/method request
  draft. Экран не вызывает HTTP или SQLite напрямую; три widget-теста покрывают
  initial state, переключение tabs и dirty draft. `flutter-check`, Rust quality
  gate (30 tests) и `git diff --check` проходят.
- В request editor добавлены editable Query и Headers key/value tables и Body
  editor; все изменения отмечают draft как unsaved. Widget tests расширены до
  четырёх сценариев, включая изменение body; `flutter-check` проходит.
- Проведён архитектурный аудит по официальным Flutter MVVM и Cargo workspace
  guidance. Принят ADR 0003; demo workspace source вынесен из Notifier в
  `WorkspaceRepository`, а workspace lints запрещают `unsafe`, `dbg!` и `todo!`
  во всех Rust crates. Flutter quality gate (4 tests), Rust quality gate
  (30 tests) и `git diff --check` проходят.
- Архитектурная санация завершена: Flutter workspace физически разделён на
  feature-first `domain`/`data`/`application`/`presentation`; его ViewModel
  получает данные только через repository → gateway seam, оба слоя изолированно
  проверяются fake repository/gateway. В Rust добавлена `application` crate, которая
  владеет request use-case; `ffi_bridge` зависит только от неё и domain, не от
  HTTP adapter. Workspace-level lints наследуются всеми пятью crates. После
  изменения проходят Flutter quality gate (6 tests), Rust quality gate (31
  tests), Clippy и `git diff --check`.
- SQLite persistence декомпозирован на `lib` (repository operations), `types`
  (public models/errors), `codec` (validation, relation guards и SQL mapping) и
  `tests`; production modules не превышают 676 строк. Все write operations
  используют короткую explicit `BEGIN IMMEDIATE` transaction policy с rollback
  по умолчанию, foreign keys, WAL и bounded busy timeout; детали закреплены в
  ADR 0003 и проверены всеми 31 Rust tests.
- Flutter state management переведён с Riverpod на BLoC: экран отправляет
  typed events, `WorkspaceBloc` строит immutable states, а repository/gateway
  остаются data layer. Riverpod удалён из dependencies; BLoC state transitions
  изолированно покрыты `bloc_test`, полный Flutter quality gate проходит.
- Rust core переведён на Ports & Adapters: `application` определяет
  `RequestExecutor` port без зависимости от HTTP/SQLite; reqwest реализует
  outbound adapter, а FFI является composition root. Есть fake-adapter unit
  test без TCP/SQLite; после рефакторинга проходят 31 Rust tests и Clippy.

## Внешние блокеры проверки

- Для запуска на macOS потребуется Xcode и simulator/device; Windows/Linux
  desktop-сборки проверяются в соответствующих CI runners.

## Принятые решения

- Первый релиз — desktop-first и local-first.
- Flutter state management: BLoC (`Event → Bloc → immutable State`).
- Flutter ↔ Rust: `flutter_rust_bridge`; UI не обращается к SQLite/HTTP
  напрямую.
- Terra Medium — базовая модель реализации; Sol High — concurrency, FFI,
  security и большие архитектурные изменения; Astra — только эскалация.
- Vercel допустим для landing/docs, но не для выполнения пользовательских HTTP
  запросов.
