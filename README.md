# QuetzaLib

Android app (Flutter, built as an `.apk`) that scans the ISBN barcode on
the back of a book, looks up its metadata, and adds it to your personal
library, stored locally on-device in SQLite.

## Features

- **Scan-to-add**: scan an ISBN-10/13 barcode with the camera and look up
  the book automatically.
- **Metadata lookup**:
  - Books: [Google Books API](https://developers.google.com/books) first,
    falling back to [Open Library](https://openlibrary.org/dev/docs/api/books).
  - Light novels: [RanobeDB](https://ranobedb.org) is tried last as a
    specialized fallback, since most scanned books aren't light novels — see
    the note in `ranobedb_provider.dart` for how its
    [public API](https://ranobedb.org/api/docs/v0) resolves an ISBN-13.
- **Add by ISBN text entry**: type or paste an ISBN-10/13 instead of
  scanning, via the same lookup flow as the barcode scanner.
- **Manual add/edit**: for books with no barcode or no metadata match.
- **Search the shelf by scan**: scan a book already in your library to jump
  straight to it, in addition to the free-text search.
- **Cover/spine scanning**: scan a book's front cover, spine, and back
  cover into a reusable preset (a book can have several; one is active at
  a time) from the book detail screen, or promote its existing API
  thumbnail into a preset instead of rescanning it. Presets can be edited
  afterward — skip a slot now and scan it in later. Capture uses Google
  Play services' document scanner instead of a plain camera shot, so the
  page is auto-detected, straightened, and cropped before it's saved.
- **Scan-to-fill book fields**: a scan button next to Title, Authors,
  Illustrators, ISBN, and Publisher in the book editor photographs that
  text and runs OCR on it. The recognized text is always shown back to you
  in an editable review dialog first — nothing is written into the field
  until you approve it (editing it first if needed). See
  [OCR text scanning](#ocr-text-scanning) below for the on-device vs. Cloud
  Vision tradeoff.
- **Saved pages**: photograph a page or illustration inside a book and
  keep it as an in-app reminder, with an optional label and note.
- **Reading-status stamps**: a timeline of `reading` / `finished` /
  `dropped` / `paused` stamps per book instead of a single status field —
  add, edit, or delete a stamp at any time; a book's current status is
  just its most recent stamp.
- **Shelf view**: browse the library as a visual shelf of spines or covers
  (a global List/Shelf and spine/cover toggle), falling back to a text
  info tile for books with no scanned cover yet.
- **Custom list details**: **Settings → Book list details** decides which
  facts the library list prints under each book's title — series, volume,
  language, genre, category, publisher, year, page count, ISBN — and
  whether they stay on one line (every row the height of its cover) or wrap
  onto several. A book only shows the details it actually has, so turning
  one on never leaves an empty slot behind.
- **Library management**: categorize books (custom categories you define)
  and search/filter by title, author, ISBN, or reading-status stamp. Search
  covers every "Info" field — author, illustrator, series, genre, language,
  publisher, category — not just title/author/ISBN.
- **Name sets (one thing, several names)**: group names that mean the same
  thing (e.g. `TH`, `thai`, `ไทย`) under **Categories → Name sets**, and
  searching any one of them finds every book matching any of the others. A
  set is just a bag of equivalent words — you never declare what kind of
  name it is, so the same set works for a language, a publisher's two
  spellings, or an author's pen name. Book titles are the one exception:
  they stay a single name in their own language and are always matched
  exactly as typed. Building a set pulls from names already used across
  your books instead of retyping them — every author, illustrator, series,
  genre, language, publisher and category you've entered is offered as a
  pick, and stays available the moment it's entered on any book. Two sets
  can be merged into one (long-press to select, then Merge), and a set that
  turned out to bundle unrelated names can be split back apart (the
  scissors action on a set).
- **Fully local**: all data lives in an on-device SQLite database
  (via `sqflite`) — nothing is synced anywhere.
- **Backup & restore**: **Settings → Backup & restore** exports the whole
  library — books, categories, reading history, cover/spine/page photos,
  and name sets — into a single `.zip` file you can save anywhere and
  import back later, on this device or another one. Importing replaces
  everything currently in the app.
- **In-app updates**: since QuetzaLib isn't distributed through the Play
  Store, **Settings → App update** checks GitHub Releases for a newer
  build and installs it over the existing app — see [App updates](#app-updates)
  below.

## Tech stack

- Flutter (Android target, plus a web/PWA target -- see [Web
  (PWA)](#web-pwa)), Material 3
- `sqflite` for local storage (native), `sqflite_common_ffi_web` for the
  same on-device database on web (a real sqlite file, persisted in the
  browser's IndexedDB rather than on a filesystem)
- `mobile_scanner` for barcode scanning + `permission_handler` for the
  camera permission
- `image_picker` for cover/spine/page photo capture, and the OCR-scan
  photo source in the book editor
- `google_mlkit_document_scanner` for cover/spine/back capture (auto edge
  detection, perspective correction, cropping) -- Android only; on web the
  cover/page photo flows fall back to `image_picker`'s plain gallery/camera
  picker
- `google_mlkit_text_recognition` for on-device OCR (default; Latin script
  only), with an optional Cloud Vision API fallback for Thai text -- on-device
  recognition is Android/iOS only, so web always needs a Cloud Vision key
- `provider` for state management
- `http` for metadata lookups (Google Books JSON, Open Library JSON) and
  the optional Cloud Vision OCR call
- `package_info_plus` + `path_provider` for the in-app updater (current
  version check, downloaded-APK staging)
- `archive` + `file_picker` for backup export/import (bundling the library
  into a `.zip`, then saving/picking it cross-platform)

## Project layout

```
lib/
  models/            Book, BookCategory, NameAliasGroup, ReadingStamp,
                      BookCoverPreset, BookPage, BookMetadata, AppUpdateInfo,
                      BookMetaField (which details the library list shows)
  services/
    database_service.dart       sqflite schema + CRUD
    isbn_utils.dart             ISBN validation/normalization
    settings_service.dart       persisted app settings (Cloud Vision API key,
                                 shelf display mode, book list details)
    book_metadata_service.dart  orchestrates provider lookup order
    book_lookup_service.dart    shared ISBN -> existing book/metadata/not-found resolution
    name_alias_index.dart       expands a search term into its equivalent names
    metadata_providers/         google_books, open_library, ranobedb
    document_scanner_service.dart  cover/spine/back capture via the ML Kit document scanner
    ocr_service.dart            scan-to-fill OCR: Cloud Vision if configured, else on-device
    image_storage_service.dart  persists scanned cover/page photos on-device
                                 (delegates to local_image_platform*.dart --
                                 real files natively, IndexedDB-backed blobs
                                 on web)
    update_service.dart         checks GitHub Releases, downloads + installs the APK
                                 (native only; see widgets/app_update_section*.dart)
    apk_installer.dart          platform channel to the native install-APK intent
    backup_service.dart         exports/imports the whole library + its local
                                 photos as a single .zip (see widgets/
                                 backup_restore_section.dart)
  state/
    library_provider.dart       app state (ChangeNotifier) wrapping the DB
    library_grouping.dart       pure sort-group/section helpers for the list+shelf
    library_search.dart         pure search matcher (literal + name-set expansion)
  screens/                      library list/shelf, scan, book detail/edit, cover/page
                                 scanning, ISBN entry, categories, settings
  widgets/                      shared UI pieces, incl. app_image.dart (the
                                 native-file-vs-web-blob image widget) and
                                 app_update_section.dart (native-only updater UI)
web/                             PWA shell: index.html, manifest.json, icons
                                 (see Web (PWA) below)
```

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
and Android SDK/platform tools (Android Studio is the easiest way to get
both).

```bash
flutter pub get
flutter run            # run on a connected device/emulator
flutter build apk       # release apk -> build/app/outputs/flutter-apk/app-release.apk
flutter build apk --debug
```

`flutter analyze` and `flutter test` both pass as of this scaffold. A
GitHub Actions workflow (`.github/workflows/build.yml`) builds a debug APK
and a release APK on every push/PR as a CI check and artifact — useful in
environments (like the one this scaffold was prepared in) where the
Android SDK itself isn't reachable, so the APK can't be built locally
there.

### Release builds

`.github/workflows/release.yml` builds a release `.apk` and publishes it
as a GitHub Release with the APK attached, either:

- automatically, on pushing a tag matching `v*.*.*` (e.g. `git tag v1.0.0
  && git push origin v1.0.0`), or
- manually, via the "Run workflow" button on the Release workflow in the
  Actions tab, entering a tag name.

The release build is signed with a shared keystore committed at
`android/app/release-keystore.jks` (configured via `android/key.properties`,
loaded by `android/app/build.gradle.kts`), so every build — CI or local —
signs with the same certificate. This matters because Android refuses to
install an "update" APK signed with a different certificate than the one
already on the device ("App not installed as package conflicts with an
existing package"); before this, every CI run signed with a freshly
auto-generated debug keystore, so no two release builds shared a
certificate. This is still not a production-grade key — replace it with a
real, unshared signing config before a production/Play Store release. If
you've already got a build installed from before this change, you'll need
to uninstall it once before an update signed with the new shared key will
install.

## Web (PWA)

Alongside the Android app, QuetzaLib also builds as an installable web app
(PWA) -- usable from any modern browser, including Safari on iPhone/iPad,
which have no Android APK equivalent to install.

```bash
flutter pub get
dart run sqflite_common_ffi_web:setup   # fetches sqlite3.wasm + sqflite_sw.js into web/
flutter run -d chrome                    # local dev
flutter build web --release              # -> build/web/
```

`.github/workflows/build.yml` runs `flutter build web` on every push/PR as a
CI check (`build-web` job); `.github/workflows/deploy-web.yml` builds and
publishes `build/web/` to GitHub Pages on every push to `main`. **The
repository's Pages source needs to be set to "GitHub Actions" once**
(Settings → Pages → Build and deployment → Source) before that workflow can
actually publish.

Everything that reads/writes the library works the same on web as on
Android -- same `LibraryProvider`/`DatabaseService` code, same auto-loaded
local database on startup -- the difference is entirely in *where* that
data lives, since a browser has no filesystem:

- **Database**: `sqflite_common_ffi_web` backs the same `sqflite` API with a
  real sqlite database file, persisted in the browser's IndexedDB instead of
  on disk. It's still private to this browser profile/device, just not a
  file you can browse to.
- **Cover/page photos**: native saves copy the picked photo into the app's
  documents directory and stores that file path; web instead saves the
  photo's bytes into a `local_images` table in that same on-device database,
  under a synthetic `webimg://...` path. `AppImage` (`lib/widgets/app_image.dart`)
  and `ImageStorageService` hide this difference from every screen.
- **Two mobile-only features degrade gracefully instead of being ported**:
  the ML Kit document scanner (auto-crop/perspective-correct cover/spine/back
  photos) is Android-only even natively, so its "Scan document" option is
  hidden on web in favor of `image_picker`'s plain gallery/camera picker --
  on iPhone Safari this still offers "Take Photo" via the OS file picker.
  The in-app APK updater (**Settings → App update**) doesn't apply to a
  browser tab at all and is simply absent there (`AppUpdateSection`).
- On-device OCR (ML Kit text recognition) is also Android/iOS-only, so the
  scan-to-fill buttons in the book editor need a Cloud Vision API key
  configured in Settings to work on web -- see [OCR text
  scanning](#ocr-text-scanning) below.

### Installing on iPhone

Safari doesn't support the install prompt other browsers show automatically;
add QuetzaLib to the home screen manually instead: open the deployed URL in
Safari, tap the **Share** icon, then **Add to Home Screen**. It then launches
full-screen like a native app (`web/index.html`'s
`apple-mobile-web-app-capable` meta tag + `apple-touch-icon`), with its data
staying local to that installation the same way any other PWA's does.

## OCR text scanning

The scan buttons next to Title, Authors, Illustrators, ISBN, and Publisher
in the book editor photograph that text and run OCR on it, then always show
the recognized text back to you in an editable dialog before it's applied —
scanning never silently overwrites a field.

By default this uses Google ML Kit's on-device text recognizer: free,
offline, and fast, but it only reads Latin-script text — Thai titles and
credits will come back empty or garbled. To get accurate Thai (and Latin)
recognition instead:

1. Create a Google Cloud Vision API key (Cloud Console → APIs & Services →
   Credentials, with the Cloud Vision API enabled on that project).
2. In the app, go to **Settings** and enter it under **Text scanning
   (OCR)**.

Once set, every OCR scan is sent to the Cloud Vision API instead of running
on-device, billed to that key's Cloud project. Clear the field to go back
to on-device recognition.

## App updates

QuetzaLib isn't distributed through the Play Store, so it can't rely on
Play's automatic update mechanism. Instead, **Settings → App update** lets
an existing install update itself in place:

1. Tap **Check for updates**. The app queries the GitHub Releases API
   (`/repos/ZYDRAXYL/QuetzaLib-APP/releases/latest`, published by
   `.github/workflows/release.yml`) and compares its `tag_name` against
   the running app's version (`PackageInfo`/`pubspec.yaml`).
2. If a newer release has an `.apk` asset attached, tap **Download &
   install**. The APK is downloaded to the app's private cache
   (`<cache>/updates/`), then streamed into a `PackageInstaller` session
   (see `MainActivity.kt` and `android.permission.REQUEST_INSTALL_PACKAGES`
   in `AndroidManifest.xml`), which reports back a final status instead of
   the app just firing off an intent and hoping.
3. The OS will prompt to allow "install unknown apps" for QuetzaLib the
   first time (Android's standard sideload-install flow), then shows the
   normal package-installer confirmation screen. Installing over the
   existing app keeps your local library/settings intact, same as any
   Android app update.
4. If Android rejects the install because this build is signed with a
   different certificate than the one already on the device (see
   [Release builds](#release-builds) below for why that can happen), the
   app now catches that specific failure (`PackageInstaller.STATUS_FAILURE_CONFLICT`)
   and shows a clear message telling you to uninstall the old build first,
   rather than leaving you looking at an opaque system dialog with no
   explanation from within the app.

This only surfaces releases that are actually published — see
[Release builds](#release-builds) above for how a new version gets
tagged and built.

## Notes on this environment

This scaffold was prepared in a sandboxed remote session without access to
the Android SDK (`dl.google.com` is not reachable from it), so the APK
itself could not be built and run end-to-end here. What *was* verified in
this environment:

- `flutter pub get` resolves all dependencies cleanly.
- `flutter analyze` reports no issues.
- `flutter test` passes (ISBN utility unit tests + a library-screen widget
  test).

Building and running the actual `.apk` on a device/emulator, and
verifying the barcode scanner and network lookups against real hardware,
still needs to happen in an environment with the Android SDK — either
locally or via the included CI workflow.
