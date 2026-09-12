# Post Killer — план разработки

Этот файл — живой план. После приемки задача переносится в «Готово» и не
дублируется в активном плане.

## Цель MVP

Нативное desktop-приложение (macOS, Windows, Linux), в котором можно создать
коллекцию HTTP-запросов, выполнить запрос через Rust core, изучить ответ и
безопасно сохранить историю. Flutter отвечает за интерфейс, Rust — за модели,
сетевой движок, хранилище и секреты. Web не является целью MVP.

## Активный план

- [ ] QA-007: проверить в GitHub Actions macOS desktop E2E runner, который
  запускает настоящий Flutter app, посылает
  GET на локальный deterministic HTTP endpoint через FRB/Rust transport и
  проверяет HTTP 200/response body в UI без mock-слоёв. Local endpoint намеренно
  заменяет внешний `httpbin`: он устраняет сетевую нестабильность CI, не ослабляя
  проверяемый native request flow.
- [ ] RELEASE-HARDENING-1: проверить в release CI release notes, SPDX SBOM,
  SHA-256 checksums и GitHub provenance; signing/notarization требует
  предоставленных Apple Developer, Windows certificate и GPG authority.

### Foundation

### Данные и редактор запросов

- [x] **QA-005 · Critical · Нельзя создать workspace или collection через UI.**
  Откройте установленное macOS-приложение и пройдите раздел Collections.
  Ожидание: пользователь может создать и выбрать workspace, а затем создать
  collection для собственных запросов. Факт: экран содержит только заранее
  заданную коллекцию `Getting started` с двумя демо-запросами; доступна
  лишь кнопка новой вкладки-запроса, controls для создания workspace/collection
  отсутствуют. Подтверждено ручным UI-тестом macOS-пакета 2026-09-09.
  Исправлено: добавлены controls для создания workspace/collection и выбора
  workspace; typed BLoC events вызывают repository → FRB → Rust SQLite, который
  хранится в системной app-data директории. BLoC и widget tests покрывают
  загрузку и создание. Финальный macOS smoke-test нового DMG остаётся частью
  QA-007 desktop E2E, поскольку локально отсутствует полный Xcode.
- [x] Реализовать auth form поверх локального request draft state.
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

- [x] Добавить Flutter JSON/text/binary viewer, поиск и отображение privacy-safe
  истории запусков.
- [x] Добавить cookie jar, file multipart, proxy и custom CA settings.

### Interoperability и hardening

- [x] Базовый импорт Postman Collection v2.1 и OpenAPI; экспорт собственного формата.
- [x] Хранение environment-секретов через системный secure storage, redaction и limits.
- [ ] Rust/Flutter unit, widget, integration и desktop E2E tests.

### Release

- [x] **QA-006 · Medium · Кнопка обновления не имела доступного имени.**
  Подтверждено macOS UI smoke-test: в accessibility tree отображалась пустым
  `button`. Исправлено `Semantics` label `Проверить обновления` / доступная
  версия; widget-тест фиксирует контракт для screen readers.
- [ ] **QA-007 · Medium · Нет автоматического desktop E2E runner для FRB.**
  `flutter test` не загружает macOS native `.framework`, поэтому Dart→FFI
  нельзя выполнять в обычном widget test. UI тестируется через injected port,
  Rust FFI integration — отдельным TCP-тестом. Критерий готовности: добавить
  macOS integration runner в CI, который запускает `.app` и подтверждает
  `GET` в Response без mock-слоёв. Реализация ожидает первый GitHub Actions run:
  `native-macos-e2e` запускает
  integration test на `macos-14`; он поднимает loopback HTTP endpoint, запускает
  приложение с настоящими `FrbWorkspaceGateway` и `FrbRequestExecutor`, вводит
  URL, нажимает Send и проверяет HTTP 200/body. Loopback заменяет зависимый от
  внешней сети `httpbin`, сохраняя реальный UI → BLoC → FRB → Rust путь.
- [x] Добавить cross-platform «Проверить обновления»: BLoC проверяет GitHub
  Releases, показывает подходящий по ОС файл и открывает загрузку только после
  явного подтверждения пользователя. Release workflow публикует DMG/EXE/DEB/
  AppImage как постоянные GitHub Release assets, а не только временные Actions
  artifacts. Автоматическая замена приложения отложена до code signing и
  notarization.
- [x] GitHub Actions для macOS, Windows и Linux packaging.
- [x] Выполнить и проверить GitHub Actions packaging run: macOS `.app`/
  DMG, Windows `.exe`, Linux AppImage/DEB artifacts.
