// Mirrors APP's Claude tooling (.claude/skills, .claude/agents) and the chain
// contract (chain/chain.json) into the four downstream repos.
//
// APP is the ONLY place a chain skill is edited. Every other repo's copy is an
// output — the header this tool stamps into each mirrored SKILL.md says so, so
// nobody edits a downstream copy by accident and loses it on the next mirror.
//
//   node tools/mirror-claude.mjs            write
//   node tools/mirror-claude.mjs --check    verify only, exit 1 on drift (CI)
//   node tools/mirror-claude.mjs --only EXE limit to one repo
//
// Not everything goes everywhere. MIRROR_SETS below is that decision, written
// down once. QuetzaLib-DEV is deliberately absent: it is not in chain.json, and
// its skills describe the multi-root workspace, which no chain repo can see.
import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync, existsSync, rmSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { loadChain, repoRoot, clonePathOf } from './chain-lib.mjs';

const ROOT = repoRoot();
const chain = loadChain(ROOT);

const args = process.argv.slice(2);
const CHECK = args.includes('--check');
const ONLY = (() => { const i = args.indexOf('--only'); return i >= 0 ? args[i + 1] : null; })();

// Which skills/agents each repo gets.
const SHARED = [
  'skills/multi-repository-architecture',
  'skills/chained-supporter',
  'skills/chained-updated',
  'skills/write-docs',
  'agents/chained-supporter.md',
  'agents/chained-updated.md',
];

// APP is the only repo with Dart in it, so every Flutter-shaped skill —
// run-quetzalib, quetzalib-file-arch, quetzalib-l10n-style, version-update,
// build-release-git, ui-researcher, ux-researcher — stays APP-only and is
// absent from every set below. A skill that documents `flutter analyze` in a
// repo with no pubspec.yaml is worse than no skill: it reads as an instruction.
const MIRROR_SETS = {
  SDB: [...SHARED],
  EXE: [...SHARED],
  PWA: [...SHARED],
  WEB: [...SHARED],
};

const STAMP_START = '<!-- mirrored-from-app: do not edit here -->';
const NOTE = `${STAMP_START}
> **Mirrored file — edit this in \`ZYDRAXYL/QuetzaLib-APP\`, not here.**
> \`tools/mirror-claude.mjs\` regenerates it and any local edit is lost on the
> next mirror. The chain contract it belongs to is \`chain/README.md\`.
`;

/** Insert the "don't edit me" note directly after a SKILL.md's frontmatter. */
function stamp(text, srcRel) {
  if (!srcRel.endsWith('.md')) return text;
  if (text.includes(STAMP_START)) return text;          // already stamped
  const m = text.match(/^---\n[\s\S]*?\n---\n/);
  return m ? m[0] + '\n' + NOTE + text.slice(m[0].length) : NOTE + '\n' + text;
}

function walk(dir, base = dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, base, out);
    else out.push(relative(base, p));
  }
  return out;
}

/** Every file this entry contributes, as [srcAbs, relPathUnderDotClaude]. */
function filesFor(entry) {
  const src = join(ROOT, '.claude', entry);
  if (!existsSync(src)) throw new Error(`mirror set names ${entry}, which does not exist in APP/.claude/`);
  if (statSync(src).isDirectory()) return walk(src).map(r => [join(src, r), join(entry, r)]);
  return [[src, entry]];
}

let drift = 0, wrote = 0, checked = 0;
const targets = Object.keys(MIRROR_SETS).filter(k => !ONLY || k === ONLY);

for (const key of targets) {
  const dest = clonePathOf(key, chain, ROOT);
  if (!dest) { console.log(`skip ${key} — not cloned beside this repo`); continue; }

  // 1. the chain contract, with `self` rewritten so chain-lib answers
  //    correctly inside that repo without any per-repo code.
  const localChain = { ...chain, self: key };
  const want = [[join(dest, 'chain', 'chain.json'), JSON.stringify(localChain, null, 2) + '\n']];

  // 2. the tooling itself. The mirrored skills tell the reader to run these by
  //    name, so all three have to travel — a skill that documents a command its
  //    own repo does not have is worse than no skill.
  for (const t of ['chain-lib.mjs', 'chain-survey.mjs', 'chain-propagate.mjs']) {
    want.push([join(dest, 'tools', t), readFileSync(join(ROOT, 'tools', t), 'utf8')]);
  }

  // 3. the per-repo skill/agent set
  for (const entry of MIRROR_SETS[key]) {
    for (const [srcAbs, rel] of filesFor(entry)) {
      // write-docs' .last-sync holds an APP commit SHA. Downstream it resolves
      // to nothing, and docs-diff.sh would rather see a missing marker (which
      // it treats as a full re-scan) than a confidently wrong one.
      if (rel.endsWith('.last-sync')) continue;
      const isText = /\.(md|mjs|js|sh|json|txt)$/.test(rel);
      const body = isText ? stamp(readFileSync(srcAbs, 'utf8'), rel) : readFileSync(srcAbs);
      want.push([join(dest, '.claude', rel), body]);
    }
  }

  for (const [path, body] of want) {
    checked++;
    const cur = existsSync(path) ? readFileSync(path, typeof body === 'string' ? 'utf8' : null) : null;
    const same = cur !== null && (typeof body === 'string' ? cur === body : Buffer.compare(cur, body) === 0);
    if (same) continue;
    if (CHECK) { drift++; console.error(`drift: ${relative(dirname(ROOT), path)}`); continue; }
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, body);
    wrote++;
  }

  // 4. prune mirrored skills this repo should no longer have — a skill removed
  //    from MIRROR_SETS must actually disappear downstream, or it lingers
  //    forever as an unowned copy nobody maintains.
  const skillsDir = join(dest, '.claude', 'skills');
  if (existsSync(skillsDir)) {
    const allowed = new Set(MIRROR_SETS[key].filter(e => e.startsWith('skills/')).map(e => e.slice(7)));
    for (const name of readdirSync(skillsDir)) {
      if (allowed.has(name)) continue;
      if (CHECK) { drift++; console.error(`stale: ${key}/.claude/skills/${name} is not in this repo's mirror set`); }
      else { rmSync(join(skillsDir, name), { recursive: true, force: true }); wrote++; }
    }
  }
}

if (CHECK) {
  if (drift) { console.error(`\n${drift} file(s) out of sync — run: node tools/mirror-claude.mjs`); process.exit(1); }
  console.log(`mirror in sync (${checked} files across ${targets.length} repos)`);
} else {
  console.log(`mirrored ${wrote} file(s) across ${targets.length} repos (${checked} checked)`);
}
