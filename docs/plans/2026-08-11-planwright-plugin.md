# Planwright Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish `planwright` — a standalone, project-agnostic Claude Code plugin whose two skills allocate user stories with observable acceptance criteria and turn a spec into a story-grouped implementation plan carrying a Definition of Done.

**Architecture:** A markdown-only plugin. One git repo doubles as marketplace and plugin (`marketplace.json` beside `plugin.json`, plugin `source: "./"`). Two skills under `skills/`, a commented config template under `templates/`, and a dependency-free bash assertion script under `tests/` that every task extends before writing the file it checks. Nothing links against superpowers at runtime; the planning material copied from it is copied once under MIT with attribution.

**Tech Stack:** Markdown, JSON manifests, YAML config template, bash 5, `python3` + PyYAML (test script only), `claude plugin` CLI (validation and install), `gh` CLI (publish).

**Source spec:** [docs/spec/2026-08-10-planwright-design.md](docs/spec/2026-08-10-planwright-design.md) — this plan covers the publishable `planwright` plugin repository.

> **Post-execution note.** This plan has been executed; it is kept as a historical record. The
> shipped skills under `skills/` have since received amendments from a final whole-branch review
> that this plan predates, so the skill text quoted verbatim in Tasks 4–6 below is the **as-planned**
> version, not the as-shipped one. Read `skills/story-backlog/SKILL.md` and
> `skills/story-plans/SKILL.md` directly for current behavior.

## Global Constraints

- Plugin name is `planwright`; marketplace name is `planwright-marketplace`; consuming repos configure it in a file named `.planwright.yml`. These three strings appear in manifests, skill bodies, the template, and the README — they must agree everywhere.
- Repository is `https://github.com/sshah-tripcart/planwright`, public, branch `main`.
- Version is `0.1.0` in `plugin.json`, in `marketplace.json`'s `metadata.version`, and in its `plugins[0].version`. All three match.
- LICENSE is MIT and carries **two** copyright lines: `Copyright (c) 2026 sshah` and `Copyright (c) 2025 Jesse Vincent`.
- `skills/story-plans/SKILL.md` opens with an HTML-comment provenance note naming `obra/superpowers` v6.2.0, MIT, Jesse Vincent, and stating this is a one-time copy rather than a tracked fork.
- **No fork mechanics.** No `upstream` remote, no submodule, no vendored copy of superpowers, and no file in this repo that superpowers is expected to update.
- **Soft dependency in both directions.** Nothing the plugin ships may require, bundle, disable, or modify superpowers. Where a skill mentions `superpowers:subagent-driven-development`, it must read as conditional ("if available") and describe the fallback.
- **Missing config is stated, never silent.** Every skill that reads `.planwright.yml` names the defaults it assumed when a key is absent.
- **An unconfigured Definition-of-Done requirement is recorded as skipped, never dropped.**
- Story IDs are `US-<epic>.<n>` from one global namespace per epic, spanning every backlog file. Never reused, never renumbered.
- No `.planwright.yml` is written into *this* repo — it is a consumer-side file. This repo ships only `templates/planwright.yml`.
- `bash tests/structure-test.sh` must exit 0 at the end of every task from Task 1 onward.

## File Structure

| File | Responsibility |
|------|----------------|
| `.claude-plugin/plugin.json` | Plugin manifest — identity, version, author, license, keywords |
| `.claude-plugin/marketplace.json` | Marketplace manifest — one plugin entry with `source: "./"` |
| `skills/story-backlog/SKILL.md` | Allocate a story (ID, routing, format, observable ACs) and close one out (markers, evidence note) |
| `skills/story-plans/SKILL.md` | Spec + stories → story-grouped plan. Copied planning material plus Story Map, task tags, Definition of Done, extended self-review |
| `templates/planwright.yml` | Commented starter config — the schema both skills read, in one place |
| `tests/structure-test.sh` | Dependency-free structural assertions; grown one section per task |
| `LICENSE` | MIT, both copyright lines |
| `README.md` | Install, configure, the two skills, the workflow, attribution |
| `.gitignore` | Minimal ignore list |

Two files carry the whole product: the skills. Everything else exists to make them installable, configurable, and legally clean. The test script is deliberately one file with no framework — the artifact under test is markdown, and the assertions are about structure and required strings, not behaviour.

---

## Task 1: Repository skeleton, manifests, and the test harness

**Files:**
- Create: `.gitignore`
- Create: `tests/structure-test.sh`
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`

**Interfaces:**
- Produces: the plugin name `planwright`, marketplace name `planwright-marketplace`, and version `0.1.0` — every later task reuses these exact strings.
- Produces: `tests/structure-test.sh` with helper functions `ok`, `fail`, `has_file`, `has_text`, `lacks_text`, and a `fails` counter. Later tasks append sections that call these helpers and must not redefine them.

- [ ] **Step 1: Initialise the repository**

```bash
cd /opt/skills/planwright
git init -b main
git config user.email "<your git email>"
git config user.name "sshah"
```

- [ ] **Step 2: Write `.gitignore`**

```gitignore
.DS_Store
evals/results/
node_modules/
```

- [ ] **Step 3: Write the failing test**

Create `tests/structure-test.sh`:

```bash
#!/usr/bin/env bash
# Structural assertions for the planwright plugin.
#
# No framework by design: the artifact under test is markdown and JSON, so the
# assertions are about files existing and containing required strings. Each
# check prints one line; the script exits 1 if any check failed.
set -uo pipefail
cd "$(dirname "$0")/.."

fails=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

has_file() {
  if [ -f "$1" ]; then ok "exists: $1"; else fail "missing: $1"; fi
}
has_text() {
  if [ -f "$1" ] && grep -qF -- "$2" "$1"; then ok "$1 has: $2"
  else fail "$1 lacks: $2"; fi
}
lacks_text() {
  if [ -f "$1" ] && grep -qF -- "$2" "$1"; then fail "$1 must not contain: $2"
  else ok "$1 clean of: $2"; fi
}

echo "== manifests =="
has_file .claude-plugin/plugin.json
has_file .claude-plugin/marketplace.json
has_text .claude-plugin/plugin.json '"name": "planwright"'
has_text .claude-plugin/plugin.json '"version": "0.1.0"'
has_text .claude-plugin/plugin.json '"license": "MIT"'
has_text .claude-plugin/marketplace.json '"name": "planwright-marketplace"'
has_text .claude-plugin/marketplace.json '"source": "./"'

echo
if [ "$fails" -eq 0 ]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
exit $((fails > 0))
```

Then make it executable:

```bash
chmod +x tests/structure-test.sh
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `bash tests/structure-test.sh`
Expected: FAIL — `missing: .claude-plugin/plugin.json`, `missing: .claude-plugin/marketplace.json`, and five `lacks:` lines; final line `7 check(s) failed`; exit status 1.

