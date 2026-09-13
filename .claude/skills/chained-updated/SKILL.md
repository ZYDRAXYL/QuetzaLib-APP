---
name: chained-updated
description: Propagate a landed change to the QuetzaLib repos downstream of it — resolve the affected edges from chain/chain.json, rebuild each edge's payload, and open a labelled pull request on every downstream repo, without being told which repos or refs are involved. Use after editing a chain skill or the contract in APP, after a schema change the SDB snapshot has to follow, after an app change PWA or EXE builds on, or when asked "ส่งต่อให้ repo อื่น", "อัปเดต repo ที่เกี่ยวข้อง", "propagate this", "update downstream", "chained update".
---

# chained-updated — push the change downstream

Every cross-repo dependency in QuetzaLib is an **edge** in `chain/chain.json`.
This skill walks the edges leaving the current repo and makes each downstream
repo current. You never have to name the repos: the contract already knows them.

```bash
node tools/chain-propagate.mjs                # every downstream edge
node tools/chain-propagate.mjs --to EXE       # one target
node tools/chain-propagate.mjs --dry-run      # show what it would do
node tools/chain-propagate.mjs --push         # commit and push the branch too
```

Without `--push` it only stages the payload in each sibling checkout and
reports. That default is deliberate — propagation is easy to trigger by accident
and expensive to undo across four repos.

## The five edge kinds

| carries | from → to | What propagation actually does |
|---|---|---|
| `claude-tooling` | APP → SDB, EXE, PWA, WEB | `node tools/mirror-claude.mjs`, commit the changed mirror |
| `generated-schema` | APP → SDB | rewrite `schema/` from APP's Dart schema, bump `schema/version.json` |
| `app-source` | APP → EXE, PWA · PWA → WEB | bump the commit pin in the target's `app-source.json`, let it rebuild |
| `schema-docs` | SDB → WEB | regenerate WEB's schema reference page |
| `release-mirror` | APP, EXE → WEB | already handled by the release workflow — do not duplicate it |

Only `claude-tooling` is implemented today. The other handlers report plainly
that their payload is not built yet and skip, rather than succeeding with an
empty change — a silent no-op leaves the chain behind, which is the exact
failure this whole mechanism exists to prevent. `release-mirror` is listed so
the contract is complete, but it is **not** this skill's job: the release
workflow mirrors inline as part of publishing, and re-running it here would
create a second, competing publisher.

## Pull request, never a direct push

The downstream repo's CI has to run *before* the artifact lands.

- Branch: the `branch` field in `chain.json` — deterministic, so a re-run
  updates the same branch and the same PR instead of opening a second one.
- Label: `chained-update`. Draft PRs, like every other automated PR here.
- The body states the before/after pin, the artifacts rewritten, and the
  upstream commits since the previous pin.
- Every commit ends with a `Chained-From: <REPO>@<sha>` trailer.

## Three things that keep it from running away

**Direction.** Edges are one-way and `chain.json` is acyclic; propagation only
ever walks `from → to`. APP has no incoming edges at all, so `A → B → A` is not
representable. Validate with `node tools/chain-lib.mjs` in any repo — in APP,
`upstream` must read `—`.

**The trailer check.** GitHub does not re-trigger workflows for events raised by
a workflow's own `GITHUB_TOKEN` — but the chain writes across repos, which needs
a PAT (`CHAIN_TOKEN`), and a PAT **does** re-trigger. So `chain-propagate.mjs`
refuses to run when HEAD already carries a `Chained-From:` trailer. Without that
check the PAT reintroduces exactly the loop the direction rule prevents.

**Path allowlist.** A propagation may only write the paths its edge declares,
plus the pin file. It can never touch a downstream repo's own source, so a human
working in `electron/` can never conflict with the bot.

## When the downstream repo has diverged

- **The propagation branch is bot-owned.** On a re-run it is recreated from the
  target's default branch and the payload re-applied — never rebased, never
  force-pushed onto someone's work. A conflicted PR therefore self-heals on the
  next run.
- **Someone hand-edited a mirrored file.** Overwrite it, and say so in the PR
  body with the diff that was replaced. The file is generated; the edit belongs
  upstream and was already invalid. But it must be *shown*, never silently
  discarded.
- **A mirrored destination no longer exists** (a consumer moved or deleted it):
  the bot cannot guess. Open an issue titled `Chain broken: <from> → <to>`
  naming the missing path, and fail loudly. A consumer that moved a contracted
  file broke the contract; a human repairs one side or the other.
- **A consumer deliberately wants to stay behind.** Honour a `hold` in the pin
  file — skip it with a notice, and keep enforcing the *pinned* version so being
  behind stays safe rather than becoming unchecked.

## Auth

Cross-repo writes need `CHAIN_TOKEN`, a PAT with `contents: write` and
`pull_requests: write` on all six repos — a workflow's own `GITHUB_TOKEN` is
scoped to its own repo and cannot do it. When the secret is absent, fail with

> a loud error naming **the secret**, **the target repo**, **the consequence**,
> and **the fix** — never a silent skip.

Use that standard for every chain error message. A missing token that fails
quietly leaves the chain silently behind.
