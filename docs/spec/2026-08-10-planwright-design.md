# Planwright — a publishable user-story planning plugin — design

**Date:** 2026-08-10
**Status:** Approved
**Scope:** A new public, project-agnostic Claude Code plugin

> **Working name.** `planwright` is provisional throughout this document — plugin name, repo name,
> and marketplace name all derive from it. Renaming before implementation costs nothing; renaming
> after publication costs users.

## Goal

Add a **user-story layer above the granular tasks** that agentic planning workflows produce, so that
every implementation task is traceable to a user-visible outcome and its acceptance criteria — and
so a future sync can map stories and tasks onto Jira issues without rework.

Attach to that layer a **Definition of Done** — unit tests, integration tests, a smoke run, updated
API docs, a security check, and a backlog status flip — expressed as triggers a plan author
evaluates mechanically, so that verification is planned into the work rather than remembered at the
end.

Ship it as a **standalone, publicly installable plugin** that reads its paths, commands, personas,
and epics from a per-project config file, so it is useful on any codebase rather than tuned to one.

## Background — what exists today

The superpowers plugin (`obra/superpowers` v6.2.0, MIT, installed via `obra/superpowers-marketplace`)
drives planning through two skills:

- **`superpowers:brainstorming`** — dialogue → design → writes a spec, defaulting to
  `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`. It explicitly notes that *user preferences
  for spec location override this default*.
- **`superpowers:writing-plans`** — spec → an implementation plan, defaulting to
  `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`, structured as a header
  (Goal / Architecture / Tech Stack / Global Constraints), a File Structure table, then a **flat
  list of `### Task N` blocks** with Files / Interfaces / TDD steps.

Three gaps motivate this work:

1. **There is no story layer.** Tasks are grouped only by the File Structure table. Nothing states
   the user-visible outcome a task serves, and nothing is verifiable as "done" at the level a
   stakeholder cares about.
2. **Verification is remembered, not planned.** Whether a change needs an integration test, a smoke
   run, or a docs update is left to the plan author's judgement at the end.
3. **A consuming project's spec/plan locations can differ from the skill defaults**, and nothing
   requires that override to be recorded anywhere durable — not `CLAUDE.md`, not a skill file — so it
   is easy for the two to drift silently apart.

## Decisions taken

| Question | Decision |
|---|---|
| Where do stories live? | Markdown is the single source of truth. Jira sync is a later, optional step. |
| Which ID scheme? | **`US-<epic>.<n>`** — a per-epic namespace, chosen so IDs stay short and stable while sorting naturally within an epic. |
| Which document owns a story? | The **backlog** is canonical; the **spec** restates the story, the **plan** copies it verbatim. |
| Which backlog file? | `docs/epic/<slug>/user-stories.md` when that epic folder exists, otherwise a generic fallback file. Both paths are config. |
| What proves a story is done? | A **Definition of Done** — unit tests, integration tests, smoke run, API docs, security check, backlog status — with machine-checkable triggers rather than "if applicable". |
| Why is security different? | Its trigger is evaluated on **every** story and the outcome recorded either way, including the negative. Silence must not be confusable with nobody having looked. |
| Fork or standalone? | **Standalone plugin.** Publishing inverts the fork's economics — see below. |
| Relationship to superpowers? | **Soft dependency.** Composes when present, works when absent. |

### Why standalone rather than a fork

An earlier iteration of this design forked `obra/superpowers` and edited two skills in place. That
shape depended entirely on keeping the forked plugin named `superpowers`, which preserved all
26 internal `superpowers:<skill>` cross-references across 9 skill files, and any existing plan that
already names `superpowers:subagent-driven-development` in its header.

Publishing publicly removes that option: a public plugin cannot share Jesse's plugin name without
colliding on install and confusing users. Once the name must change, all 26 references need
rewriting, and — decisively — **every future `git merge upstream/main` re-introduces upstream's
references into those same 9 files, forever.** The fork's one advantage evaporates and its
maintenance cost remains.

Standalone inverts this. Skills are markdown read into context, not libraries linked at runtime, so
the parts of `writing-plans` worth keeping (bite-sized task granularity, the No Placeholders rules,
the TDD step cycle) can be **copied once under MIT, with attribution, and then owned outright.** A
copy creates no ongoing obligation; a fork creates a merge every time upstream moves.