- [ ] **Step 5: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "planwright",
  "description": "A user-story layer above granular planning. Allocate US-<epic>.<n> stories with observable acceptance criteria, then turn a spec into a story-grouped implementation plan where every task is tagged to a criterion and every story carries a Definition of Done.",
  "version": "0.1.0",
  "author": {
    "name": "sshah"
  },
  "homepage": "https://github.com/sshah-tripcart/planwright",
  "repository": "https://github.com/sshah-tripcart/planwright",
  "license": "MIT",
  "keywords": [
    "skills",
    "planning",
    "user-stories",
    "backlog",
    "acceptance-criteria",
    "definition-of-done",
    "tdd"
  ]
}
```

- [ ] **Step 6: Write `.claude-plugin/marketplace.json`**

The plugin lives at the marketplace root, so its `source` is `"./"` — the documented pattern for a plugin in the same repository as its marketplace.

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "planwright-marketplace",
  "owner": {
    "name": "sshah"
  },
  "metadata": {
    "description": "Story-first planning skills for Claude Code.",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "planwright",
      "source": "./",
      "description": "Allocate user stories with observable acceptance criteria, then plan against them: story-grouped tasks, per-task AC tags, and a Definition of Done per story.",
      "version": "0.1.0",
      "license": "MIT",
      "category": "workflow",
      "keywords": [
        "planning",
        "user-stories",
        "acceptance-criteria",
        "definition-of-done"
      ]
    }
  ]
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `bash tests/structure-test.sh`
Expected: PASS — seven `ok` lines and `all checks passed`; exit status 0.

- [ ] **Step 8: Validate both manifests with the Claude Code CLI**

```bash
claude plugin validate .claude-plugin/plugin.json --strict
claude plugin validate .claude-plugin/marketplace.json --strict
```

Expected: `✔ Validation passed` from each, with no warnings. `--strict` turns warnings into failures, so a passing run here means the manifests carry no unrecognized fields and no missing metadata.

- [ ] **Step 9: Commit**

```bash
git add .gitignore tests/structure-test.sh .claude-plugin docs/
git commit -m "feat: plugin and marketplace manifests with structural test harness"
```

---

## Task 2: LICENSE with dual copyright

The copied planning material in Task 5 is only clean if the license carrying it exists first. This task is the legal precondition for that copy, which is why it comes before any skill is written.

**Files:**
- Create: `LICENSE`
- Modify: `tests/structure-test.sh` (append a `== license ==` section)

**Interfaces:**
- Produces: the exact strings `Copyright (c) 2026 sshah` and `Copyright (c) 2025 Jesse Vincent`. Task 5's provenance comment and Task 6's README attribution section both refer back to this file.

- [ ] **Step 1: Write the failing test**

Append to `tests/structure-test.sh`, immediately **before** the final `echo` / summary block:

```bash
echo "== license =="
has_file LICENSE
has_text LICENSE 'MIT License'
has_text LICENSE 'Copyright (c) 2026 sshah'
has_text LICENSE 'Copyright (c) 2025 Jesse Vincent'
has_text LICENSE 'obra/superpowers'
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/structure-test.sh`
Expected: FAIL — `missing: LICENSE` plus four `lacks:` lines; `5 check(s) failed`; exit status 1.

- [ ] **Step 3: Write `LICENSE`**

Both copyright lines sit above one MIT grant. That is the correct shape for a single work containing material from two authors under the same licence — not two separate licence blocks.

```
MIT License

Copyright (c) 2026 sshah
Copyright (c) 2025 Jesse Vincent

