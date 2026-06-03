# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Layout

This is a monorepo for **Night Sky Guide** — a commercial planetarium app (tied to star-registration.com / Online Star Register) built on the open-source Stellarium engine. Three top-level components:

| Directory | Language | Role |
|-----------|----------|------|
| `stellarium_flutter/` | Dart/Flutter | The shipped mobile + web app. Where almost all product work happens. |
| `stellarium-web-engine/` | C → WASM | Forked Stellarium rendering engine, compiled to `.js`/`.wasm` and embedded by the app. |
| `stellarium-data/` | Perl/Python/C++ | Offline tools that generate astronomical catalogs. **Separate embedded git repo** (has its own `.git`, no submodule registration). Has its own `CLAUDE.md`. |

## Critical Architecture: How the app renders the sky

The renderer is the WASM-compiled `stellarium-web-engine`, **not native Flutter drawing**. There are two delivery paths selected at compile time via conditional imports:

- **Mobile (iOS/Android):** Flutter hosts a `webview_flutter` WebView (`lib/widgets/stellarium_webview.dart`) that loads `assets/stellarium/stellarium.html`, which boots the WASM engine. Dart↔JS communication:
  - JS → Dart: `FlutterChannel.postMessage(JSON)` (events like engine-ready, object-selected, time-changed).
  - Dart → JS: `runJavaScript` calls into `window.stellariumAPI.*` (defined in `stellarium.html`).
- **Web:** `HtmlElementView(viewType: 'stellarium-container')` driven by `stellarium_engine_web.dart`.

There is also an FFI scaffold (`stellarium_engine_mobile.dart` calling `libstellarium_engine.so` / `core_init`), but **no native engine library is bundled**, so it returns `StellariumEngineUnavailable`. The WebView is the real mobile renderer — ignore the FFI path unless explicitly wiring up native linking.

Engine API conventions (see `stellarium_flutter/docs/STELLARIUM_API_NOTES.md`): the global engine is `window.stellarium`/`stel`; **all angles are radians**, time is **MJD** (Modified Julian Date), positioning uses `stel.observer.view_offset_alt` + `stel.pointAndLock`.

### Platform-abstraction pattern (recurring)

Platform-specific code uses the stub/conditional-import idiom — `*.dart` (abstract API) + `*_factory.dart` (conditional `export`) + `*_stub.dart` / `*_web.dart` / `*_mobile.dart`. Used by `stellarium_engine`, `star_viewer_screen`, `certificate_scanner`, and `web_sensors`. When adding cross-platform behavior, follow this same triple rather than scattering `kIsWeb` branches (though `kIsWeb` is used heavily inside `sky_view.dart`).

## Building & Running the Flutter app

**Always run Flutter through the wrapper, not bare `flutter`:**

```bash
cd stellarium_flutter
./tool/flutterw run          # or build, etc.
```

`tool/flutterw` first runs `tool/generate_stellarium_data_assets.dart`, which regenerates the (~4000-line) asset list in `pubspec.yaml` between the `# BEGIN/END STELLARIUM DATA ASSETS` markers from the contents of `assets/stellarium/data/`. **Do not hand-edit that block** — add/remove files in `assets/stellarium/data/` and let the generator rebuild it. Running bare `flutter run` after changing data assets will ship a stale asset list.

```bash
flutter test                          # runs test/widget_test.dart
flutter gen-l10n                       # regenerate localizations (or use generate: true on build)
firebase deploy --only hosting        # web build is published from build/web (see firebase.json)
```

## Rebuilding the WASM engine

After editing C in `stellarium-web-engine/` you must recompile and copy the artifacts into the app:

```bash
cd stellarium-web-engine
source $PATH_TO_EMSDK/emsdk_env.sh    # emscripten must be on PATH
make js                               # release; uses emscons + scons (also: make js-debug)
cp build/stellarium-web-engine.js   ../stellarium_flutter/assets/stellarium/
cp build/stellarium-web-engine.wasm ../stellarium_flutter/assets/stellarium/
```

Engine source lives in `stellarium-web-engine/src/` (`modules/` = renderable layers: `stars.c`, `planets.c`, `constellations.c`, …; `js/pre.js` = the Emscripten-exported JS API surface). Build is SCons-driven (`SConstruct`), wrapped by the `Makefile`.

## Flutter app structure (`stellarium_flutter/lib`)

Mixed feature-first + layered layout:

- `features/` — newer feature-first modules with `presentation/` subfolders: `auth/`, `onboarding/`, `subscription/`.
- `screens/` — top-level screens (`home_screen.dart` is the main sky screen and is large/central).
- `widgets/` — `sky_view.dart` (orchestrates engine/WebView + gyroscope + gestures), `stellarium_webview.dart`, `star_info_sheet.dart`, `settings_panel.dart`, `bottom_bar.dart`, `time_slider.dart`.
- `stellarium/` — the engine abstraction layer (see pattern above) plus `observer.dart`, `stellarium_settings.dart`.
- `services/` — **singletons accessed via `.instance`** (e.g. `SavedStarsService.instance`). Cover auth, Firestore sync, analytics, Klaviyo, notifications, subscriptions, saved/searched stars, background music.
- `l10n/` — ARB-based localization (`en`, `de`, `es`, `fr`, `zh`); config in `l10n.yaml`, `flutter: generate: true`.

`main.dart` owns a deliberately ordered async startup (Firebase → Adapty → notifications → services). Note the intentional deferrals: Firestore sync and notification-permission prompts are held until **after onboarding** (and wrapped in `timeout`/`unawaited`) so they never block launch or prematurely trigger OS permission dialogs. Preserve this ordering when adding startup work.

## Backend & third-party integrations

- **Firebase** (`firebase.json`, `functions/`): Auth, Firestore, Analytics, Crashlytics, Messaging, In-App Messaging. Cloud Functions (`functions/`, TypeScript, Node 20) implement **star-visibility push notifications** — the app syncs saved stars to Firestore via `FirestoreSyncService` and Functions decide when to notify. Build/deploy: `cd functions && npm run build && npm run deploy`. Firestore security in `firestore.rules` / `firestore.indexes.json`.
- **Adapty** — subscriptions and paywalls (`features/subscription/`, `subscription_availability_service.dart`).
- **Klaviyo** — email/push marketing; push payloads are forwarded to `KlaviyoService.instance.handlePush` (including from the top-level background message handler in `main.dart`).
- Notification taps route through `_handleNotificationTap` in `main.dart` (external URL, `registration_number` deep link to a star, or `screen` navigation).

## Custom star labels (engine + bridge + app feature)

A cross-layer feature documented in `CUSTOM_LABELS_IMPLEMENTATION.md`. Two label systems live in the C engine: a transient **selection custom label** (`core->selection_custom_label`) and **persistent labels** keyed by normalized HIP number (`core->persistent_labels`), both rendered gold in `modules/stars.c`. Exposed through `src/js/pre.js` → `window.stellariumAPI` → `StellariumWebView` methods → `SavedStarsService`. Editing this feature means touching all four layers and rebuilding the WASM engine.