## Design

### 1. The story format (backlog — canonical)

Stories are allocated in the backlog **before** the spec is written:

```markdown
**US-8.22** · `S` · ⬜ Not started · As a **Recruiter**, I want to reply to a specific message in a
thread, so that the contact can see which message I'm answering.
- ⬜ AC1: A message sent as a reply renders a quoted block above its body in the inbox thread.
- ⬜ AC2: The contact's WhatsApp client shows the message as a native quote of the original.
```

Rules:

- **IDs come from a single global namespace.** `US-<epic>.<n>`, taking the next free `n` within the
  epic. The namespace spans **every** backlog file, so `n` is allocated by scanning all of them, not
  just the file being written. IDs are never reused or renumbered.
- **File routing.** A story goes in the configured epic path — `docs/epic/<slug>/user-stories.md` by
  default — when that epic folder exists; otherwise it goes in the configured fallback file. The
  slug is `e<n>-<theme>` in kebab-case, derived from the epic table in config.
- **Epic folders are created deliberately, not automatically.** Promoting an epic means creating its
  folder, moving that epic's stories out of the fallback file, and leaving a pointer line behind.
  The folder-per-epic shape leaves room for epic-scoped notes and diagrams beside the stories.
- **The persona is one of the configured set.** Priority is `M`/`S`/`C`; status starts
  `⬜ Not started`.
- **Acceptance criteria are numbered** `AC1`, `AC2`, … in stories this workflow writes or edits, so
  a task can tag one. Pre-existing unnumbered `- AC:` bullets are left exactly as they are.
- **Every story has at least one acceptance criterion**, and **an AC is observable** — decidable by
  looking at the running system, never by reading code. "The `replyTo` column is nullable" is not an
  AC; "a reply renders a quoted block" is.
- **A story describes user-visible value.** Enabling work that no user can observe is not a story —
  it is a task belonging to one.

The spec's `## Stories` section then restates each allocated story — ID, statement, and numbered
ACs — so the spec reads standalone. The backlog remains the source of truth if the two disagree.

### 2. The story map and task grouping (plan — verbatim copy)

The plan's flat task list is replaced by story-grouped tasks. After `## Global Constraints` and the
File Structure table:

````markdown
## Story Map

| Story | ACs | Tasks |
|-------|-----|-------|
| US-8.22 — Agent replies with a quote | AC1, AC2 | 1, 2, 5, 7 |
| US-8.23 — Recruiter sees reply context on mobile | AC1 | 6, 7 |

---

## US-8.22 — Agent replies with a quote

As a **Recruiter**, I want to reply to a specific message in a thread, so that the contact can see
which message I'm answering.

**Acceptance criteria** (verbatim from `docs/epic/e8-comms/user-stories.md`)
- **AC1** — A message sent as a reply renders a quoted block above its body in the inbox thread.
- **AC2** — The contact's WhatsApp client shows the message as a native quote of the original.

### Task 1: Schema — two nullable reply columns  `[US-8.22·AC1]`

**Files:**
- Modify: `apps/api/prisma/schema.prisma`

**Interfaces:**
- Produces: `Message.replyToExternalId: string | null`
````

Four rules make the layer load-bearing rather than decorative:

1. **Every task heading carries a story tag** — `` `[US-8.22·AC1]` ``, or `` `[US-8.22·AC1,AC2]` ``
   when it serves several criteria of its story. A task with no tag is a plan defect.
2. **Story statement and AC text are copied verbatim** from the backlog into the plan's story
   heading. The copy is word-for-word; if the backlog changes, the plan is updated to match.
3. **One task, one home.** Groundwork serving several stories (a migration, a shared type) is placed
   under the **earliest** story that requires it. The Story Map's Tasks column may list that task
   under more than one story — the column is a cross-reference, the heading is the owner.
4. **Each story's final task ends with an AC-verification step**, distinct from its "run the tests"
   step, that demonstrates every AC of that story.

The copy-forward chain — **backlog → spec → plan → task tag** — exists because a subagent executing
Task 5 sees **only the plan**. If the acceptance criteria live solely upstream, that subagent cannot
read the criterion it is supposed to satisfy.