Portions of skills/story-plans/SKILL.md are adapted from the "writing-plans"
skill in obra/superpowers v6.2.0 (https://github.com/obra/superpowers),
Copyright (c) 2025 Jesse Vincent, used under the MIT License. That material was
copied once with attribution; this repository is not a fork of, and tracks no
branch of, obra/superpowers.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/structure-test.sh`
Expected: PASS — `all checks passed`; exit status 0.

- [ ] **Step 5: Commit**

```bash
git add LICENSE tests/structure-test.sh
git commit -m "docs: MIT license with dual copyright and superpowers attribution"
```

---

## Task 3: The config template

`templates/planwright.yml` is the single written definition of the config schema. Both skills read keys from it, so it lands before either of them — a skill cannot document a key that has no canonical spelling.

**Files:**
- Create: `templates/planwright.yml`
- Modify: `tests/structure-test.sh` (append a `== config template ==` section)

**Interfaces:**
- Produces: the key paths `backlog.epic_path`, `backlog.fallback`, `specs`, `plans`, `personas`, `epics`, `layers`, `definition_of_done.unit.command`, `definition_of_done.integration.command`, `definition_of_done.integration.location`, `definition_of_done.smoke.command`, `definition_of_done.smoke.file`, `definition_of_done.api_docs.file`, `definition_of_done.security.surfaces`, `definition_of_done.security.command`, `definition_of_done.backlog_status`. Tasks 4 and 5 reference these spellings verbatim.
- Produces: the seven surface names `tenant-isolation`, `authorization`, `user-input`, `file-handling`, `secrets`, `outbound-fetch`, `dependency`.

- [ ] **Step 1: Write the failing test**

Append to `tests/structure-test.sh`, before the summary block. The check parses the YAML and walks every documented key path, so a typo in a key name fails the build rather than surfacing later as a silently-missing config value.

```bash
echo "== config template =="
has_file templates/planwright.yml
config_report=$(python3 - <<'PY' 2>&1
import yaml
required = [
    "backlog.epic_path", "backlog.fallback", "specs", "plans",
    "personas", "epics", "layers",
    "definition_of_done.unit.command",
    "definition_of_done.integration.command",
    "definition_of_done.integration.location",
    "definition_of_done.smoke.command",
    "definition_of_done.smoke.file",
    "definition_of_done.api_docs.file",
    "definition_of_done.security.surfaces",
    "definition_of_done.security.command",
    "definition_of_done.backlog_status",
]
try:
    doc = yaml.safe_load(open("templates/planwright.yml"))
except Exception as exc:
    print("UNPARSEABLE %s" % exc)
    raise SystemExit(0)
missing = []
for path in required:
    node = doc
    for part in path.split("."):
        if isinstance(node, dict) and part in node:
            node = node[part]
        else:
            missing.append(path)
            break
print("MISSING " + " ".join(missing) if missing else "OK")
PY
)
if [ "$config_report" = "OK" ]; then
  ok "templates/planwright.yml parses and has every documented key"
else
  fail "templates/planwright.yml: $config_report"
fi

for surface in tenant-isolation authorization user-input file-handling secrets outbound-fetch dependency; do
  has_text templates/planwright.yml "$surface"
done
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/structure-test.sh`
Expected: FAIL — `missing: templates/planwright.yml`, then `templates/planwright.yml: UNPARSEABLE [Errno 2] No such file or directory: 'templates/planwright.yml'`, then seven `lacks:` lines; `9 check(s) failed`; exit status 1.

- [ ] **Step 3: Write `templates/planwright.yml`**

Every value below is a working example, not a placeholder — a reader copies the file and edits, rather than decoding what a token means.

```yaml
# .planwright.yml — planwright project configuration.
#
# Copy this file to the root of your repository as `.planwright.yml` and edit it.
# Every key is optional. Whatever you leave out, the skills fall back to the
# default noted beside it AND state the assumption in the plan they write, so an
# omission is always visible in the output rather than silently applied.

# ---------------------------------------------------------------------------
# Where documents live
# ---------------------------------------------------------------------------
backlog:
  # Per-epic backlog file. {slug} is replaced with the epic's slug from the
  # `epics` table below. Used only when that epic's folder already exists.
  # Default: docs/epic/{slug}/user-stories.md
  epic_path: docs/epic/{slug}/user-stories.md

  # Stories whose epic has no folder yet land here.
  # Default: docs/user-stories.md
  fallback: docs/user-stories.md

# Where design specs are written. Default: docs/specs/
specs: docs/specs/

# Where implementation plans are written. Default: docs/plans/
plans: docs/plans/

# ---------------------------------------------------------------------------
# Vocabulary
# ---------------------------------------------------------------------------
# The complete set of actors a story may be written for. A story whose persona
# is not on this list is a defect: add the persona here first, deliberately.
# No default — with this key absent, the skill asks rather than inventing one.
personas: [Recruiter, Candidate, Agent, Employer, TenantAdmin, PlatformAdmin]

# Epic number -> theme and folder slug. Story IDs are US-<epic number>.<n>, so
# the key here supplies the `8` in US-8.22. Slugs are `e<n>-<theme>` in
# kebab-case and fill the {slug} above.
# No default — with this key absent, the skill asks which epic a story belongs to.
epics:
  E0: { theme: Platform foundation, slug: e0-platform }
  E8: { theme: Comms & notifications, slug: e8-comms }

# Architectural layers. A story touching two or more of these fires the
# integration-test requirement.
# Default: the list shown here.
layers: [http, service, data-access, worker, external-adapter, authorization]

# ---------------------------------------------------------------------------
# Definition of Done
# ---------------------------------------------------------------------------
# Any requirement left unconfigured is written into the plan as "not configured
# — skipped". It is never silently dropped.
definition_of_done:
  # 1. Unit tests — fires on any task with branching logic, a pure function,
  #    a validator, or a projection.
  unit:
    command: pnpm test

  # 2. Integration tests — fires when a story touches two or more `layers`.
  integration:
    command: pnpm --filter @your-scope/api test
    location: apps/api/test/

  # 3. Smoke run — fires on a new/changed/removed HTTP route, request or
  #    response shape, or auth gate.
  smoke:
    command: pnpm smoke
    file: scripts/smoke.sh

  # 4. API docs — same trigger as the smoke run.
  api_docs:
    file: docs/api.md

  # 5. Security check — evaluated on EVERY story, and the outcome recorded
  #    either way, including "no surface touched".
  security:
    # Surfaces this project can actually expose. Remove any that cannot apply;
    # a surface listed here is one the skill will check a story against.
    surfaces: [tenant-isolation, authorization, user-input, file-handling,
               secrets, outbound-fetch, dependency]
    # Optional scanner or review command, run IN ADDITION to the surface checks
    # — never instead of them. Leave null if you have none.
    command: null

  # 6. Backlog status — flipping the story's marker and appending an evidence
  #    note. Always applies.
  backlog_status: true
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/structure-test.sh`
Expected: PASS — including `ok    templates/planwright.yml parses and has every documented key`; `all checks passed`; exit status 0.

- [ ] **Step 5: Commit**

```bash
git add templates/planwright.yml tests/structure-test.sh
git commit -m "feat: commented .planwright.yml starter template"
```

---

## Task 4: The `story-backlog` skill

**Files:**
- Create: `skills/story-backlog/SKILL.md`
- Modify: `tests/structure-test.sh` (append a `== story-backlog skill ==` section)

**Interfaces:**
- Consumes: the config key paths from Task 3 — `backlog.epic_path`, `backlog.fallback`, `personas`, `epics`.
- Produces: the story wire format `**US-<epic>.<n>** · \`<M|S|C>\` · <marker> · As a **<Persona>**, I want …, so that …` with `- <marker> AC<k>: …` bullets, and the marker vocabulary `⬜ Not started` / `🟡 Partial` / `✅ Done`. Task 5's skill copies this format verbatim into plans, and Task 6's README documents it.

- [ ] **Step 1: Write the failing test**

Append to `tests/structure-test.sh`, before the summary block:

```bash
echo "== story-backlog skill =="
has_file skills/story-backlog/SKILL.md
has_text skills/story-backlog/SKILL.md 'name: story-backlog'
has_text skills/story-backlog/SKILL.md 'US-<epic>.<n>'
has_text skills/story-backlog/SKILL.md '.planwright.yml'
has_text skills/story-backlog/SKILL.md '⬜ Not started'
has_text skills/story-backlog/SKILL.md '🟡 Partial'
has_text skills/story-backlog/SKILL.md '✅ Done'
has_text skills/story-backlog/SKILL.md 'Promoting an epic'
has_text skills/story-backlog/SKILL.md 'evidence note'
has_text skills/story-backlog/SKILL.md 'docs/user-stories.md'
has_text skills/story-backlog/SKILL.md '## Stories'
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/structure-test.sh`
Expected: FAIL — `missing: skills/story-backlog/SKILL.md` plus ten `lacks:` lines; `11 check(s) failed`; exit status 1.

- [ ] **Step 3: Write `skills/story-backlog/SKILL.md`**

````markdown
---
name: story-backlog
description: Use when allocating a user story before a spec is written, or closing one out after implementation - assigns US-<epic>.<n> IDs from a global namespace, writes observable numbered acceptance criteria, routes the story to the right backlog file, and flips status markers with an evidence note
---

# Story Backlog

Allocate and maintain user stories in a markdown backlog. The backlog is the
source of truth: a spec restates a story, a plan copies it verbatim, and a task
tag points back at one of its acceptance criteria. When the backlog and a
downstream document disagree, the backlog wins.

**Announce at start:** "I'm using the story-backlog skill to allocate this story."
(or "…to close out this story.")

## Two modes

| Mode | When | Produces |
|------|------|----------|
| **Allocate** | Before the spec is written, once you know what the change is for | A story with a globally-unique ID and numbered ACs, in the routed backlog file |
| **Close out** | After the implementation is verified | Flipped status markers and an evidence note on the story and each AC |

## Read the config first

Read `.planwright.yml` from the repository root. Where a key is absent, use the
default **and say which defaults you assumed** in your first message.

| Key | Used for | Default when absent |
|-----|----------|---------------------|
| `backlog.epic_path` | Per-epic file; `{slug}` is substituted | `docs/epic/{slug}/user-stories.md` |
| `backlog.fallback` | File for epics with no folder yet | `docs/user-stories.md` |
| `personas` | The allowed set of actors | none — ask the user, never invent one |
| `epics` | Epic number → theme and slug | none — ask the user which epic this belongs to |

If there is no `.planwright.yml`, say so plainly — "no `.planwright.yml`; using
`docs/user-stories.md`" — and continue. A missing config is a stated assumption,
never a silent one.

## Allocate

- [ ] **1. Choose the epic.** Match the change to an entry in `epics`. If nothing
  fits, ask whether to add an epic rather than forcing a bad fit.

- [ ] **2. Find the next free `n`.** IDs come from one global namespace per epic,
  spanning **every** backlog file — not just the one you are about to write.
  Scan all of them, substituting the epic number for `8`:

  ```bash
  grep -rhoE 'US-8\.[0-9]+' --include='*.md' --exclude-dir=.git . | sort -t. -k2 -n | tail -1
  ```

  The next `n` is one past the highest hit. IDs are never reused and never
  renumbered, so a gap left by a deleted story stays a gap.

  The scan covers the whole repository rather than a fixed directory, because
  `backlog.epic_path` and `backlog.fallback` can point anywhere and a narrower
  scan would silently miss a file and reissue a live ID. It also matches IDs
  restated in specs and plans; that is harmless, because those are copies and
  you only need the highest.

- [ ] **3. Route the file.** Compute the epic's path from `backlog.epic_path`
  with `{slug}` replaced. If that **folder already exists**, the story goes
  there. Otherwise it goes in `backlog.fallback`. Do not create the folder to
  make the first branch true — see *Promoting an epic*.

- [ ] **4. Write the story** in the house format below, appended after the last
  story in the target file.

- [ ] **5. Verify the write.** Re-read the lines you added and confirm the ID is
  unique, the persona is one from `personas`, every AC is numbered, and every AC
  is observable:

  ```bash
  grep -rn 'US-8.22' --include='*.md' --exclude-dir=.git .   # expect one hit: the line you just wrote
  ```

## The story format

```markdown
**US-8.22** · `S` · ⬜ Not started · As a **Recruiter**, I want to reply to a specific message in a
thread, so that the contact can see which message I'm answering.
- ⬜ AC1: A message sent as a reply renders a quoted block above its body in the inbox thread.
- ⬜ AC2: The contact's WhatsApp client shows the message as a native quote of the original.
```

- **ID** — `US-<epic>.<n>`, bold.
- **Priority** — `` `M` ``, `` `S` ``, or `` `C` `` (must / should / could have).
- **Status** — starts `⬜ Not started`; becomes `🟡 Partial` or `✅ Done` at
  close-out.
- **Statement** — `As a **<persona>**, I want <capability>, so that <benefit>.`
  The persona is bold and comes from `personas`.
- **Acceptance criteria** — one bullet each, numbered `AC1`, `AC2`, …, each
  carrying its own `⬜` marker.

### What makes a story a story

**It describes user-visible value.** Enabling work nobody can observe is not a
story — it is a task belonging to one. A migration, a shared type, a refactor:
each lives under the story it serves.

### What makes an AC an AC

**An AC is decidable by looking at the running system**, never by reading code.

| Not an AC | An AC |
|-----------|-------|
| The `replyTo` column is nullable | A reply renders a quoted block above its body |
| A service method returns the parent message | The contact's client shows the message as a native quote |
| The handler is covered by tests | Replying to a deleted message shows "original unavailable" |

Every story has **at least one** AC. If you cannot write an observable one, what
you have is a task — fold it into a story that has one.

### Leave old stories alone

Bullets already written as `- AC:` without a number stay exactly as they are.
Number ACs only in stories this skill writes or edits. No retrofit, no
renumbering, no reformatting in passing.

## Restating the story in the spec

Stories are allocated **before** the spec is written, so at allocation time there
is usually no spec to edit. Finish by emitting the block the spec's `## Stories`
section needs, ready to drop in:

```markdown
## Stories

**US-8.22** — As a **Recruiter**, I want to reply to a specific message in a thread, so that the
contact can see which message I'm answering.
- **AC1** — A message sent as a reply renders a quoted block above its body in the inbox thread.
- **AC2** — The contact's WhatsApp client shows the message as a native quote of the original.
```

If the spec already exists, write the block into it under `## Stories`, creating
that section if it is absent. The restatement carries the ID, statement, and
numbered ACs so the spec reads standalone; it drops the priority and status
markers, which only the backlog tracks.

**The backlog stays canonical.** If the spec and the backlog disagree, the
backlog is right and the spec is stale.

## Promoting an epic

Epic folders are created deliberately, never as a side effect of allocating a
story. To promote an epic out of the fallback file:

- [ ] Create the folder named by the epic's `slug`.
- [ ] Move that epic's stories out of `backlog.fallback` into the new
  `user-stories.md`, unchanged.
- [ ] Leave a pointer line where they were:

  ```markdown
  > E8 stories moved to [docs/epic/e8-comms/user-stories.md](epic/e8-comms/user-stories.md).
  ```

The folder shape exists so epic-scoped notes and diagrams can sit beside the
stories.

## Close out

Run this after the implementation is verified — not when the code is merely
written.

- [ ] **1. Check each AC against the running system.** An AC you cannot
  demonstrate is not done, whatever the code says.

- [ ] **2. Flip the markers.** Each satisfied AC's `⬜` becomes `✅`. The story's
  marker becomes `✅ Done` when every AC is satisfied, `🟡 Partial` otherwise.

- [ ] **3. Append an evidence note** to the story line — what proved it, in one
  parenthetical:

  ```markdown
  **US-8.22** · `S` · ✅ Done · As a **Recruiter**, I want to reply to a specific message in a
  thread, so that the contact can see which message I'm answering. *(2 unit + 1 integration + 1
  smoke assertion; verified live in the inbox.)*
  - ✅ AC1: A message sent as a reply renders a quoted block above its body in the inbox thread.
  - ✅ AC2: The contact's WhatsApp client shows the message as a native quote of the original.
  ```

  `✅ Done` with no evidence note is an incomplete close-out. The note names
  what was run, not merely that something was.

- [ ] **4. Leave unsatisfied ACs at `⬜`** and say in your reply which ones and
  why. Never flip a marker you did not verify.
````

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/structure-test.sh`
Expected: PASS — eleven new `ok` lines; `all checks passed`; exit status 0.

- [ ] **Step 5: Commit**

```bash
git add skills/story-backlog tests/structure-test.sh
git commit -m "feat: story-backlog skill for allocating and closing out stories"
```

---

## Task 5: The `story-plans` skill

This is the largest file in the repo and the one carrying copied material. Its provenance comment is not decoration — it is the condition under which the copy is licensed.

**Files:**
- Create: `skills/story-plans/SKILL.md`
- Modify: `tests/structure-test.sh` (append a `== story-plans skill ==` section)

**Interfaces:**
- Consumes: the config key paths from Task 3, and the story wire format from Task 4.
- Produces: the task tag syntax `` `[US-8.22·AC1]` `` (middle dot `·` between story and AC, comma-separated ACs), the `## Story Map` table shape, and the close-out block ordering. Task 6's README documents all three.

- [ ] **Step 1: Write the failing test**

Append to `tests/structure-test.sh`, before the summary block:

```bash
echo "== story-plans skill =="
has_file skills/story-plans/SKILL.md
has_text skills/story-plans/SKILL.md 'name: story-plans'
has_text skills/story-plans/SKILL.md 'obra/superpowers'
has_text skills/story-plans/SKILL.md 'Jesse Vincent'
has_text skills/story-plans/SKILL.md 'not a tracked fork'
has_text skills/story-plans/SKILL.md 'Story Map'
has_text skills/story-plans/SKILL.md '[US-8.22·AC1]'
has_text skills/story-plans/SKILL.md 'No Placeholders'
has_text skills/story-plans/SKILL.md 'Definition of Done'
has_text skills/story-plans/SKILL.md 'no surface touched'
has_text skills/story-plans/SKILL.md 'not configured'
has_text skills/story-plans/SKILL.md 'Story coverage'
has_text skills/story-plans/SKILL.md 'subagent-driven-development'
has_text skills/story-plans/SKILL.md 'is available'
for surface in tenant-isolation authorization user-input file-handling secrets outbound-fetch dependency; do
  has_text skills/story-plans/SKILL.md "$surface"
done
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/structure-test.sh`
Expected: FAIL — `missing: skills/story-plans/SKILL.md` plus twenty `lacks:` lines; `21 check(s) failed`; exit status 1.

- [ ] **Step 3: Write `skills/story-plans/SKILL.md`**

`````markdown
---
name: story-plans
description: Use when turning a spec and its allocated user stories into an implementation plan - produces a story-grouped plan with a Story Map, a [US-<epic>.<n>·AC<k>] tag on every task, and a Definition of Done close-out block per story
---

<!--
  Provenance. The Overview, Scope Check, File Structure, Task Right-Sizing,
  Bite-Sized Task Granularity, Task Structure, No Placeholders, and the first
  three Self-Review checks in this file are adapted from the `writing-plans`
  skill in obra/superpowers v6.2.0 (https://github.com/obra/superpowers),
  MIT licensed, Copyright (c) 2025 Jesse Vincent. Copied once with attribution;
  this file is not a tracked fork and no upstream merge is expected. See LICENSE.
-->

# Story Plans

Turn a spec and its allocated stories into an implementation plan where every
task is traceable to a user-visible outcome, and verification is planned into the
work rather than remembered at the end.

**Announce at start:** "I'm using the story-plans skill to create the implementation plan."

Write plans assuming the engineer has zero context for this codebase and
questionable taste. Document everything they need to know: which files to touch
for each task, the code, the tests, the docs they might need to check, how to
test it. Give them the whole plan as bite-sized tasks. Assume a skilled developer
who knows almost nothing about this toolset or problem domain, and who does not
know good test design well. DRY. YAGNI. TDD. Frequent commits.

**Prerequisite:** the stories this plan implements are already allocated in the
backlog. If they are not, use the `story-backlog` skill first — a plan cannot
copy criteria that do not exist yet.

Read the story text from the **backlog file**, not from the spec's `## Stories`
restatement. The restatement exists so the spec reads standalone, and it can go
stale. If the two disagree, use the backlog and say so in your reply.

## Read the config first

Read `.planwright.yml` from the repository root. Where a key is absent, use the
default **and record the assumption in the plan itself**, under Global
Constraints.

| Key | Used for | Default when absent |
|-----|----------|---------------------|
| `plans` | Where this plan is written | `docs/plans/` |
| `specs` | Where the source spec was found | `docs/specs/` |
| `backlog.epic_path`, `backlog.fallback` | Where story text is read from | `docs/epic/{slug}/user-stories.md`, `docs/user-stories.md` |
| `layers` | The integration-test trigger | `[http, service, data-access, worker, external-adapter, authorization]` |
| `definition_of_done.*` | Close-out step content | each unconfigured requirement is **recorded as skipped**, never dropped |

A requirement with no configured command is written into the plan as
`smoke: not configured in .planwright.yml — skipped`. A reader must never have to
wonder whether a missing step was considered and rejected, or simply forgotten.

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken
into sub-project specs during design. If it was not, suggest splitting it into
separate plans — one per subsystem. Each plan should produce working, testable
software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what
each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file
  should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are
  more reliable when files are focused. Prefer smaller, focused files.
- Files that change together should live together. Split by responsibility, not
  by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large
  files, do not unilaterally restructure — but if a file you are modifying has
  grown unwieldy, including a split in the plan is reasonable.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a fresh
reviewer's gate. When drawing task boundaries: fold setup, configuration,
scaffolding, and documentation steps into the task whose deliverable needs them;
split only where a reviewer could meaningfully reject one task while approving
its neighbor. Each task ends with an independently testable deliverable.

## Bite-Sized Task Granularity

**Each step is one action (2–5 minutes):**

- "Write the failing test" — step
- "Run it to make sure it fails" — step
- "Implement the minimal code to make the test pass" — step
- "Run the tests and make sure they pass" — step
- "Commit" — step

## Plan document header

Every plan starts with this header:

````markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** implement this plan task-by-task. If
> `superpowers:subagent-driven-development` is available, use it — a fresh
> subagent per task, with review between tasks. Otherwise execute the tasks in
> order, reviewing between each. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about the approach]

