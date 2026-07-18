---
name: project-ed
description: Configure this repo for engineering skills — set up its issue tracker, and domain doc layout. Run once before first use of the other engineering skills.
disable-model-invocation: true
---


# Setup project-ed Directory

Scaffold the per-repo configuration that the engineering skills assume:

- **Issue tracker** — where issues live (.project-ed direcotory)
- **Triage labels** — the strings used for the five canonical triage roles
- **Domain docs** — where `CONTEXT.md` and ADRs live, and the consumer rules for reading them

This is a prompt-driven skill, not a deterministic script for writing up project configuration.

## Issue tracker: Local Markdown, .project-ed/

Issues and specs (you may know a spec as a PRD) for this repo live as markdown files in `.project-ed/`.

### Conventions

- One feature per directory: `.project-ed/<feature-slug>/`
- The spec is `.project-ed/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.project-ed/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01` — never a single combined tickets file
- Triage state is recorded as a `Status:` line near the top of each issue file (see `triage-labels.md` for the role strings)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading

### When a skill says "publish to the issue tracker"

Create a new file under `.project-ed/<feature-slug>/` (creating the directory if needed).

### When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.

### Wayfinding operations

Used by `/wayfinder`. The **map** is a file with one **child** file per ticket.

- **Map**: `.project-ed/<effort>/map.md` — the Notes / Decisions-so-far / Fog body.
- **Child ticket**: `.project-ed/<effort>/issues/NN-<slug>.md`, numbered from `01`, with the question in the body. A `Type:` line records the ticket type (`research`/`prototype`/`grilling`/`task`); a `Status:` line records `claimed`/`resolved`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `resolved`.
- **Frontier**: scan `.project-ed/<effort>/issues/` for files that are open, unblocked, and unclaimed; first by number wins.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer (gist + link) to the map's Decisions-so-far in `map.md`.


### Write Documentation

In brief, write short summaries of how the issue-tracker works at `docs/agents/issue-tracker.md`. Write up the triage-labels at `docs/agents/triage-labels.md`.

**Pick the file to edit:**

- If `CLAUDE.md` exists, edit it.
- Else if `AGENTS.md` exists, edit it.
- If neither exists, ask the user which one to create — don't pick for them.

Never create `AGENTS.md` when `CLAUDE.md` already exists (or vice versa) — always edit the one that's already there.

If an `## Agent skills` block already exists in the chosen file, update its contents in-place rather than appending a duplicate. Don't overwrite user edits to the surrounding sections.

The block:

```markdown
## Agent skills

### Issue tracker

[one-line summary of where issues are tracked]. See `docs/agents/issue-tracker.md`.

### Triage labels

[one-line summary of the label vocabulary]. See `docs/agents/triage-labels.md`.

