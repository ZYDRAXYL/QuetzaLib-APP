---
name: chained-supporter
description: Survey the other QuetzaLib repos in the chain BEFORE starting work — what moved in APP/SDB/EXE/PWA/WEB since this repo last looked, sorted into what blocks you, what you block, and what is merely sibling news. Bounded to one git call per peer and answers "nothing changed" cheaply. Use at the start of any session in a QuetzaLib chain repo, before planning a change that might already be in flight upstream, after a long gap since the last session, or when asked "มีอะไรเปลี่ยนบ้าง", "repo อื่นอัปเดตอะไร", "check the other repos", "what changed upstream", "chain survey".
---

# chained-supporter — look before you work

In a multi-repo chain the expensive mistake is not a bad change; it is a change
built on a stale assumption about another repo. This skill is the cheap check
that prevents it.

Run it **before** planning work, not after.

```bash
node tools/chain-survey.mjs            # the survey
node tools/chain-survey.mjs --mark     # record what you saw, after the work lands
```

## What it reports

Peers are sorted by their relationship to *this* repo, resolved from
`chain/chain.json` — that ordering is the point of the skill, because a PWA
session should treat an APP move as blocking and an SDB move as trivia:

```
Chain survey (PWA, last surveyed 2026-09-12T18:02Z)
  ↑ APP   MOVED     e4f5a6b (was 73540da)  tag v1.14.0 (was v1.13.0)
  ↓ WEB   unchanged
  · SDB   unchanged
  · EXE   MOVED     9c1d2e3

  → upstream moved: APP. Check for an open chained-update PR before doing this by hand.
```

- `↑` **upstream** — this can block you. An app-source pin left behind is the case that matters.
- `↓` **downstream** — you block them. Anything you land here has to reach these.
- `·` **sibling** — same chain, not on your path. Read it, do not act on it.

In APP the survey is all `↓` and `·`: APP is the root of the graph and nothing
is upstream of it, so the closing line is always "nothing upstream blocks this
work." That is correct output, not a broken survey.

## What to do with each result

| Finding | Action |
|---|---|
| Upstream APP moved and this repo's source pin is behind | Check for an open `chained-update` PR first — do not hand-vendor. If none exists, run `chained-updated` from APP. |
| Upstream APP moved, skills/chain only | `node tools/mirror-claude.mjs --check` in APP; drift means the mirror never ran. |
| A downstream repo has an open `chained-update` PR from you | Finish it before starting new work — a half-propagated change is worse than an unpropagated one. |
| A peer reports `UNKNOWN` | Treat it as unread, never as unchanged. Say which peer and why in your first message. |
| Nothing moved | Say so in one line and get on with the work. |

## How it stays cheap

State lives in `chain/.chain-sync.json`: per peer, the last commit SHA and
release tag this repo saw. The survey is one `git ls-remote` per peer — refs
only, no clone, no API token, and it works the same for the private DEV repo.
The common "nothing moved" answer costs nothing more. It is the same idea as
`write-docs`'s `.last-sync` marker, generalised from one repo to four.

Two failure modes, both non-fatal by design:

- **A recorded SHA no longer resolves** (someone rebased or squashed): treat it
  as a full re-scan and say so, rather than crashing. `write-docs`'s
  `docs-diff.sh` already handles its marker this way — same convention.
- **A peer cannot be read** (no network, no credentials, rate limit): report
  that peer as `unknown`, not as `unchanged`. A survey that silently downgrades
  an unreadable repo to "fine" is worse than no survey.

## Tag namespaces

The survey reads each peer's newest tag **in that peer's own namespace** — `v*`
for APP, `exe-v*` for EXE, `sdb-v*` for SDB. Never compare across namespaces,
and never report "the newest tag" from WEB's release mirror as any one
product's version; the mirror carries all of them.

## When to mark

Run `--mark` **after the work lands**, not when the survey runs — same timing
rule as `write-docs`'s `mark-synced.sh`. Marking early records that you saw a
change you then did not act on.