**Tech Stack:** [Key technologies/libraries]

**Stories:** [US-8.22, US-8.23 — and the backlog file they were read from]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact values
copied verbatim from the spec. Every task's requirements implicitly include this
section.]

[Then any `.planwright.yml` default that was assumed rather than configured, one
line each: "no `specs` key; assumed `docs/specs/`".]

---
````

## Story Map and story grouping

After Global Constraints and the File Structure table, tasks are **grouped under
their story** rather than listed flat, and a Story Map indexes them:

````markdown
## Story Map

| Story | ACs | Tasks |
|-------|-----|-------|
| US-8.22 — Agent replies with a quote | AC1, AC2 | 1, 2, 5, 7 |
| US-8.23 — Recruiter sees reply context on mobile | AC1 | 6, 7 |

---

## US-8.22 — Agent replies with a quote

As a **Recruiter**, I want to reply to a specific message in a thread, so that
the contact can see which message I'm answering.

**Acceptance criteria** (verbatim from `docs/epic/e8-comms/user-stories.md`)
- **AC1** — A message sent as a reply renders a quoted block above its body in the inbox thread.
- **AC2** — The contact's WhatsApp client shows the message as a native quote of the original.

### Task 1: Schema — two nullable reply columns  `[US-8.22·AC1]`

