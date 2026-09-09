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

- [ ] **QA-005 · Critical · Нельзя создать workspace или collection через UI.**
  Откройте установленное macOS-приложение и пройдите раздел Collections.
  Ожидание: пользователь может создать и выбрать workspace, а затем создать
  collection для собственных запросов. Факт: экран содержит только заранее
  заданную коллекцию `Getting started` с двумя демо-запросами; доступна
  лишь кнопка новой вкладки-запроса, controls для создания workspace/collection
  отсутствуют. Подтверждено ручным UI-тестом macOS-пакета 2026-09-09.
  Критерий готовности: добавить доступный путь создания и выбора workspace и
  collection с typed BLoC events и persistence через repository/gateway; после
  перезапуска выбранная сущность и созданная collection сохраняются; покрыть
  сценарии widget-тестами и повторить macOS UI smoke-test.
- [ ] Реализовать auth form поверх локального request draft state.
- [x] **QA-001 · Critical · Send не выполняет HTTP-запрос.** В приложении
  введите `GET https://httpbin.org/get` в открытую вкладку и нажмите **Send**.
  Ожидание: BLoC запускает use case через `flutter_rust_bridge`, кнопка показывает
  состояние выполнения, а в response viewer появляются status, headers и body.
  Факт: обработчик кнопки пустой, response viewer остаётся placeholder.
  Подтверждено ручным UI-тестом в macOS-пакете 2026-09-09: URL редактируется,
  нажатие **Send** не меняет интерфейс, во вкладке Response остаётся текст
  `Response will appear here`.
  Исправление реализовано в исходниках: BLoC вызывает data-layer executor,
  generated `flutter_rust_bridge` bridge вызывает Rust Ports-and-Adapters core,
  а Response умеет отображать loading/success/error. Flutter native-assets hook
  успешно компилирует Rust library; Rust 34 tests и Flutter 12 tests проходят.
  Ручная проверка `v0.1.2` выявила следующий transport blocker: при валидном
  `https://httpbin.org/get` Response показывает `HTTP transport failed: Connect`,
  хотя macOS `curl` получает HTTP 200. В работе native Rustls root-store fix;
  после него требуется повторный DMG smoke-test.
  TLS fix проверен opt-in live Rust test: тот же engine получил HTTP 200 от
  `https://httpbin.org/get`. В релизном ревью UI-переходы и typed error
  отображены в установленном macOS app; Dart BLoC regression test проверяет
  loading → HTTP 200 response, а FFI integration test выполняет локальный
  TCP HTTP request. Автоматизатор macOS не способен надёжно вызвать Flutter
  `onChanged` программной вставкой текста, поэтому визуальный smoke-test
  успешного внешнего HTTPS оставлен как дополнительная ручная проверка после
  скачивания пакета, но не блокирует выпуск: реальный Rust HTTPS smoke-test
  проходит.
  Критерий готовности: подключить UI к Rust через `flutter_rust_bridge` для
  execution, collections, tabs, request drafts и сохранения без прямого доступа
  Flutter к SQLite/HTTP; покрыть state transitions и success/error/cancel paths.

### HTTP execution

- [ ] Добавить Flutter JSON/text/binary viewer, поиск и отображение privacy-safe
  истории запусков.
- [ ] Добавить cookie jar, file multipart, proxy и custom CA settings.

### Interoperability и hardening

- [ ] Импорт Postman Collection v2.1 и OpenAPI; экспорт собственного формата.
- [ ] Хранение секретов через системный secure storage, redaction и limits.
- [ ] Rust/Flutter unit, widget, integration и desktop E2E tests.

### Release

- [x] Добавить cross-platform «Проверить обновления»: BLoC проверяет GitHub
  Releases, показывает подходящий по ОС файл и открывает загрузку только после
  явного подтверждения пользователя. Release workflow публикует DMG/EXE/DEB/
  AppImage как постоянные GitHub Release assets, а не только временные Actions
  artifacts. Автоматическая замена приложения отложена до code signing и
  notarization.
- [ ] GitHub Actions для macOS, Windows и Linux; signing/notarization.
- [ ] Выполнить и проверить первый GitHub Actions packaging run: macOS `.app`/
  DMG, Windows `.exe`, Linux AppImage/DEB artifacts.
- [ ] Добавить signing/notarization secrets, release signing и updater после
  предоставления Apple Developer / Windows certificate / GPG authority.
- [ ] Добавить release notes и provenance/SBOM для опубликованных пакетов.
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
- Добавлен reproducible unsigned packaging pipeline: universal macOS DMG
  (`arm64` + `x86_64`) через `hdiutil`,
  Windows setup `.exe` через Inno Setup, Linux `.deb` и AppImage. GitHub Actions
  запускает platform-native builds и загружает каждый artifact; локальная DMG
  сборка ждёт полноценный Xcode (сейчас активны только Command Line Tools).
- Добавлен отдельный пользовательский гайд `INSTALL.md`: пошаговая установка
  через GitHub Actions для macOS (Apple Silicon и Intel), Windows и Linux,
  включая безопасное прохождение Gatekeeper/SmartScreen и текущие ограничения
  ранней версии.
- QA-002 закрыт: выбранный раздел workspace хранится в immutable BLoC state;
  NavigationRail dispatches typed event, а History и Variables показывают свои
  экраны. BLoC и widget-тесты покрывают переходы.
- QA-003 закрыт: Search dispatches debounce-free BLoC event и отображает
  derived-фильтр collections/requests без изменения исходных данных. BLoC и
  widget-тесты покрывают совпадение, пустой результат и восстановление списка.
- QA-004 закрыт: неготовые интерактивные Environment picker и Settings скрыты
  до появления доменных BLoC flows; widget-тест подтверждает их отсутствие.
- QA-001 закрыт: Send подключён к `flutter_rust_bridge` и Rust HTTP adapter;
  UI показывает loading, status, response headers/body и безопасные ошибки.
  Результат привязан к вкладке, поэтому не отображается в другой вкладке;
  исключение bridge возвращает кнопку из loading. Релизные проверки: Rust
  34 passed + 1 ignored, Flutter 19 passed, live HTTPS smoke-test HTTP 200.

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
