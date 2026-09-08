# Post Killer — правила разработки для Claude

Это обязательный контракт для каждого изменения. Проект — local-first
HTTP-клиент: Flutter отображает интерфейс, Rust владеет исполнением запросов,
данными, cookies и секретами. Не отправляй пользовательские запросы, cookies,
токены или bodies через Vercel либо иной проектный proxy.

## Рабочий порядок

1. `DEVELOPMENT.md` — обязательный журнал работы и единственный источник
   статуса. Перед каждым изменением прочитай его, выбери незавершённый пункт и
   соотнеси с ним код; не начинай «скрытую» работу вне плана. Если нужной задачи
   нет, сначала добавь её в «Активный план».
2. Не меняй публичный Rust/FFI контракт, схему БД или формат export без ADR,
   миграции и тестов совместимости.
3. Не выдумывай готовность: выполни подходящие команды проверки и сообщи, что
   именно не удалось запустить и почему.
4. Во время работы поддерживай `DEVELOPMENT.md` актуальным: отмечай blocker
   сразу после его обнаружения, декомпозируй следующий проверяемый шаг и после
   приемки перемести выполненную задачу из «Активного плана» в «Готово». Не
   оставляй выполненный пункт в обоих разделах и не отмечай его готовым до
   реальной проверки.
5. Не откатывай и не перезаписывай чужие незакоммиченные изменения.

## Rust core

### Границы crates и Ports & Adapters

- `domain` — чистые transport-independent типы и инварианты; никаких `reqwest`,
  SQLite, FFI, filesystem или Tokio.
- `application` содержит use-cases и **ports** (traits); он зависит только от
  `domain` и никогда от HTTP, SQLite, FFI или platform SDK.
- `http_engine`, `storage_sqlite` и `secrets` — outbound adapters. Они могут
  реализовывать application ports, но не импортируют FFI.
- `ffi_bridge` — inbound adapter и composition root: он создаёт concrete
  adapters и передаёт их use-case; business logic в нём запрещён.
- Port описывает нужное use-case поведение, а не API конкретной технологии.
  Public async port возвращает `impl Future<...> + Send`; не используй public
  `async fn` trait без явного Send contract.
- Новую crate добавляй только при реальной независимой границе владения,
  сборки или тестирования; не дроби workspace ради абстракции.

Cargo workspace должен иметь общий `Cargo.lock`, общие версии зависимостей и
workspace-level metadata/lints. Virtual workspace с явно заданным resolver —
правильная базовая форма для нескольких crates.

### Модели и API

- Public Rust/FFI types должны быть простыми owned данными: `String`, числа,
  `Vec`, `Option`, structs/enums. Не пропускай ссылки, borrowed data, raw
  pointers, generic/lifetime-heavy типы через FFI.
- Все входные данные валидируй на boundary до side effect. Ошибки валидации
  должны быть typed и пригодны для показа в UI без parsing текста.
- Сериализуемые модели имеют явные `serde` defaults, versioning/export migration
  strategy и предсказуемые enum tags. Не переименовывай wire fields молча.
- Следуй rust naming: `UpperCamelCase` у типов, `snake_case` у функций. Для
  conversions используй осмысленные `as_`/`to_`/`into_`.

### Ошибки, async и cancellation

- Для ожидаемых failures возвращай `Result<T, E>` с domain-specific error.
  `unwrap`, `expect`, `panic!` и `todo!` допустимы только в тестах или в
  доказанно невозможном internal invariant с поясняющим сообщением.
- Не теряй `source` ошибки при оборачивании. Не показывай в UI секреты,
  Authorization header, cookie или полный request body.
- Не держи `Mutex`/`RwLock` guard через `.await`; CPU/blocking I/O выноси из
  async executor.
- Каждый execution имеет стабильный `execution_id`, timeout и явную отмену.
  Отмена должна прекращать transport и streaming, а UI получает terminal event
  (`cancelled`, `failed` либо `completed`) ровно один раз.
- Не оставляй detached task: владелец хранит handle, может его отменить и ждёт
  завершение во время shutdown. Сначала проектируй cancellation-safe поток,
  затем добавляй concurrency.
- `unsafe` запрещён без отдельного ADR, комментария `SAFETY`, теста и review
  Sol High.

### Данные, сеть и секреты

- SQLite migrations только forward-only, idempotent на свежей БД и протестированы
  как upgrade с предыдущей версии. Никогда не удаляй пользовательские данные
  «для упрощения» миграции.
- `http_engine` не логирует secrets. История хранит только заранее определённые
  metadata и redacted request snapshot.
- TLS verification включена по умолчанию. Custom CA и disable verification —
  явные scoped настройки с предупреждением; последняя не становится global
  default.