**Files:**
- Modify: `apps/api/prisma/schema.prisma`

**Interfaces:**
- Produces: `Message.replyToExternalId: string | null`
````

Four rules make this layer load-bearing rather than decorative:

1. **Every task heading carries a story tag** — `` `[US-8.22·AC1]` ``, or
   `` `[US-8.22·AC1,AC2]` `` when it serves several criteria of its story. A
   task with no tag is a plan defect.
2. **Story statement and AC text are copied verbatim** from the backlog, and the
   story heading names the file they came from. Word for word. If the backlog
   later changes, the plan is updated to match — the backlog wins.
3. **One task, one home.** Groundwork serving several stories (a migration, a
   shared type) goes under the **earliest** story that requires it. The Story
   Map's Tasks column may list that task under more than one story — the column
   is a cross-reference, the heading is the owner.
4. **Each story's final task ends with an AC-verification step**, distinct from
   its "run the tests" step, demonstrating every AC of that story.

The text is copied rather than linked because the executing subagent cannot read
the backlog. If the acceptance criteria live solely upstream, it cannot read the
criterion it is supposed to satisfy.

Two scopes are in play, and they differ. A subagent handed the whole plan can see
the story heading above its task; a subagent handed only its own task block
cannot, and executing a plan by extracting one task at a time is common. So the
rule is: **a tagged task must be executable from its own block.** Either the
story heading travels with the task, or the AC text its tag names is restated
inside the task. Say in the plan header which of the two your execution setup
provides, so a reader knows whether the story headings are load-bearing.