- [ ] Добавить signing/notarization secrets, release signing и updater после
  предоставления Apple Developer / Windows certificate / GPG authority.
- [ ] Добавить release notes и provenance/SBOM для опубликованных пакетов.
  Реализация ожидает первый tag run: `CHANGELOG.md` даёт notes конкретной версии;
  release job добавляет SPDX SBOM, `SHA256SUMS.txt` и provenance attestation для
  DMG/EXE/DEB/AppImage. Packaging helper AppImage исключён из release assets.
- [ ] Отдельно решить необходимость E2EE cloud sync; не проксировать запросы
  пользователя через Vercel.

## Готово

- RELEASE-PACKAGES-1 (2026-09-12): после полного local gate (Rust 44 passed/
  1 ignored + Clippy; Flutter `dart format`, analyze и 74 tests) опубликован
  `v0.2.21` на commit `7cb7741`. GitHub Actions Release packages #32 завершён
  успешно за 7m39s; Flutter quality #29 также зелёный. GitHub Release содержит
  macOS arm64/x86_64 DMG, Windows EXE, Linux DEB и AppImage. Предыдущий
  `v0.2.20` сохранён неизменным: его отдельный Flutter quality job выявил
  formatting, исправленный в `v0.2.21`.

- API-WORKBENCH-6 (2026-09-12): Response workbench сохраняет exact native
  bytes отдельно от lossy text preview, показывает размер binary payload,
  preview для изображений и explicit Save response для любого binary content
  type. Текстовые и JSON responses получили case-insensitive поиск с числом
  совпадений и highlight, не нарушающий JSON highlighting когда поиск выключен.
  Postman Collection v2.1 import теперь различает multipart text fields и file
  references, сохраняет имя/тип файла, но не читает файл на import и не
  экспортирует его путь. Flutter analyze и 74 tests проходят.

- SECURITY-WORKBENCH-1 (2026-09-12): значения environment-переменных с
  credential-like key отправляются из SQLite в системный Keychain/Credential
  Manager/Secret Service; в SQLite остаётся только marker, а старые plaintext
  values мигрируют при первом чтении. Черновые Basic/Bearer/API-key credentials
  остаются исключительно в памяти открытой вкладки и не сохраняются. UI
  маскирует environment и полученный bearer token; экспорт исключает secret
  query/header/form fields и redacts именованные secret-поля JSON body. FFI
  возвращает только typed privacy-safe ошибки без raw URL/transport diagnostics.
  Введены лимиты: inline request 5 MiB, collection/OpenAPI import 10 MiB,
  custom CA 1 MiB, multipart 50 MiB и response 10 MiB. Rust 44 passed/1
  ignored, Clippy; Flutter analyze и 71 tests проходят.

- API-WORKBENCH-5 (2026-09-12): multipart получил explicit local-file
  references через Flutter UI → BLoC → FFI → Rust; файл читается только во
  время send, ограничен 50 MiB, а path/bytes не попадают в history или export.
  Встроен session-only in-memory cookie jar, который очищается вместе с native
  process. Network-tab добавляет runtime-only proxy URL и выбранный PEM custom
  CA, передаёт их через typed FFI в reqwest и не сохраняет в collection,
  history или export. Flutter 70 tests, Rust 42 passed/1 ignored, Clippy и
  `git diff --check` проходят.

- API-WORKBENCH-4 (2026-09-11): добавлены offline OpenAPI 3.0/3.1 JSON/YAML
  import и export собственной collection. Import читает только выбранный файл,
  не загружает remote `$ref` и не исполняет операции; поддерживает servers,
  path/query/header parameters и JSON/text request examples. Export создаёт
  versioned JSON только с saved request definitions, без runtime history,
  environments и draft authentication; известные credential headers/query
  keys redacted. Flutter analyze и 70 tests проходят.

- API-WORKBENCH-3 (2026-09-11): privacy-safe SQLite execution history
  подключена через generated Flutter Rust Bridge к repository/BLoC. Для
  сохранённых запросов локально записываются только ID, время, HTTP status,
  duration, response size и typed error category; schema, FFI DTO и History UI
  не содержат URLs, body, headers, cookies, credentials или raw error text.
  История загружается по workspace после перезапуска, фильтруется, открывает
  исходный saved request и очищается с явным подтверждением, не затрагивая
  сами запросы и environments. Flutter analyze и 67 tests, Rust fmt/test (41
  passed, 1 ignored)/Clippy, `git diff --check` проходят.

