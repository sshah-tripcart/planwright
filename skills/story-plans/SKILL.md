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

If no spec document exists — `planwright` does not bundle a spec-writing skill —
work from the design discussion in the current session instead, and record its
constraints verbatim under Global Constraints.

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
| `epics` | Epic number → theme and slug, used to resolve `{slug}` in `backlog.epic_path` | none — locate the story instead by grepping its ID across `*.md`, the same fallback `story-backlog` uses: `grep -rn 'US-8.22' --include='*.md' --exclude-dir=.git .` |
| `layers` | The integration-test trigger | `[http, service, data-access, worker, external-adapter, authorization]` |
| `definition_of_done.*` | Close-out step content | requirements #2 (integration), #3 (smoke), and #4 (API docs) are **recorded as skipped** when their command is unconfigured. #1 (unit), #5 (security), and #6 (backlog status) always apply and are never skipped — see *Definition of Done* below. |
| `definition_of_done.security.surfaces` | Which surfaces requirement #5 checks | the seven surfaces listed in *Security surfaces* below: `tenant-isolation`, `authorization`, `user-input`, `file-handling`, `secrets`, `outbound-fetch`, `dependency` |

A command-backed requirement (#2, #3, #4) with no configured command is written into the plan as
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

**AC visibility:** [story headings travel with each task | AC text restated inside each task block]

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
inside the task. Record which of the two your execution setup provides in the
plan header's **AC visibility** field, so a reader knows whether the story
headings are load-bearing. **The default is to restate the AC text inside the
task block** — if the header omits the field, that is the assumption in force.
Only declare "story headings travel with each task" when you know the execution
setup keeps the heading attached to the task; the cheaper option is never the
assumed one.

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
| 1 | **Unit tests** | …contains any task with branching logic, a pure function, a validator, or a projection. | Native to the TDD cycle (write failing test → implement → pass), run with `unit.command`. The self-review confirms every logic-bearing task has one. |
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

And a requirement whose command is unconfigured — #2, #3, or #4 — is **recorded
as skipped, never dropped**: write `smoke: not configured in .planwright.yml —
skipped`. A project without a smoke suite should see that line, not an
unexplained absence. #1, #5, and #6 have no unconfigured state to record: unit
tests run whenever logic-bearing code exists, security is evaluated on every
story (see below), and the backlog flip always happens.

### Security surfaces

A story fires requirement #5 when it touches any surface listed in
`security.surfaces` — the seven surfaces below by default when the key is
absent, or the project's own list when `.planwright.yml` configures one.
Surfaces are configured, not guessed: the set a story is checked against is
declared up front, once, not invented per story to fit whatever it happens to
touch.

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
state. Among #2–#4, every requirement that is unconfigured appears as an
explicit "not configured — skipped" line. #1, #5, and #6 are never skipped: the
unit-test step is native to the TDD cycle, the security evaluation appears on
every story — including the ones where it records that no surface was touched —
and the backlog status flip always happens.

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