## Task structure

````markdown
### Task N: [Component Name]  `[US-8.22·AC1]`

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter and
  return types. A task's implementer sees only their own task; this block is how
  they learn the names and types neighboring tasks use.]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan
failures** — never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without the actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of
  order)
- Steps that describe what to do without showing how (code blocks required for
  code steps)
- References to types, functions, or methods not defined in any task

## Definition of Done

Six requirements. Each has a **trigger** you evaluate mechanically, **per story
and not per task**. They are written as triggers rather than "where applicable"
because No Placeholders forbids a vague step: you must be able to decide, without
judgement calls, whether each one fires.

Key names in this section are relative to `definition_of_done` in
`.planwright.yml`: `smoke.file` means `definition_of_done.smoke.file`.

| # | Requirement | Fires when the story… | Step content |
|---|-------------|-----------------------|--------------|
| 1 | **Unit tests** | …contains any task with branching logic, a pure function, a validator, or a projection. | Native to the TDD cycle (write failing test → implement → pass). The self-review confirms every logic-bearing task has one. |
| 2 | **Integration tests** | …touches two or more of the configured `layers`. | A test at `integration.location` exercising the real boundary, run with `integration.command`. |
| 3 | **Smoke run** | …adds, changes, or removes an HTTP route, a request/response shape, or an auth/permission gate. | Extend `smoke.file` with an assertion for the new behaviour, run `smoke.command`, and record the expected pass count. |
| 4 | **API docs** | Same trigger as #3. | Update `api_docs.file` — the endpoint's method, path, auth/permission key, request body, success response. |
| 5 | **Security check** | …touches any configured `security.surfaces`. **Evaluated on every story; the outcome is recorded either way.** | The specific checks for the surfaces touched, each naming its file and expected state. Never the words "review for security". |
| 6 | **Backlog status** | Always. | Flip the story's marker and each AC's marker in the backlog, appending an evidence note — `*(3 unit + 1 smoke assertion; verified live.)*`. |

Two rules keep this from becoming ceremony:

**Triggers are evaluated per story.** A story that only changes a UI component
fires none of #2–#4 — only #5, which always applies — and its plan must not carry
empty close-out steps for the rest.

**Every firing trigger becomes a real step with real content.** An
integration-test step contains the test code. A smoke step contains the assertion
and the command. A docs step names the exact section and the lines to add. "Add
tests" and "update docs" are plan defects.

And a requirement with no configured command is **recorded as skipped, never
dropped**: write `smoke: not configured in .planwright.yml — skipped`. A project
without a smoke suite should see that line, not an unexplained absence.

### Security surfaces

A story fires requirement #5 when it touches any surface listed in
`security.surfaces`. Surfaces are configured, not guessed.

| Surface | Fires on | The step must name |
|---------|----------|--------------------|
| `tenant-isolation` | A new table, or a new query path to an existing one | The isolation mechanism this project uses and the file declaring it, plus a test that reads across tenants and is expected to find nothing |
| `authorization` | A new or changed route, permission key, or role check | The permission key the route declares, the file where the gate is enforced, and an assertion covering the denied path |
| `user-input` | User-supplied data reaching storage, a query, a path, or a rendered view | The validation or sanitisation layer the field passes through, and the absence of raw query interpolation or unescaped rendering |
| `file-handling` | Upload, download, or serving of files | The allowlist entry covering the new type, the size cap, and that the stored path is not user-controlled |
| `secrets` | Credentials, tokens, or crypto | That the value is not logged, is absent from every response projection, and is read from the environment with a boot-time requirement |
| `outbound-fetch` | Fetching a user-supplied URL, or adding a webhook | The allowlist the URL is validated against, or the signature the webhook verifies |
| `dependency` | A new runtime dependency | Why it is needed, and the file where it is added |

**The evaluation is always recorded, including the negative.** When no surface is
touched, the close-out carries one line saying so with the reason —
`security: no surface touched (UI-only change)`. This is the one requirement
whose negative result is written down, because a missed security surface costs
more than a missed smoke assertion, and silence cannot be distinguished from
nobody having looked.

Where `security.command` is configured, the step runs it **in addition to** the
surface checks. It never replaces them.

### The close-out block

