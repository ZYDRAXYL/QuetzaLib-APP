---
name: write-docs
description: Auto-generate and keep project documentation in sync with the code — explains what each system/module does and what each file contains (docs/SYSTEMS.md, docs/FILES.md), and appends a dated changelog entry summarizing what Claude changed and why (docs/CHANGELOG.md). Use when asked to "document this change", "write documentation", "sync docs with code", "update the changelog", or proactively after a set of edits big enough that the docs would go stale.
---

# write-docs — sync docs/SYSTEMS.md, docs/FILES.md, docs/CHANGELOG.md with the code

Paths below are relative to the repo root (`QuetzaLib-APP/`), not to this
skill directory.

This skill maintains three files:

| File | Purpose | Audience |
|---|---|---|
| `docs/SYSTEMS.md` | How each system/service behaves — data flow, what happens when the user does X | Someone who wants to understand behavior without reading code |
| `docs/FILES.md` | What's in each file, per-directory — line counts, responsibilities, key functions/classes | Someone about to edit a specific file |
| `docs/CHANGELOG.md` | Dated log of what Claude changed, why, and which of the above two files it touched | Anyone tracking what happened between sessions |

**The driver is a diff detector, not an app launcher** — figuring out *what
changed since docs were last synced* is `.claude/skills/write-docs/docs-diff.sh`.

## Run (the actual workflow)

### 1. See what changed since the last doc sync

```bash
bash .claude/skills/write-docs/docs-diff.sh
```

This prints:
- Uncommitted working-tree changes (`git status --porcelain`)
- If `.claude/skills/write-docs/.last-sync` exists: commit log + changed-file
  list between that commit and `HEAD`
- If no marker exists yet (first run ever): a note to treat it as a full-repo
  scan, plus the full tracked file list

Read the actual diff/files — don't guess from commit messages alone. A commit
message can undersell what changed.

### 2. Update docs/FILES.md for touched files

For every file in the diff:
- If the file is new: add an entry under the right directory table/section
  (`lib/models`, `lib/services`, `lib/services/metadata_providers`,
  `lib/state`, `lib/screens`, `lib/widgets`, `lib/l10n`, `android/`).
- If the file changed meaningfully (new function/class, changed
  responsibility, new public API, new DB column, new route/screen): update
  its existing entry. Don't just note "changed" — say *what* changed (new
  method name, new table column, new provider).
- If the change is cosmetic (formatting, comment tweak, variable rename with
  no behavior change): skip — don't pad the doc with noise.

### 3. Update docs/SYSTEMS.md for affected systems

Ask: does this diff change *user-visible behavior* or *data flow* for any
system section (scanning, metadata lookup, OCR scan-to-fill, cover/page
capture, library/shelf, reading-status stamps, in-app updates, settings)? If
yes, update that section's prose. If the diff only touches internals with no
behavior change (refactor, perf, dead code removal), leave SYSTEMS.md alone.

**Verify claims against the real app when the change is behavioral, not just
against the diff.** A diff can look right and still not work. Run `flutter
analyze` and `flutter test` at minimum; if this environment has the Android
SDK reachable, use `.claude/skills/run-quetzalib/SKILL.md` to actually launch
the app before writing the behavior down as fact — otherwise say explicitly
that the behavior is verified by code reading and tests only, not a live run
(see that skill's "Environment limits" section).

### 4. Append a changelog entry

Prepend (newest first) to `docs/CHANGELOG.md` using this format:

```
## YYYY-MM-DD — short title
- commit: <sha, or "uncommitted" if not committed yet>
- Files changed: path/a.dart, path/b.dart
- What changed: ...
- Why: ...
- Docs updated: docs/SYSTEMS.md §X, docs/FILES.md §Y (or "no doc impact" if neither needed an update)
```

Match the language already in the changelog (English, matching this repo's
commit history). Keep each entry to what actually changed; don't restate the
whole diff line by line.

### 5. Mark the sync point

Only after `docs/SYSTEMS.md`, `docs/FILES.md`, and `docs/CHANGELOG.md` are all
updated (or explicitly confirmed to need no update):

```bash
bash .claude/skills/write-docs/mark-synced.sh
```

This writes current `HEAD` to `.claude/skills/write-docs/.last-sync`. The
next run's diff starts from here.

**Don't run this if there are still-uncommitted changes you intend to keep
editing** — the marker is meant to track "docs are caught up to code," and if
code keeps moving without a commit, re-run step 1 instead of trusting the
marker.

## First run on a fresh checkout / new project

If `docs/SYSTEMS.md` or `docs/FILES.md` don't exist yet, this isn't an
incremental sync — do a **full scan**:
1. List every file under `lib/` (and anything relevant in `android/`,
   `test/`) with `git ls-files`.
2. For each system (scanning, metadata lookup providers, OCR, cover/page
   capture, library state, in-app updater) read enough of the code to
   describe real behavior, not just file names.
3. If the app is drivable in this environment (Android SDK reachable), use
   `run-quetzalib` and actually exercise the flows before writing "how it
   behaves" — don't infer behavior from code alone when you can verify it.
   If it isn't drivable here, say so and base the write-up on code + tests.
4. Write `docs/SYSTEMS.md` and `docs/FILES.md` from scratch, then seed
   `docs/CHANGELOG.md` with one baseline entry describing "initial doc write".
5. Run `mark-synced.sh` to set the baseline.

## Gotchas

- `git diff --name-status <marker>..HEAD` silently returns nothing if
  `<marker>` was on a branch that got rebased/squashed away — `docs-diff.sh`
  checks `git cat-file -e <marker>^{commit}` first and tells you to fall back
  to a full re-scan rather than reporting a false "nothing changed."
- The marker file itself (`.claude/skills/write-docs/.last-sync`) and
  `docs/` are excluded from the diff/`git ls-files` output in
  `docs-diff.sh` — otherwise every doc-sync run would show up as a change
  needing documentation about itself.
- Uncommitted changes always show up in step 1 regardless of the marker —
  don't skip documenting something just because it hasn't been committed.
  If it's uncommitted, write `commit: uncommitted` in the changelog entry and
  correct it to the real sha in a later pass once it lands (or just leave it —
  the important record is that the change happened).
- This skill does not commit anything itself and does not run `mark-synced.sh`
  automatically — both are explicit steps so a partial/interrupted doc-sync
  never silently advances the marker past work that wasn't actually
  documented.
