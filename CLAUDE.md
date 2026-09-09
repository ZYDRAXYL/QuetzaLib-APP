# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

QuetzaLib: a Flutter app (`pubspec.yaml` name `quetzalib`) that scans a
book's ISBN barcode, looks up its metadata online, and manages a personal
library stored entirely on-device in SQLite. Primary target is Android
(built as an `.apk`, not distributed through the Play Store); it also
builds as an installable web PWA. There is no backend — every feature is
local-first except the metadata-lookup and update-check network calls.

## Commands

```bash
flutter pub get                 # install dependencies
flutter analyze                 # static analysis -- keep at zero issues
flutter test                    # unit + widget tests
flutter test test/isbn_utils_test.dart          # run a single test file
flutter test --plain-name "some test name"      # run a single test by name

flutter run                     # run on a connected device/emulator (Android)
flutter build apk               # release apk -> build/app/outputs/flutter-apk/app-release.apk
flutter build apk --debug

# Web (PWA) target
dart run sqflite_common_ffi_web:setup   # one-time: fetches sqlite3.wasm + sqflite_sw.js into web/
flutter run -d chrome                    # local dev in browser
flutter build web --release              # -> build/web/
```

There is no lint-fix/format command beyond `flutter analyze`; this repo's
own bar is zero analyzer issues. `.github/workflows/build.yml` runs
`pub get` -> `analyze` -> `test` -> `build apk` (debug + release) and a
separate `build-web` job on every push/PR — treat it as the source of
truth when the local environment can't build/run (see "Environment limits"
below).

### Releasing

Tagging is the entire release trigger: pushing `v*.*.*` (e.g. `git tag
v1.2.0 && git push origin v1.2.0`) makes `.github/workflows/release.yml`
run the test suite, build a signed release APK, and publish it as a GitHub
Release. `pubspec.yaml`'s `version: X.Y.Z+B` is the single source of
truth — `X.Y.Z` is semver, `B` is the Android build number and must
strictly increase every release (it's what the in-app updater compares).
Use the `version-update` skill to bump it and `build-release-git` to cut
the tag; don't hand-build and upload a release APK outside that workflow.

## Environment limits (be honest about what you actually verified)

This is frequently run in a sandbox without the Android SDK reachable
(`dl.google.com` blocked) and sometimes without `flutter` on PATH at all.
Check first:

```bash
which flutter adb
flutter devices
```

- No `flutter` on PATH: read code and reason about it, but say so rather
  than claiming analysis/tests ran.
- `flutter` present, no SDK/emulator: `pub get`, `analyze`, and `test` all
  work (no device needed) — this is the floor of verification. `build apk`
  and anything device-dependent will not run.
- Never say "verified in the running app" when only `analyze`/`test` ran.
  Camera/scanner features (`mobile_scanner`, `google_mlkit_*`) need a real
  device or emulator with camera support; they aren't exercised by
  `flutter test`.

## Architecture

### Layering

```
screens/   -> state/library_provider.dart (ChangeNotifier) -> services/ -> sqflite (native) / IndexedDB (web)
```

`LibraryProvider` (`lib/state/library_provider.dart`) is the **single**
`ChangeNotifier` holding all in-memory app state — books, categories,
reading-status stamp timelines, cover presets, saved pages, name-alias
groups, and the current search/filter/sort/view-mode selections. Screens
read it via `provider`'s `Consumer`/`context.watch`; there is intentionally
only one notifier so no two providers compete for the same UI. Anything
split out of it (e.g. `library_grouping.dart`, `library_search.dart`)
either takes the provider as a constructor arg or is a pure function —
never a second `ChangeNotifier`.

- `state/library_grouping.dart` — pure sort/group/section helpers for the
  list and shelf views.
- `state/library_search.dart` — pure search matcher: literal match plus
  name-set expansion (see below).

### Services (`lib/services/`, one file per concern)

- `database_service.dart` — the sqflite schema and all CRUD; the only
  place SQL lives.
- `isbn_utils.dart` — ISBN-10/13 validation and normalization (barcode
  scans and typed entry both funnel through this).
- `settings_service.dart` — persisted app settings via `shared_preferences`
  (Cloud Vision API key, shelf display mode, which book fields the list
  shows, theme, locale).
- `book_metadata_service.dart` — orchestrates ISBN lookup across providers
  in a fixed order (see below), swallowing any single provider's failure
  and trying the next.
- `book_lookup_service.dart` — shared "does this ISBN match an existing
  book, or fetch metadata, or report not-found" resolution used by both
  the scan flow and manual ISBN entry.
- `metadata_providers/` — one file per external API: `google_books_provider.dart`
  and `open_library_provider.dart` are tried first (general books);
  `ranobedb_provider.dart` (light novels, no direct ISBN search) is tried
  **last** since most scanned books aren't light novels.
- `name_alias_index.dart` — expands a search term into every name in its
  alias group (see "Name sets" below).
- `document_scanner_service.dart` — cover/spine/back capture via Google
  Play services' ML Kit document scanner (auto edge detection, perspective
  correction) — Android-only; web falls back to `image_picker`.
