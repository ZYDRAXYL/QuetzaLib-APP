# Chain — the multi-repository contract

> Status: adopted 2026-09-13. QuetzaLib is split across six repositories, each
> with one job. [`chain.json`](chain.json) is the **single source of truth** for
> this — every skill and agent reads it instead of hardcoding repo names, which
> is why `chained-updated` works without being told any refs in a given session.

This architecture is adapted from
[DraconDex](https://github.com/ZYDRAXYL/DraconDex-APP)'s eight-repo chain. The
mechanics are the same; §2 records the one place QuetzaLib inverts it and why.

## 1. Who owns what

| Repo | Role | Owns | Release tag |
|---|---|---|---|
| **APP** | hub + app | `.claude/` (the source of every chain skill), `chain/`, `tools/`, `docs/`, and the Flutter app: `lib/`, `android/`, `web/`, `test/` | `v*` |
| **SDB** | schema | `schema/` — SQLite schema snapshot + migration history; `backup-format/` — the `.zip` backup spec | `sdb-v*` |
| **EXE** | app | `electron/` — the Windows desktop shell around the Flutter web build | `exe-v*` |
| **PWA** | build | `tools/`, `shim/`, `dist/` — the installable browser build | — |
| **WEB** | site | the website, its Docs pages, and the **release mirror** the apps poll for updates | mirror |
| **DEV** | controller | the multi-root workspace file and the setup/start scripts — **not in the chain** | — |

**The single most important rule:** a file that was generated or mirrored is
**never hand-edited at its destination.** Change the source and let the chain
carry it. Every such file has a header saying where it came from.

## 2. Why APP is both the hub and the app

DraconDex's hub repo holds no application code, so it can sit at the root of the
graph while a separate repo owns the schema upstream of the apps. QuetzaLib has
one repo fewer, so APP does both jobs.

That is safe for exactly one reason: **APP has no incoming edges.** It is the
root. Verify it before adding any edge:

```bash
node tools/chain-lib.mjs | grep '^upstream'   # in APP this must print: upstream —
```

The consequence is that **SDB is downstream of APP here, where DraconDex's SDB
is upstream of its apps.** This is not an oversight. QuetzaLib's schema is
authored in Dart — `lib/services/database_service.dart` holds the `CREATE TABLE`
statements and `_dbVersion` — so the app *is* the schema's source, and SDB
publishes a snapshot of it. Making SDB upstream would mean either a cycle
(`APP → SDB → APP`) or rewriting the app to load its DDL from a `.sql` master.
The first is forbidden; the second is a real refactor, not an architecture
change, and is not what this split did.

**DEV is outside `chain.json` entirely.** It holds the workspace and scripts,
its skills describe a multi-root checkout no chain repo can see, and it is
absent from `MIRROR_SETS`. Do not add it.

## 3. The four chains

```
android   APP > WEB
desktop   APP > EXE > WEB
browser   APP > PWA > WEB
schema    APP > SDB > WEB
```

Read as: changes flow left to right, **never backwards.** That property, more
than any other mechanism, is what prevents an endless propagation loop (A
updates B, B updates A). Every chain terminates at WEB, because WEB is the
public release mirror all the update checkers poll.

`lib/` is **one** source tree serving Android, web, and desktop, splitting by
platform through conditional exports (`local_image_platform{,_io,_web}.dart` and
four more of the same shape). PWA and EXE are *build targets* of that tree, not
forks. Never copy `lib/` into either.

## 4. What each edge carries

| carries | meaning | actual payload |
|---|---|---|
| `claude-tooling` | APP → SDB, EXE, PWA, WEB | `.claude/skills`, `.claude/agents`, `chain/chain.json` (with `self` rewritten), `tools/chain-*.mjs` |
| `generated-schema` | APP → SDB | the schema snapshot regenerated from the Dart DDL, plus `schema/version.json` |
| `app-source` | APP → EXE, PWA · PWA → WEB | an `app-source.json` pinning the source commit the target builds from |
| `schema-docs` | SDB → WEB | WEB's generated schema reference page |
| `release-mirror` | APP, EXE → WEB | releases and assets re-published at WEB, where the in-app updater looks |

Only `claude-tooling` is implemented today. Every other handler in
`tools/chain-propagate.mjs` reports that its payload is not built yet and skips
— deliberately, because a handler that silently succeeded with an empty change
would leave the chain behind while claiming it had not.

## 5. The skills that read this file

| Skill | When |
|---|---|
| `multi-repository-architecture` | "which repo does this belong in?" |
| `chained-supporter` | **before** starting work — what moved in the other repos |
| `chained-updated` | **after** the work lands — push it downstream |

`tools/chain-lib.mjs` is the helper all three share. `node tools/chain-lib.mjs`
prints the resolved chain for whichever repo you are standing in — the same code
answers correctly everywhere because the mirror rewrites `self` per repo.

## 6. Adding a repo or an edge

1. Add an entry to `chain.json` → `repos` (`owns`, `releases`, `versionSource`).
2. Add the edges to `chain.json` → `edges` — **one direction only**, and never
   pointing at APP.
3. Add the repo to `MIRROR_SETS` in `tools/mirror-claude.mjs`, naming the skill
   set it should receive.
4. Run `node tools/mirror-claude.mjs`, then commit every repo it touched.

CI (`.github/workflows/chain-check.yml`) enforces steps 1–3: it fails if
`chain.json` does not parse, if a mirror set names a skill that does not exist,
or if the graph gains a cycle.

## 7. The token propagation needs

A workflow's `GITHUB_TOKEN` is scoped to the repo it runs in and **cannot write
across repos.** The chain uses a single PAT named `CHAIN_TOKEN` (with
`contents: write` and `pull_requests: write` on all six repos), stored as a
secret in each.

If that secret is missing, **fail loudly** — name the secret, the target repo,
the consequence, and the fix. Never skip quietly: a silent skip leaves the chain
behind, which is the one outcome this whole mechanism exists to prevent.
