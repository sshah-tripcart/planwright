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

Verified on Claude Code with `claude plugin validate --strict`, a local marketplace install, and
`claude plugin details planwright` reporting both skills.

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
  # Requirement 6 (backlog status) is unconditional and has no key.
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

`skills/story-plans/SKILL.md` adapts material — the Overview, Scope Check, File
Structure, Task Right-Sizing, Bite-Sized Task Granularity, Task Structure, No
Placeholders, and the first three self-review checks — from the `writing-plans`
skill in `obra/superpowers` v6.2.0, MIT licensed, Copyright (c) 2025 Jesse
Vincent. It was copied once with attribution. This repository is not a fork and
tracks no upstream branch.

## Licence

MIT. See [LICENSE](LICENSE).
