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
| `specs` | Where the spec lives, so the story's `## Stories` restatement can be written into it | `docs/specs/` |
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
