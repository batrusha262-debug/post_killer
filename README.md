# Post Killer

Post Killer — local-first desktop-клиент для работы с HTTP API, аналог Postman
для macOS, Windows и Linux. Запросы выполняются на устройстве пользователя, а
не проходят через сервер проекта или proxy.

## Зачем нужен

Используйте Post Killer для проверки API, сохранения коллекций запросов,
исследования HTTP-ответов и повторного запуска запросов с разными query,
headers и телом. Коллекции и история хранятся локально.

## Функциональность сейчас

- Desktop UI: collections, tabs, URL, HTTP method, Query, Headers, JSON body и
  response viewer (status, response headers и body).
- **Send**: Flutter BLoC → `flutter_rust_bridge` → Rust HTTP engine; UI
  показывает отправку, результат или безопасную typed error.
- HTTP engine: Rustls TLS, redirects, timeout, bounded response, streaming и
  caller-owned cancellation.
- Request bodies: empty, text, JSON, form-url-encoded и text multipart.
- Basic, Bearer и API-key authentication.
- SQLite: workspace, collection, folder, request, environment и variables.
- Privacy-safe history: только timestamp, status, duration, response size и
  error category — без bodies, headers, URLs, cookies и credentials.
- GitHub Actions выпускает unsigned macOS DMG, Windows setup EXE, Linux DEB и
  AppImage artifacts.

## Что пока не готово

- Нет Postman/OpenAPI import/export, secure storage, file multipart, proxy,
  custom CA, cookie jar, signing/notarization и auto-update.
- Создание workspace/collection и их сохранение через UI ещё в работе; текущие
  demo-коллекции служат для быстрого старта.

Полный актуальный backlog: [DEVELOPMENT.md](DEVELOPMENT.md).

## Установка готового пакета

Если вы просто хотите установить приложение, следуйте пошаговой инструкции:
[INSTALL.md](INSTALL.md). Она написана для macOS (M-чип и Intel), Windows и
Linux и не требует знаний разработки.

В GitHub откройте **Actions → Release packages**, выберите успешный run и
скачайте artifact для своей ОС. Пакеты пока unsigned, поэтому macOS и Windows
могут показать системное предупреждение до появления code signing.

### macOS

1. Скачайте и распакуйте `post-killer-macos-dmg`.
2. Откройте `Post-Killer-<version>-macos.dmg`. Это универсальный пакет: один
   DMG подходит и для Apple Silicon (M1/M2/M3/M4), и для Intel Mac.
3. Перетащите `Post Killer.app` в `/Applications`.
4. Если Gatekeeper блокирует запуск, подтвердите его в System Settings →
   Privacy & Security.

### Windows

1. Скачайте и распакуйте `post-killer-windows-exe`.
2. Запустите `Post-Killer-<version>-windows-setup.exe`.
3. Пройдите установщик; ярлык появится в Start Menu, а при выборе опции — на
   рабочем столе.

### Linux

```sh
# Debian / Ubuntu
sudo apt install ./post-killer_<version>_amd64.deb

# AppImage
chmod +x Post-Killer-<version>-linux-x86_64.AppImage
./Post-Killer-<version>-linux-x86_64.AppImage
```

## Запуск из исходников на macOS

Нужны Flutter SDK и полный Xcode:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

cd /Users/adt/Documents/ChatGPT/post_killer/apps/client_flutter
/Users/adt/development/flutter/bin/flutter pub get
/Users/adt/development/flutter/bin/flutter run -d macos
```

Создание локального DMG:

```sh
cd /Users/adt/Documents/ChatGPT/post_killer
cd apps/client_flutter
# Flutter/Xcode build the standard macOS architectures; the packaging script
# verifies the output contains both Intel and Apple Silicon slices.
/Users/adt/development/flutter/bin/flutter build macos --release
cd ../..
bash packaging/macos/create_dmg.sh 0.1.0
```

Если Flutter не находит `xcodebuild`, установлены только Command Line Tools —
установите полный Xcode из App Store.

## Проверки для разработчиков

```sh
cargo fmt --all --check
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
make flutter-check
```

## Архитектура

- Flutter: BLoC — `Event → Bloc → immutable State`.
- Rust: Ports & Adapters — application use-cases зависят от traits, HTTP/SQLite
  являются заменяемыми outbound adapters.

Подробности: [docs/adr](docs/adr/). Правила разработки: [CLAUDE.md](CLAUDE.md).