- Лимитируй размер body/response, глубину импортируемых структур и время
  операций. Все file paths проверяй до чтения.

### Rust quality gate

Перед передачей Rust-изменения запускай:

```sh
rtk cargo fmt --all --check
rtk cargo test --workspace
rtk cargo clippy --workspace --all-targets -- -D warnings
```

Новая ветка логики требует unit test. Для engine/storage/FFI добавь integration
или contract test с observably useful scenario: cancel, timeout, malformed input,
migration upgrade или backward-compatible decoding.

## Flutter client

### Структура и состояние

- Организация feature-first: `features/<name>/{presentation,application,data}`;
  общие widgets/theme/navigation — в `core`. Не делай глобальную папку с сотней
  несвязанных `providers` или `services`.
- BLoC — единственный механизм state management: View отправляет typed Event,
  Bloc преобразует его в immutable State, а `BlocBuilder` рендерит State. Не
  создавай параллельные Riverpod, singleton или service-locator state stores.
- Один Bloc отвечает за один feature state slice и зависит только от injected
  repositories. Blocs не слушают друг друга; общий реактивный источник живёт в
  repository. Для async handler явно моделируй loading/success/error state.
- Widgets не вызывают Rust bridge напрямую. Цепочка всегда такая:
  `View → Event → Bloc → Repository → Rust gateway`.

### Desktop UX и async

- Каждая async action имеет `loading`, `success` и user-readable `error` state;
  повторный клик не запускает дубликат execution.
- При закрытии request tab отмени связанный execution через repository. Не
  обновляй state после dispose.
- Request editor использует local draft state до Save; autosave не перезаписывает
  пользовательский ввод после конфликтующего external update.
- Все interactive controls доступны с клавиатуры, имеют tooltip/semantic label,
  видимый focus и не зависят только от цвета. Не блокируй UI при response stream.
- Не записывай секреты в `TextEditingController` logs, snackbar, analytics или
  screenshots.

### Flutter quality gate

Перед передачей Flutter-изменения запускай:

```sh
flutter format --set-exit-if-changed .
flutter analyze
flutter test
```

- Unit tests: parsing, state transitions, repositories и Notifier.
- Widget tests: editor, tab, response viewer, loading/error/empty states.
- Integration tests: создать collection → выполнить local test request → увидеть
  response → сохранить history; отдельно cancellation.
- В тестах создавай свежий Bloc с fake repository/gateway или используй
  `bloc_test`; не обращайся к production HTTP/SQLite.

## Flutter ↔ Rust bridge

- Используй `flutter_rust_bridge` code generation; generated файлы не редактируй
  вручную. Изменение Rust public API включает regeneration и Dart compile/test.
- FFI API versioned и coarse-grained: передавай request definition, возвращай
  result/stream событий, а не десятки мелких setter calls.
- Событие потока — tagged DTO с `execution_id`, monotonic sequence и terminal
  состоянием. UI допускает поздние/повторные события и игнорирует их по ID.
- Никаких платформенных `MethodChannel` для business logic; использовать их
  можно только в изолированном plugin adapter, когда FRB физически не покрывает
  OS capability.

## Review checklist

- Изменение минимально, ownership и layering ясны.
- Нельзя случайно раскрыть секрет в log, crash report, history или export.
- Ошибка/timeout/cancel отображаются и не оставляют dangling task/spinner.
- Есть тест для исправляемого поведения и все доступные quality gates зелёные.
- `DEVELOPMENT.md` отражает реальное состояние без дублей.

## Проверенные ориентиры

- [Cargo workspaces](https://doc.rust-lang.org/stable/cargo/reference/workspaces.html)
  — shared lockfile/metadata и virtual workspace.
- [Rust error handling](https://doc.rust-lang.org/stable/book/ch09-00-error-handling.html)
  — `Result` для recoverable failures, `panic!` для bugs.
- [Rust API Guidelines: naming](https://rust-lang.github.io/api-guidelines/naming.html)
  — конвенции public API.
- [Tokio graceful shutdown](https://tokio.rs/tokio/topics/shutdown) и
  [task cancellation](https://docs.rs/tokio/latest/tokio/task/) — cancellation
  token, ожидание завершения, ограничения `abort`.
- [Flutter app architecture](https://docs.flutter.dev/app-architecture/guide) —
  View/ViewModel/Repository/Service и domain layer только при необходимости.
- [Flutter testing](https://docs.flutter.dev/testing/overview) — unit/widget/
  integration test pyramid.
- [BLoC architecture](https://bloclibrary.dev/architecture/) и
  [BLoC concepts](https://bloclibrary.dev/bloc-concepts/) — event/state flow,
  data-layer boundary и testable business logic.
