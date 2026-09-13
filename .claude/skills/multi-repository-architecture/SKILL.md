---
name: multi-repository-architecture
description: The contract for QuetzaLib's six-repository architecture — which of APP/SDB/EXE/PWA/WEB owns a given file, where DEV fits, which direction changes flow, and where a new piece of work belongs. Read this BEFORE creating a file, moving code between repos, or answering "where does this live" — guessing produces a change in the wrong repo that the chain then propagates everywhere. Use when starting work in any QuetzaLib repo, when a change touches more than one repo, when adding a repo or an edge to the chain, or when asked "อยู่ repo ไหน", "ควรแก้ที่ไหน", "โครงสร้าง repo", "multi-repo", "which repo owns this".
---

# QuetzaLib multi-repository architecture

`chain/chain.json` is the machine-readable form of everything below. Read it
rather than trusting this prose where the two disagree — and print the resolved
view for the repo you are standing in with:

```bash
node tools/chain-lib.mjs
```

## The six repos

| Repo | Role | Owns | Releases |
|---|---|---|---|
| **APP** | hub + app | `.claude/` (the source of every chain skill), `chain/`, `tools/`, `docs/`, and the Flutter app itself — `lib/`, `android/`, `web/`, `test/`, `pubspec.yaml` | `v*` |
| **SDB** | schema | `schema/` — the SQLite schema snapshot and migration history; `backup-format/` — the `.zip` backup archive spec | `sdb-v*` |
| **EXE** | app | `electron/` — the Windows desktop shell hosting the Flutter web build | `exe-v*` |
| **PWA** | build | `tools/`, `shim/`, `dist/` — the installable browser build of APP's Flutter tree | — |
| **WEB** | site | the marketing site, its Docs pages, and the public release mirror | mirror |
| **DEV** | controller | the multi-root workspace file and the setup/start scripts — **not in the chain** | — |

## Why APP is both hub and app

DraconDex, which this architecture is adapted from, has a hub repo holding no
application code. QuetzaLib has one repo fewer, so APP carries both jobs: it is
the Flutter app *and* the source of every chain skill, the chain contract, and
the tooling. That works only because **APP receives nothing** — it is the root
of the graph, with no incoming edges. Check that property before adding an edge:

```bash
node tools/chain-lib.mjs | grep '^upstream'   # must print: upstream —
```

The moment something points *at* APP, the graph gains a cycle and propagation
loops forever. That is why SDB is downstream of APP here and not upstream of it,
which is the one place this architecture inverts DraconDex's: QuetzaLib's schema
is authored in Dart, in `lib/services/database_service.dart`, so the app is the
schema's source and SDB publishes a snapshot of it — not the other way round.

**DEV is outside `chain.json` entirely.** It holds the workspace and the scripts,
its skills describe the multi-root checkout that no chain repo can see, and it is
absent from `MIRROR_SETS`. Do not add it.

## The four chains

```
android   APP > WEB
desktop   APP > EXE > WEB
browser   APP > PWA > WEB
schema    APP > SDB > WEB
```

Changes flow **left to right, never backwards.** That single property is what
prevents an infinite propagation loop, and it is why `chain.json`'s `edges` are
directed. Every chain terminates at WEB, because WEB is the public release
mirror all three products' update checkers poll.

## Where does this change belong?

| If you are changing... | Do it in | Notes |
|---|---|---|
| a screen, widget, service, provider, model | **APP** | `lib/` — PWA and EXE build from this same tree, never fork it |
| a table, a column, `_dbVersion`, a migration | **APP** | `lib/services/database_service.dart` is the source; SDB's snapshot follows |
| the published schema snapshot or the backup-archive spec | **SDB** | generated from APP — see rule 1 |
| a hand-written `_en`/`_th` string | **APP** | `lib/l10n/app_localizations.dart`; run the `quetzalib-l10n-style` check |
| the Electron main process, the desktop window, the installer | **EXE** | `electron/` |
| the browser shims, the service worker, the PWA build | **PWA** | APP's `web/` holds the Flutter shell; PWA holds the build around it |
| the website, the download page, the Docs manuals | **WEB** | |
| a chain skill, an agent, `chain.json`, `tools/` | **APP** | then `node tools/mirror-claude.mjs` |
| a Flutter-only skill (`run-quetzalib`, `version-update`, …) | **APP** | APP-only by design — it is not in any mirror set |
| the workspace file, the setup/start scripts | **DEV** | |

## Three rules that are not negotiable

**1. Never hand-edit a generated or mirrored file at its destination.**
Every one carries a header naming its source. Edit the source; let the chain
carry it. The files this covers:

| Destination | Source |
|---|---|
| any `.claude/skills/**` or `.claude/agents/**` outside APP | APP `.claude/**` |
| any `chain/chain.json` outside APP | APP `chain/chain.json` (with `self` rewritten) |
| any `tools/chain-*.mjs` outside APP | APP `tools/` |
| SDB `schema/**` | APP `lib/services/database_service.dart` |
| PWA `dist/**` | built from APP's Flutter tree |

**2. `lib/` is one source tree serving Android, web, and desktop.**
It splits by platform through conditional exports, not by forking:
`local_image_platform.dart` exports `_io` / `_web`, and the same pattern repeats
for `app_image_impl_*`, `local_image_size_*`, `app_update_section_*`. PWA and EXE
are *build targets* of that tree. Copying `lib/` into either forks the app and
every later fix has to be made twice.

**3. The release trains are independent and namespaced.**
APP ships `vX.Y.Z` from `pubspec.yaml`; EXE ships `exe-vX.Y.Z`; SDB ships
`sdb-vX.Y.Z`. Their numbers are unrelated and any may be newest overall. The
in-app updater (`lib/services/update_service.dart`) must filter by tag prefix,
because `/releases/latest` returns whichever was published most recently
regardless of product — a desktop release would otherwise offer itself as an
Android update. Never remove a tag prefix, and never point a checker at a
private repo: `api.github.com` answers 404 for a private repo to everyone
without a token, which is every install of the app.

## Related skills

- `chained-supporter` — run before work: what changed in the other repos
- `chained-updated` — run after work: push the change downstream
- `build-release-git` / `version-update` — APP's own release train (APP-only)