Each story's **final task** ends with a close-out block: the AC-verification step
(story-grouping rule 4), then whichever of #2–#4 fired, then the security
evaluation (#5) and the backlog status flip (#6) — both of which always appear.

````markdown
- [ ] **Step 8: Verify the acceptance criteria**

AC1 — Send a reply from the inbox; the sent message renders a quoted block above its body.
AC2 — Open the thread in WhatsApp; the message displays as a native quote of the original.

- [ ] **Step 9: Integration test — http → service → data-access**

```ts
// apps/api/test/reply.e2e-spec.ts
it('persists replyToExternalId through the send path', async () => {
  const res = await request(app).post('/api/v1/messages').send({ conversationId, body: 'hi', replyToExternalId: 'wamid.X' })
  expect(res.status).toBe(201)
  expect(await db.message.findUnique({ where: { id: res.body.id } })).toMatchObject({ replyToExternalId: 'wamid.X' })
})
```

Run: `pnpm --filter @your-scope/api test reply`
Expected: PASS

- [ ] **Step 10: Smoke assertion**

Add to `scripts/smoke.sh`, after the outbound-send case: POST a reply, assert 201 and that the
stored row carries `replyToExternalId`.
Run: `pnpm smoke`
Expected: 24 passed (was 23).

- [ ] **Step 11: API docs**

In `docs/api.md`, under **Messaging**, add `POST /api/v1/messages` — permission
`messages:send`, body `{ conversationId, body, replyToExternalId? }`, 201 →
`{ id, externalId }`.

- [ ] **Step 12: Security evaluation**

`authorization` — `POST /api/v1/messages` declares `messages:send`; the gate is enforced in
`apps/api/src/messaging/messages.controller.ts`; smoke asserts 403 for a user without the key.
`tenant-isolation` — no new table; the existing `message` query path is already tenant-scoped, so
no change. Cross-tenant read test unchanged and still passing.
Surfaces not touched: `user-input` (no new user-supplied field reaches a query), `file-handling`,
`secrets`, `outbound-fetch`, `dependency`.

- [ ] **Step 13: Flip the backlog status**

In `docs/epic/e8-comms/user-stories.md`, set US-8.22 to `✅ Done` and AC1/AC2 to `✅`, appending
*(2 unit + 1 integration + 1 smoke assertion; verified live in the inbox.)*
````

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the
plan against it. This is a checklist you run yourself — not a subagent dispatch.

**1. Spec coverage.** Skim each section and requirement in the spec. Can you
point to a task that implements it? List any gaps.

**2. Placeholder scan.** Search the plan for the red flags in *No Placeholders*
above. Fix them.

**3. Type consistency.** Do the types, method signatures, and property names used
in later tasks match what earlier tasks defined? A function called
`clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

**4. Story coverage.** Every story has at least one task. Every AC is claimed by
at least one task tag. Every task heading carries a tag. Each story's final task
ends with an AC-verification step covering all of that story's ACs.

**5. Definition of Done.** For each story, walk all six triggers and state
whether each fires. Every trigger that fires has a close-out step containing real
content — code, an assertion, a named docs section, a named file and expected
state. Every requirement that is unconfigured appears as an explicit "not
configured — skipped" line. The security evaluation appears on every story,
including the ones where it records that no surface was touched.

If you find issues, fix them inline. No need to re-review — fix and move on. If
you find a spec requirement with no task, add the task.

## Execution handoff

After saving the plan, say where it is and offer the two ways to run it:

1. **Subagent-driven (recommended)** — a fresh subagent per task with review
   between tasks. Available only **if** `superpowers:subagent-driven-development`
   is installed.
2. **Inline** — execute the tasks in order in this session, reviewing between
   each.

`planwright` neither requires nor bundles superpowers. When it is absent, option
2 is the whole menu — say so, rather than naming a skill the user does not have.
`````

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/structure-test.sh`
Expected: PASS — twenty-one new `ok` lines; `all checks passed`; exit status 0.

- [ ] **Step 5: Confirm the plugin now reports two skills**

```bash
claude plugin validate .claude-plugin/plugin.json --strict
```

Expected: `✔ Validation passed` with no warnings. A malformed skill frontmatter block surfaces here as a warning, and `--strict` turns it into a failure.

- [ ] **Step 6: Commit**

```bash
git add skills/story-plans tests/structure-test.sh
git commit -m "feat: story-plans skill with story map, task tags, and definition of done"
```

---

## Task 6: README

**Files:**
- Create: `README.md`
- Modify: `tests/structure-test.sh` (append a `== readme ==` section)

**Interfaces:**
- Consumes: the install command from Task 1's manifests, the config keys from Task 3, the story format from Task 4, and the tag syntax from Task 5.

- [ ] **Step 1: Write the failing test**

Append to `tests/structure-test.sh`, before the summary block:

```bash
echo "== readme =="
has_file README.md
has_text README.md '/plugin marketplace add sshah-tripcart/planwright'
has_text README.md '.planwright.yml'
has_text README.md 'story-backlog'
has_text README.md 'story-plans'
has_text README.md 'obra/superpowers'
has_text README.md '[US-8.22·AC1]'
lacks_text README.md 'TODO'
lacks_text README.md 'TBD'
lacks_text README.md 'FIXME'
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/structure-test.sh`
Expected: FAIL — `missing: README.md` plus six `lacks:` lines. The three `lacks_text` checks pass vacuously on a missing file, which is fine: they exist to catch placeholder text once the file is written. `7 check(s) failed`; exit status 1.

- [ ] **Step 3: Write `README.md`**

````markdown
# planwright

A user-story layer above granular planning, for Claude Code.

Agentic planning produces good tasks and no answer to "done for whom?". `planwright`
adds the missing layer: stories with acceptance criteria you can check by looking
at the running system, tasks grouped under the story they serve and tagged with
the criterion they satisfy, and a Definition of Done whose triggers are evaluated
mechanically rather than remembered at the end.

It reads its paths, commands, personas, and epics from a per-project config file,
so it works on any codebase rather than one.

## Install

```
/plugin marketplace add sshah-tripcart/planwright
/plugin install planwright@planwright-marketplace
```

The repository is its own marketplace, so one `add` is enough. Updates arrive
with `/plugin marketplace update planwright-marketplace`.

## Configure

Copy [`templates/planwright.yml`](templates/planwright.yml) to your repository
root as `.planwright.yml` and edit it. Every key is optional. Most fall back to a
documented default, and the skills say which defaults they assumed — so an
omission is visible in the output rather than silently applied. `personas` and
`epics` are the exceptions: they have no default, and a skill that needs one asks
you rather than inventing it.

```yaml
backlog:
  epic_path: docs/epic/{slug}/user-stories.md
  fallback: docs/user-stories.md
specs: docs/specs/
plans: docs/plans/

personas: [Recruiter, Candidate, Agent, Employer, TenantAdmin, PlatformAdmin]
epics:
  E8: { theme: Comms & notifications, slug: e8-comms }
layers: [http, service, data-access, worker, external-adapter, authorization]

definition_of_done:
  unit:        { command: pnpm test }
  integration: { command: pnpm --filter @your-scope/api test, location: apps/api/test/ }
  smoke:       { command: pnpm smoke, file: scripts/smoke.sh }
  api_docs:    { file: docs/api.md }
  security:
    surfaces: [tenant-isolation, authorization, user-input, file-handling,
               secrets, outbound-fetch, dependency]
    command: null
  backlog_status: true
```

## The two skills

**`planwright:story-backlog`** — allocate a story before the spec is written, and
close it out after the work is verified. It assigns the next free `US-<epic>.<n>`
from a namespace spanning every backlog file, writes numbered acceptance criteria,
routes the story to the epic's file or the fallback, and at close-out flips the
status markers and appends an evidence note.

**`planwright:story-plans`** — turn a spec and its stories into an implementation
plan. Tasks are grouped under story headings, indexed by a Story Map, and each
heading carries a tag naming the criterion it satisfies. Each story's final task
ends with a close-out block: verify the ACs, then whichever Definition-of-Done
triggers fired.

## The workflow

```
backlog  →  spec  →  plan  →  task tag
```

The backlog is canonical. The spec restates each story so it reads standalone.
The plan copies the story statement and AC text **verbatim** — because a subagent
executing Task 5 sees only the plan, and cannot satisfy a criterion it cannot
read. The task tag closes the loop:

```markdown
### Task 1: Schema — two nullable reply columns  `[US-8.22·AC1]`
```

A story looks like this:

```markdown
**US-8.22** · `S` · ⬜ Not started · As a **Recruiter**, I want to reply to a specific message in a
thread, so that the contact can see which message I'm answering.
- ⬜ AC1: A message sent as a reply renders a quoted block above its body in the inbox thread.
- ⬜ AC2: The contact's WhatsApp client shows the message as a native quote of the original.
```

An acceptance criterion is decidable by looking at the running system, never by
reading code. "The `replyTo` column is nullable" is not one; "a reply renders a
quoted block" is.

## Definition of Done

Six requirements, evaluated per story:

| # | Requirement | Fires when the story… |
|---|-------------|-----------------------|
| 1 | Unit tests | contains branching logic, a pure function, a validator, or a projection |
| 2 | Integration tests | touches two or more configured `layers` |
| 3 | Smoke run | adds, changes, or removes an HTTP route, a request/response shape, or an auth gate |
| 4 | API docs | same trigger as #3 |
| 5 | Security check | touches any configured security surface — **evaluated always, recorded either way** |
| 6 | Backlog status | always |

Security is the requirement whose negative result is written down. When nothing
is touched, the plan says so and why — `security: no surface touched (UI-only
change)` — because a missed security surface costs more than a missed smoke
assertion, and silence cannot be distinguished from nobody having looked.

A requirement you have not configured is recorded as skipped, never silently
dropped.

## Relationship to superpowers

`planwright` is a standalone plugin with a soft dependency on
[obra/superpowers](https://github.com/obra/superpowers) in both directions: it
composes when present and works when absent.

- `superpowers:writing-plans` is not replaced or overridden. It stays installed
  and keeps updating; `story-plans` is a differently-named alternative you invoke
  for story-based work.
- `superpowers:brainstorming` stays upstream and untouched. `story-backlog` runs
  as its own step once the design settles, so allocation works even when
  brainstorming was not used.
- Plans generated by `story-plans` say to use
  `superpowers:subagent-driven-development` **if available**, and to execute
  task-by-task otherwise. That costs nothing when superpowers is absent.

Nothing here requires, bundles, disables, or modifies superpowers.

## Attribution

`skills/story-plans/SKILL.md` adapts material — task right-sizing, bite-sized step
granularity, the No Placeholders rules, the TDD step cycle, and the first three
self-review checks — from the `writing-plans` skill in `obra/superpowers` v6.2.0,
MIT licensed, Copyright (c) 2025 Jesse Vincent. It was copied once with
attribution. This repository is not a fork and tracks no upstream branch.

## Licence

MIT. See [LICENSE](LICENSE).
````

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/structure-test.sh`
Expected: PASS — ten new `ok` lines including the three `clean of:` lines; `all checks passed`; exit status 0.

- [ ] **Step 5: Commit**

```bash
git add README.md tests/structure-test.sh
git commit -m "docs: README covering install, config, both skills, and attribution"
```

---

## Task 7: Local install verification

The plugin is only finished if it installs and both skills are discoverable. This task installs from the local path, before anything is pushed, so a broken manifest is caught without a public commit.

**Files:**
- No files created or modified. This task verifies the artifact built by Tasks 1–6.

**Interfaces:**
- Consumes: `planwright`, `planwright-marketplace`, and the two skill names `story-backlog`, `story-plans`.

- [ ] **Step 1: Run the full structural suite one more time**

```bash
cd /opt/skills/planwright
bash tests/structure-test.sh
```

Expected: `all checks passed`; exit status 0. If anything fails here, fix it before installing — do not install a failing artifact.

- [ ] **Step 2: Validate both manifests**

```bash
claude plugin validate .claude-plugin/plugin.json --strict
claude plugin validate .claude-plugin/marketplace.json --strict
```

Expected: `✔ Validation passed` twice, no warnings.

- [ ] **Step 3: Add the marketplace from the local path**

```bash
claude plugin marketplace add /opt/skills/planwright
claude plugin marketplace list
```

Expected: `planwright-marketplace` appears in the list. If adding by local path is rejected, note it and defer this step to after Task 8, adding by `sshah-tripcart/planwright` instead — the local path is a convenience, not a requirement of the design.

- [ ] **Step 4: Install the plugin**

```bash
claude plugin install planwright@planwright-marketplace --scope user
```

Expected: install succeeds and reports the plugin name and version `0.1.0`.

- [ ] **Step 5: Confirm both skills are present**

```bash
claude plugin details planwright
```

Expected: the component inventory lists exactly two skills, `story-backlog` and `story-plans`, and a projected token cost. Two skills and no commands, hooks, or agents is the correct inventory for this plugin.

- [ ] **Step 6: Confirm superpowers is untouched**

```bash
claude plugin list
```

Expected: `superpowers` is still installed, still enabled, and still at the version it was before this work. `planwright` appears alongside it. Both coexisting is the design; if installing `planwright` disabled or shadowed anything, that is a defect in the manifests, not an acceptable outcome.

- [ ] **Step 7: Record the verification in the repo**

Append to `README.md` under `## Install`, as the last line of that section:

```markdown
Verified on Claude Code with `claude plugin validate --strict`, a local marketplace install, and
`claude plugin details planwright` reporting both skills.
```

- [ ] **Step 8: Commit**

```bash
git add README.md
git commit -m "docs: record local install verification"
```

---

## Task 8: Publish

**Files:**
- No files created or modified. This task pushes the repository built by Tasks 1–7 to a new public GitHub repository.

**Interfaces:**
- Produces: `https://github.com/sshah-tripcart/planwright`, the source of the install command in the README.

> **Confirm before running.** This task is the one irreversible step in the plan: it creates a public repository and publishes the copyright line, the attribution, and the whole plugin under `sshah-tripcart`. Ask the user to confirm before Step 2, and do not run it on an implicit go-ahead from earlier tasks.

- [ ] **Step 1: Confirm the working tree is clean and the history is coherent**

```bash
cd /opt/skills/planwright
git status --short
git log --oneline
```

Expected: no output from `git status --short`, and seven or eight commits from `git log --oneline` — one per task that wrote files. A dirty tree here means a previous task did not commit; commit it before publishing.

- [ ] **Step 2: Create the public repository and push**

```bash
gh repo create sshah-tripcart/planwright \
  --public \
  --source=. \
  --remote=origin \
  --description "A user-story layer above granular planning for Claude Code: stories with observable acceptance criteria, story-grouped tasks, and a Definition of Done." \
  --push
```

Expected: the repository URL is printed and `main` is pushed. `--source=.` with `--push` creates the remote, adds it as `origin`, and pushes the current branch in one call.

- [ ] **Step 3: Verify the published repository serves the manifests**

```bash
gh repo view sshah-tripcart/planwright --json name,visibility,defaultBranchRef
gh api repos/sshah-tripcart/planwright/contents/.claude-plugin/marketplace.json --jq '.name'
```

Expected: `"visibility": "PUBLIC"`, default branch `main`, and `marketplace.json` from the second call. A marketplace that GitHub cannot serve is a marketplace nobody can add.

- [ ] **Step 4: Install from the published source, as a user would**

```bash
claude plugin marketplace remove planwright-marketplace
claude plugin marketplace add sshah-tripcart/planwright
claude plugin install planwright@planwright-marketplace --scope user
claude plugin details planwright
```

Expected: the marketplace resolves from GitHub, the install succeeds, and `details` lists both skills — the same output as Task 7 Step 5, now from the public source rather than a local path. This is the exact command sequence the README tells users to run, so it is the one worth proving.

- [ ] **Step 5: Report the result**

State the repository URL, the install command, and the confirmed skill inventory. Installation is not the same claim as an end-to-end planning cycle: this step confirms the plugin installs and both skills are discoverable, not that a story has been carried from allocation through a verified close-out. That verification is out of scope for this plan.

---

## What this plan does not cover

This plan produces the publishable `planwright` plugin repository only: both skills, the config
schema and template, the manifests, the README, and the license. It does not cover adopting the
plugin into any particular consuming project, and it does not include an end-to-end run of the
skills against a real feature. `planwright` is publishable and installable without either.