- API-WORKBENCH-2 (2026-09-11): SQLite environments подключены через generated Flutter Rust Bridge к repository/BLoC и полноценному Variables screen. Пользователь создаёт, выбирает и удаляет local environment и переменные; включённые значения подставляются Rust domain resolver в копию запроса только перед отправкой. Переменные не мутируют draft и не попадают в response/history. Flutter analyze и 66 tests, Rust fmt/test (40 passed, 1 ignored)/Clippy, `git diff --check` проходят.

- API-WORKBENCH-1 (2026-09-11): request model, Flutter editor и typed FFI mapping расширены до HEAD/OPTIONS, `application/x-www-form-urlencoded` и text multipart fields. Поля формы редактируются как immutable BLoC draft, сохраняются и исполняются через уже существующий Rust transport; базовый Postman v2 import теперь сохраняет `urlencoded` fields и HEAD. Flutter analyze и 65 tests, Rust fmt/test (39 passed, 1 ignored)/Clippy, `git diff --check` проходят.

- UI-FLOW (v0.2.14): polished desktop surface — выразительные кнопки, tabs,
  cards и feedback; мягкие переходы между рабочими разделами и live-indicator
  активного запроса с полным уважением Reduce motion. Во время Send кнопка
  превращается в Cancel: отмена мгновенно освобождает UI, поздний результат
  отменённой операции игнорируется и не попадает в историю, поэтому следующий
  запрос можно стартовать сразу. BLoC regression test покрывает cancel и
  поздний ответ; widget suite подтверждает отсутствие overflow в узком окне.

- AUTH-EDITOR (v0.2.13): в каждой вкладке редактор Auth поддерживает No auth,
  Basic, Bearer и API key (header/query). Обязательные поля валидируются до
  отправки; auth сохраняется только в открытом черновике, поэтому секреты не
  записываются в локальную историю или ответ. Существующий Rust execution
  boundary применяет выбранную схему и сохраняет приоритет явно указанных
  пользователем headers/query. BLoC и widget tests покрывают выбор схемы,
  валидацию, изоляцию черновика и FFI mapping.

- EDITOR-UX (v0.2.5): Tab вставляет 2 пробела, Shift+Tab снимает отступ, в том
  числе с выделенных строк. Серый placeholder Body; подсказки JSON keys/literals
  рядом с курсором (↑/↓, Enter, Escape), без изменения текста внутри строк.
  JSON syntax controller переиспользуется в редакторе и ответе. Response получил
  Pretty JSON/Raw/Headers, status/time/size, syntax highlighting и Copy; ответы
  больше 1 MiB показываются текстом без синхронного форматирования.
  Default Accept: application/json и presets популярных headers без дублей;
  Authorization preset выключен до заполнения. Updater показывает отдельные
  ошибки 404/403/429 и кнопку открытия GitHub Releases; launch failures обработаны.
  Flutter format/analyze clean, 39 tests passed. Rust/FFI не менялись.
- Ограничение updater: автоматическое сравнение закрытых GitHub Releases
  невозможно без доступа к API. Browser fallback использует вход пользователя;
  токены в приложение не встраиваются. Нужен публичный feed либо отдельный
  безопасный login flow для полноценной автоматической проверки.


- RELEASE-APT: установка Linux build dependencies вынесена в
  `packaging/linux/install_dependencies.sh`. Оба вызова APT используют только
  официальные Ubuntu jammy repositories с archive-keyring и retry; системные
  sources не меняются, hash/signature checks не отключаются. Проверены `bash -n`,
  `git diff --check` и запуск с подменённым sudo: параметры update/install,
  список пакетов, остановка при ошибке update и очистка временного файла.
  Реальная Ubuntu-установка и готовые пакеты требуют подтверждения release CI.


- AUDIT-2026-09: выполнено Rust/Flutter ревью, декомпозированы монолитные файлы,
  устранены дубли HTTP construction, гонки workspace, ошибки поиска/nullable state,
  циклы и cross-collection связи папок, зависание streaming backpressure и
  повторные update checks. Удалена unused Cupertino dependency. Rust: 38 passed,
  1 ignored; Flutter: 30 passed; fmt/analyze/Clippy/diff clean. Подробный отчёт
  и оставшиеся ограничения: [docs/reviews/2026-09-09.md](docs/reviews/2026-09-09.md).


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
  34 passed + 1 ignored, Flutter 22 passed, live HTTPS smoke-test HTTP 200.

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