### 3. Plugin shape

A fresh MIT repo. No fork, no `upstream` remote, no merges.

```
planwright/
  .claude-plugin/
    plugin.json          name: planwright
    marketplace.json     name: planwright-marketplace, plugin source: ./
  skills/
    story-backlog/SKILL.md
    story-plans/SKILL.md
  templates/
    planwright.yml        commented starter config
  README.md
  LICENSE                MIT (yours), plus attribution for the copied material
```

A single repo serves as both marketplace and plugin — `marketplace.json` beside `plugin.json` with
the plugin's `source` set to `"./"`. This is a documented, supported pattern, not a gamble: the
marketplace reference states *"For plugins in the same repository, use a path starting with `./`"*
and shows `source: "./"` for a plugin living at the marketplace root. Users install with
`/plugin marketplace add sshah-tripcart/planwright`.

**Distribution needs no approval.** Claude Code marketplaces are decentralised — you host a git
repo, users add it by name. There is no submission, review queue, registry listing, or fee. Updates
ship by pushing to the repo; users pull them with `/plugin marketplace update`.

**Attribution.** `story-plans/SKILL.md` incorporates material from `obra/superpowers` under MIT. The
LICENSE file carries both copyright lines, and the skill file carries a provenance comment naming
the source and the version copied from. This is a one-time copy, not a tracked fork.

### 4. The two skills

**`skills/story-backlog/SKILL.md`** — allocate and maintain stories. Reads config, scans every
backlog file for the epic's highest `n`, writes the new story in house format with numbered ACs,
and routes it per §1. Also owns the close-out edit: flipping status markers and appending the
evidence note. Entirely new; nothing upstream corresponds to it.

**`skills/story-plans/SKILL.md`** — spec + stories → a story-grouped implementation plan. This is
where the copied material lives: task right-sizing, the bite-sized step granularity, the No
Placeholders rules, the TDD step cycle, and the plan self-review. On top of that it adds the Story
Map, story-grouped headings, task tags, the close-out block, and two extra self-review checks:

- **Story coverage** — every story has ≥1 task; every AC is claimed by ≥1 task tag; every task
  carries a tag.
- **Definition of Done** — for each story, each of the six triggers is evaluated, and every trigger
  that fires has a close-out step containing real content.

### 5. Project configuration

Everything project-specific lives in `.planwright.yml` at the consuming repo's root. The plugin ships
`templates/planwright.yml` as a commented starter.

```yaml
backlog:
  epic_path: docs/epic/{slug}/user-stories.md
  fallback:  docs/user-stories.md
specs: docs/spec/
plans: docs/plans/

personas: [Recruiter, Candidate, Agent, Employer, TenantAdmin, PlatformAdmin]

epics:
  E0: { theme: Platform foundation, slug: e0-platform }
  E8: { theme: Comms & notifications, slug: e8-comms }

layers: [http, service, data-access, worker, external-adapter, authorization]

definition_of_done:
  unit:        { command: pnpm --filter @your-scope/shared test }
  integration: { command: pnpm --filter @your-scope/api test, location: apps/api/test/ }
  smoke:       { command: pnpm smoke, file: scripts/smoke.sh }
  api_docs:    { file: docs/api.md }
  security:
    surfaces: [tenant-isolation, authorization, user-input, file-handling, secrets,
               outbound-fetch, dependency]
    command: null          # optional; e.g. a security-review skill or scanner
  backlog_status: true
```

Two rules govern config handling. **Missing config is not silent failure** — with no `.planwright.yml`
the skills fall back to `docs/specs/`, `docs/plans/`, `docs/user-stories.md`, and state in the plan
which defaults they assumed. And **a Definition-of-Done requirement with no configured command is
skipped explicitly and recorded in the plan** as skipped, never silently dropped; a project without
a smoke suite should see "smoke: not configured", not an unexplained absence.

### 6. Definition of Done

The plan must satisfy these before its story's tasks can be marked complete. They are written as
triggers rather than "where applicable" because the copied No Placeholders rule forbids vague steps:
a plan author must be able to decide, mechanically, whether each fires.