- `ocr_service.dart` — scan-to-fill OCR for the book editor: on-device ML
  Kit text recognition (Latin-script only) by default, or the Cloud Vision
  API if a key is set in Settings (needed for Thai, and always needed on
  web since on-device recognition is Android/iOS-only). Recognized text is
  always shown back in an editable dialog before being applied — never
  written silently.
- `image_storage_service.dart` — persists scanned cover/page photos,
  delegating to `local_image_platform_io.dart` (real files) or
  `local_image_platform_web.dart` (IndexedDB-backed blobs behind a
  synthetic `webimg://...` path) via the `local_image_platform.dart`
  conditional-export shim. `widgets/app_image.dart` hides this
  native-vs-web difference from every screen that renders a photo.
- `update_service.dart` + `apk_installer.dart` — in-app updater: checks
  `GET /repos/ZYDRAXYL/QuetzaLib-APP/releases/latest`, compares `tag_name`
  against the running `PackageInfo` version, downloads the APK to
  `<cache>/updates/`, and streams it into an Android `PackageInstaller`
  session (native only — see `MainActivity.kt` and
  `widgets/app_update_section_io.dart` / `_web.dart`).
- `backup_service.dart` — exports/imports the whole library (books,
  categories, stamps, photos, name sets) as a single `.zip` via `archive`
  + `file_picker`; import replaces everything currently in the app.

### Web vs. native: the conditional-export pattern

Several services have `_io.dart` / `_web.dart` sibling files behind a
platform-neutral entry point (`foo.dart` conditionally exports one or the
other based on `dart:io` availability): `local_image_platform*.dart`,
`app_image_impl_*.dart`, `local_image_size_*.dart`,
`app_update_section_*.dart`. When touching one of these concerns, check
whether the change needs to land in both the `_io` and `_web` variant, or
whether it belongs in the shared entry file instead.

### Name sets (`NameAliasGroup` / `name_alias_index.dart`)

A cross-cutting feature worth understanding before touching search: a
"name set" is a bag of equivalent strings (e.g. `TH` / `thai` / `ไทย`)
that all mean the same author/publisher/genre/language/category/series
name. Searching one member matches books tagged with any other member of
its set. Book titles are the one field excluded — always matched exactly
as typed, never alias-expanded. `library_search.dart` is where this
expansion is applied to the actual filter.

### Localization — hand-written, not `gen-l10n`

`lib/l10n/app_localizations.dart` is a **hand-written** `AppLocalizations`
class (two `const` maps, `_en` and `_th`, behind typed getters like
`AppLocalizations.of(context).save`) — not Flutter's generated `gen-l10n` +
`.arb` pipeline. A key missing from `_th` falls back to the English value
(`_t()`: `_values[key] ?? _en[key] ?? key`) rather than throwing, so an
incomplete translation degrades gracefully instead of crashing. Practical
implications when adding user-facing text:

1. Add the key to **both** `_en` and `_th` with the same key name (a typo
   in one produces one orphaned key and one silent English-fallback key —
   nothing errors).
