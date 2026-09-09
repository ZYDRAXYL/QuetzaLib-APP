---
name: build-release-git
description: Decide whether the current version is due for a GitHub release, and cut it by pushing a `vX.Y.Z` tag — `.github/workflows/release.yml` runs the Flutter test suite, builds the release APK, and publishes it as a GitHub Release asset. Use when asked to "cut a release", "build the release", "publish to GitHub releases", or after `version-update` bumps a version and you need to know whether that bump is due for a release yet.
---

# build-release-git

`version-update` decides the *number*. This skill decides whether that number
is worth a **release**, and cuts it.

## The one mechanism

Pushing a `v*.*.*` tag is the entire release trigger.
`.github/workflows/release.yml` does the rest: `flutter pub get` → `flutter
test` → `flutter build apk --release` → renames the APK to
`quetzalib-<tag>.apk` → `softprops/action-gh-release` publishes it as a
GitHub Release with auto-generated notes. The same workflow also supports a
manual `workflow_dispatch` run with an explicit `tag_name` input.

There is no other supported path — do not build locally and upload by hand.
Note the release build is signed with the shared keystore committed at
`android/app/release-keystore.jks` (see `android/key.properties`), so every
release — CI or local — produces an APK Android will accept as an update over
a previously-installed build. Don't touch that keystore/config as part of a
routine release.

## Is a release due?

This app is small and young (no tags cut yet as of this writing — check
`git tag --list` before trusting that assumption). Unlike DraconDex, there's
no dense multi-commit-per-day cadence here to throttle, so default to a
simpler rule:

- **Release whenever `pubspec.yaml`'s version was just bumped for a
  user-facing reason** — a new feature, a real bug fix users hit, a version
  the user explicitly wants published. Don't cut a release for a version
  bump that only exists to test the bump process itself.
- **Always release, cadence aside:**
  - The user asked for a release outright.
  - A crash, data-loss, or install/update-breaking fix landed (this repo's
    own history has one of these — the signature-conflict fix in `c32b8f0`).
  - `update_service.dart`'s in-app updater is what surfaces new releases to
    existing installs — if a fix doesn't ship as a release, no installed
    copy of the app will ever see it.

If this project's release cadence picks up later (frequent small patches),
revisit this rule the way DraconDex's `build-release-git` throttles minor/fix
bumps — but don't invent that complexity preemptively for a project that
doesn't need it yet.

## Flow

1. **Confirm the tree is clean and on the right branch.** `git status
   --short` must be empty, and `HEAD` must be the commit you intend to ship
   (normally the repo's default branch after a `version-update` bump has
   landed).

2. **Check the version isn't already released.** Local tags can lag the
   published list:

   ```bash
   git fetch --tags --quiet
   git tag --list 'v*' --sort=-v:refname | head -5
   ```

   Tag names are `v<version>` with **no build-number suffix** — the
   `pubspec.yaml` version `1.1.1+4` tags as `v1.1.1`, not `v1.1.1+4` (the
   `+build` part is Android-internal bookkeeping, not part of the release
   tag). Confirm against `pubspec.yaml`'s current `X.Y.Z`:

   ```bash
   grep '^version:' pubspec.yaml
   ```

3. **Tag and push.**

   ```bash
   git tag -a v1.1.1 -m "QuetzaLib 1.1.1"
   git push origin v1.1.1
   ```

   Push the tag alone. Never `git push --tags` — it fires every unpushed tag,
   and every one starts its own build+publish job.

4. **Report the run.** The workflow takes a few minutes (Flutter setup +
   test + APK build). Point the user at the Actions tab for
   `.github/workflows/release.yml`, and confirm the release afterward:

   ```bash
   curl -s https://api.github.com/repos/ZYDRAXYL/QuetzaLib-APP/releases/latest
   ```

   One asset is expected: `quetzalib-v<version>.apk`.

## When it goes wrong

- **`flutter test` fails in CI** — the release does not build or publish, by
  design. Fix on the branch, then delete and re-push the tag; a tag pointing
  at a commit whose build never published is safe to re-cut.

  ```bash
  git push origin :refs/tags/vX.Y.Z   # delete the remote tag
  git tag -d vX.Y.Z                   # delete the local tag
  ```

- **Release exists but the asset is missing** — re-run the workflow manually
  via `workflow_dispatch`, passing the same `tag_name`. The upload step is
  the last one in the job; a partial failure there is safe to retry.
- **Tag already published** — never move a published tag. Bump the version
  (`version-update`) and cut the next one instead.
- **Android refuses to install the release APK as an "update"** — almost
  always a signing-certificate mismatch (see the README's "Release builds"
  section and `c32b8f0`'s fix). Confirm the CI build actually used the
  committed `android/app/release-keystore.jks`, not a fresh debug keystore.

## What this skill does not do

- It does not bump versions. That's `version-update`; run it first so
  `pubspec.yaml` and the tag agree.
- It does not write changelogs. The GitHub Release notes are
  `generate_release_notes: true` (commit-derived); `docs/CHANGELOG.md` (if
  present) is `write-docs`'s job, and covers dev-facing history, not release
  notes.
- It does not touch `.github/workflows/build.yml` (the debug/CI build that
  runs on every push/PR) — that's a separate, unrelated workflow.