| # | Requirement | Trigger — it fires when the story… | Step content |
|---|---|---|---|
| 1 | **Unit tests** | …contains any task with branching logic, a pure function, a validator, or a projection. | Native to the TDD cycle (write failing test → implement → pass). The self-review confirms every logic-bearing task has one. |
| 2 | **Integration tests** | …touches two or more of the configured `layers`. | A test at the configured `integration.location` exercising the real boundary, run with `integration.command`. |
| 3 | **Smoke run** | …adds, changes, or removes an HTTP route, a request/response shape, or an auth/permission gate. | Extend `smoke.file` with an assertion for the new behaviour, run `smoke.command`, record the expected pass count. |
| 4 | **API docs** | Same trigger as #3. | Update `api_docs.file` — the endpoint's method, path, auth/permission key, request body, success response. |
| 5 | **Security check** | …touches any configured `security.surfaces` — see below. Evaluated always; the outcome is recorded either way. | The specific checks for the surfaces touched, each naming its file and expected state. Never the words "review for security". |
| 6 | **Backlog status** | Always. | Flip the story's marker from `⬜ Not started` to `✅ Done` (or `🟡 Partial`), and each AC's marker with it, appending an evidence note — `*(3 unit + 1 smoke assertion; verified live.)*`. |

**Security surfaces (#5) are configured, not guessed.** A story fires the check when it touches any
of them:

| Surface | Fires on | Example check content |
|---|---|---|
| `tenant-isolation` | A new table, or a new query path to an existing one | The table is listed in the project's row-level-security policy file, is FORCE-RLS with a `tenant_isolation` policy, and a cross-tenant read test proves isolation as the non-superuser role |
| `authorization` | A new or changed route, permission key, or role check | The route declares its permission key and the gate is enforced; a smoke assertion covers the 403 path |
| `user-input` | User-supplied data reaching storage, a query, a path, or a rendered view | The field goes through the field-type sanitisation layer; no raw SQL interpolation; no `dangerouslySetInnerHTML` |
| `file-handling` | Upload, download, or serving of files | MIME allowlist covers the new type; size cap applies; the stored path is not user-controlled |
| `secrets` | Credentials, tokens, or crypto | Not logged, not returned in a response projection, env-gated with a boot-time requirement |
| `outbound-fetch` | Fetching a user-supplied URL, or a new webhook | The URL is validated against an allowlist; the webhook verifies its signature |
| `dependency` | A new runtime dependency | Justified in the plan, and its addition is visible in the diff |

**The evaluation is always recorded.** When no surface is touched, the close-out carries one line
stating so with the reason — `security: no surface touched (UI-only change)`. This is the one
requirement whose negative result is written down, because a missed security surface costs more than
a missed smoke assertion, and silence cannot be distinguished from nobody having looked.

Where a project has a security-review command or skill configured, the step runs it in addition to
the surface checks — it does not replace them.

Two rules keep this from becoming ceremony. **Triggers are evaluated per story, not per task** — a
story that only changes a UI component fires none of #2–#4 (only #5, which always applies), and its
plan must not carry empty close-out steps for the rest. And **every firing trigger becomes a real
step with real content**: an integration-test step contains the test code, a smoke step contains the
assertion and the command, a docs step names the exact section and the lines to add. "Add tests" and
"update docs" are plan defects.

Each story's final task therefore ends with a **close-out block**: the AC-verification step from §2
rule 4, followed by whichever of #2–#4 fired, then the security evaluation (#5) and the backlog
 status flip (#6), which always appear.

### 7. Composition with superpowers

Soft dependency in both directions. `planwright` neither requires nor bundles superpowers.

- **`writing-plans` is not removed or overridden.** It stays installed and keeps updating;
  `story-plans` is a differently-named alternative invoked for story-based work. Because the names
  differ, there is no ambiguity about which applies.
- **`brainstorming` stays upstream and untouched**, so it keeps receiving updates. `story-backlog`
  runs as its own step once the design settles, which also means allocation works when brainstorming
  wasn't used at all.
- **Execution stays upstream.** The generated plan header reads: *if
  `superpowers:subagent-driven-development` is available use it, otherwise execute task-by-task,
  reviewing between tasks.* Costs nothing when absent; composes automatically when present.
- **TDD discipline, code review, verification, debugging, worktrees** are all orthogonal concerns
  left to whatever the project already uses.

The accepted cost: upstream improvements to `writing-plans`' planning guidance do not arrive
automatically. That is one file to diff and cherry-pick from when desired — optional maintenance,
not a forced merge.

### 8. Adopting the plugin into a project

Three things a consuming project needs, none of them part of the plugin itself:

- **A `.planwright.yml`** at the repo root, exactly as in §5.
- **One line in `CLAUDE.md`** under Workflow expectations: specs go in `docs/spec/`, plans in
  `docs/plans/`, stories in the backlog, and every plan task carries a `[US-<epic>.<n>·AC<k>]` tag.
  This line is load-bearing, not decorative — upstream `brainstorming` defaults to
  `docs/superpowers/specs/` and defers to user preferences for the override, so this is the
  supported mechanism. Without it, a convention survives only in agent memory.
- **An API reference file, if requirement #4 needs one** — see §9.

Existing story files are not migrated as part of adopting the plugin. Whatever markdown already
holds a project's stories keeps living where it is; an epic is promoted out of the fallback file
only when its folder is created deliberately (§1), never as a side effect of installing the plugin.

### 9. An API reference file

Definition-of-Done requirement #4 needs a target that exists. Many projects do not have one yet: no
OpenAPI or Swagger spec anywhere, and the API surface described only in prose scattered across
existing architecture documents.

A `docs/api.md` (or wherever `definition_of_done.api_docs.file` points) becomes the canonical
endpoint reference. Where a project's route surface is large or irregular — many controllers, plus
a generic route that serves several entity types through one contract — the true surface is larger
than a per-route count suggests, and needs a generic-contract entry rather than one row per entity.

It is built in two moves so requirement #4 never points at a missing file:

1. **Skeleton first** — every route inventoried by method, path, and owning controller, grouped by
   module, with any generic contract described once.
2. **Detail thereafter** — auth/permission key, request body, and success response per endpoint,
   filled in by a dedicated backfill and incrementally by each story firing trigger #4.

Existing prose docs keep their architectural narrative and link to the API reference file for
endpoint detail.

## Scope

This spec describes the `planwright` plugin itself — the repo, both skills, the config schema and
template, the manifests, the README, and the license — which is the publishable artifact. Adopting
the plugin into a specific project (§8) and building that project's API reference file (§9) are
included here as design rationale, not as work this repository ships.

## Non-goals

- **The Jira sync is not built.** Story IDs and task numbers are stable identifiers, so a later sync
  can map story → Jira Story and task → Jira Task with the story as parent, writing a
  `**Jira:** PROJ-123` line back under the story heading. Nothing about that is implemented here, and
  no empty Jira field is added to the templates. (The Atlassian MCP server in this workspace is also
  not yet authorised.)
- **No superpowers skill is modified, removed, or republished.** All fourteen stay installed and
  keep updating from upstream.
- **No retrofit and no backlog migration.** Existing plans, specs, and story files keep their
  current shape. The convention applies to work started after adoption.
- **No AC renumbering.** Pre-existing unnumbered `- AC:` bullets stay as they are.
- **No config auto-generation.** `.planwright.yml` is written by hand from the template; the plugin
  does not infer commands or paths by scanning a repo.

## Verification and rollback

**Plugin install** — `/plugin marketplace add sshah-tripcart/planwright`, then install. Superpowers is left
installed throughout; the two coexist by design, so there is no uninstall-first ordering.

**Verification is a real cycle, not a file inspection.** Run one genuine small feature that touches
the API surface through design → `story-backlog` → `story-plans`, and confirm: the story is
allocated in the routed backlog file with numbered observable ACs and a globally-unique ID; the spec
lands in the configured `specs` path with a `## Stories` section; the plan lands in the configured
`plans` path with a Story Map; tasks are grouped under story headings and every heading carries a
tag; the story's final task carries a close-out block with the AC-verification step plus the steps
its triggers fired; each of those steps contains real content rather than an instruction to go write
it; and any unconfigured requirement is recorded as skipped rather than silently absent.

An API-touching feature is chosen deliberately — it is the only shape that exercises all six
triggers at once.

**Rollback** is uninstalling the plugin. Nothing in superpowers was changed, so its behaviour
returns to baseline immediately; `.planwright.yml` and the `CLAUDE.md` line become inert text.
