# unbloat-ed

Ed's single source of truth for AI skills, strict prompts, tool configurations, etc.

## Skills

Skills come from [mattpocock/skills](https://github.com/mattpocock/skills). They are
**not** vendored into this repo — the only thing tracked here is which commit to use:

| File | Purpose |
| :--- | :--- |
| `skills.lock` | The upstream repo URL and the exact commit hash in use |
| `skills.list` | Which skills to install |

Everything else is fetched on demand into `.cache/` (gitignored).

### Setting up a machine

```bash
./install-claude.sh    # → ~/.claude/skills
./install-agy.sh       # → ~/.gemini/skills
```

Each script clones the upstream repo at the pinned commit and symlinks the selected
skills into place. It's idempotent — re-run it any time. Links to skills that have
been dropped from `skills.list` are cleaned up automatically.

Requires SSH access to GitHub. Check with `ssh -T git@github.com`.

### Changing which skills are installed

Edit `skills.list`, then re-run the install script. To see what's on offer at the
current pin:

```bash
./update-skills.sh --list
```

Names are resolved by searching upstream's buckets (`engineering`, `productivity`,
`misc`, `in-progress`, `deprecated`), so a skill that gets promoted between buckets
keeps working without an edit here.

### Moving to a newer version of the skills

```bash
./update-skills.sh --status    # what's pinned now, and what's newer
./update-skills.sh             # move to the latest upstream release
./update-skills.sh v1.2.0      # or a specific tag, branch or commit
./update-skills.sh main        # or the tip of main
```

This shows the commits and the diff **limited to the skills you actually install**,
asks for confirmation, then rewrites the pin in `skills.lock`. Re-run the install
script afterwards and commit `skills.lock`.

Nothing else in this repo needs touching when upstream changes — that's the point.
Local edits to Matt's skills are deliberately not supported; configure per-repo
behaviour by running `/setup-matt-pocock-skills` in the target repo instead, which
writes a `docs/agents/issue-tracker.md` that the other skills read.

## Architecture

- `/core/prompts` — strict prompts
- `/guides` — setup notes
- `/lib` — shared shell helpers
- `skills.lock`, `skills.list` — the upstream skills pin
- `install-claude.sh`, `install-agy.sh`, `update-skills.sh`