2. Add a typed getter (or a method for `{placeholder}` strings, matching
   `documentScanFailed(String error)`'s pattern), grouped by screen the
   way the existing getters are.
3. Call sites use the getter, never a raw string literal.
4. Run `bash .claude/skills/quetzalib-l10n-style/check-l10n.sh` — checks
   en/th key parity and flags likely-hardcoded `Text('...')` literals in
   `lib/screens` and `lib/widgets` (heuristic grep, verify hits by hand).

`appTitle` ("QuetzaLib") is intentionally identical in both locales — it's
the brand name, not an untranslated string.

### Database

sqflite backs local persistence on native; on web, `sqflite_common_ffi_web`
provides the *same* `sqflite` API over a real SQLite file persisted in the
browser's IndexedDB (see the comment in `pubspec.yaml` above the sqflite
deps). This means `LibraryProvider`/`DatabaseService` code paths are
identical across platforms — only image storage (see above) differs.

## Repo layout

```
lib/
  main.dart              entry point, MaterialApp + ChangeNotifierProvider setup
  theme.dart             Material 3 ThemeData
  l10n/                  hand-written AppLocalizations (en/th) -- see above
  models/                plain data classes: Book, BookCategory, NameAliasGroup,
                         ReadingStamp, BookCoverPreset, BookPage, BookMetadata,
                         AppUpdateInfo, BookMetaField
  services/              one file per concern -- see above
  services/metadata_providers/  one file per external API
  state/                 LibraryProvider (the one ChangeNotifier) + pure helpers
  screens/               one file per screen
  widgets/               shared UI pieces
android/                 native Android project (MainActivity.kt, keystore/signing config)
web/                     PWA shell (index.html, manifest.json, icons)
test/                    mirrors lib/'s directory shape
.claude/skills/          project-specific Claude Code skills (see below)
```

### File-size guidance

No automated checker exists; use judgment (see the `quetzalib-file-arch`
skill for the full rationale): 0–250 lines is normal, 250–450 means check
for mixed responsibilities, 450–700 start considering a split, 700+
re-evaluate. `lib/l10n/app_localizations.dart` is explicitly exempt (it's
a translation-table data file). When a service concern grows past one
file, turn it into a folder (`metadata_providers/` is the existing
example), not `foo_bar_baz.dart` siblings dumped into `services/`.

### Tests (`test/`, mirrors `lib/`)

- `test/isbn_utils_test.dart`, `test/stamp_test.dart` — model/util unit tests.
- `test/models/`, `test/state/` — model and pure-helper unit tests.
- `test/services/`, `test/services/metadata_providers/` — service-layer
  tests; network calls are mocked via `http`'s test client, never hit real
  APIs.
- `test/widget_test.dart` — pumps `HomeScreen` inside a `MaterialApp` with
  `AppLocalizations.delegate` and a fresh `LibraryProvider`, asserting on
  rendered text. This is the closest thing to a UI driver in this repo —
  extend it rather than building a separate integration-test harness.

## Project-specific Claude Code skills (`.claude/skills/`)

This repo ships its own skills — prefer them over ad hoc approaches for
these tasks: `version-update` (bump `pubspec.yaml`'s version correctly),
`build-release-git` (cut a tagged release), `quetzalib-file-arch` (decide
whether/how to split a file), `quetzalib-l10n-style` (en/th key parity +
hardcoded-string check), `run-quetzalib` (how to run/test/verify given
this environment's actual capabilities), `write-docs` (keep `docs/`
in sync, if present).

## Notable constraints

- The release APK is signed with a shared keystore committed at
  `android/app/release-keystore.jks` (via `android/key.properties`,
  loaded by `android/app/build.gradle.kts`) so every build — CI or local —
  shares one signing certificate. Android refuses to install an "update"
  signed with a different certificate than what's already on the device,
  so never regenerate or bypass this keystore as part of routine work.
- The in-app updater and RanobeDB/Google Books/Open Library lookups all
  make real network calls — don't rely on them in an offline/sandboxed run.
- `flutter analyze` is expected to report zero issues; treat any new
  warning as something to fix, not suppress, unless there's a specific
  documented reason (see `analysis_options.yaml`).
