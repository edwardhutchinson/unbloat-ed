# unbloat-ed

Ed's single source of truth for AI skills, strict prompts, tool configurations, etc.

## Skills

Skills come from two kinds of place, and the install scripts deploy both:

| Where | What |
| :--- | :--- |
| `sources/*.lock` | External repos, each pinned to an exact commit. Not vendored — fetched on demand into `.cache/` (gitignored). |
| `core/skills/` | Skills we write ourselves, living in this repo. |

Today that's one source: `sources/mattpocock.lock`, pinning
[mattpocock/skills](https://github.com/mattpocock/skills). Only the commit hash is
tracked here, never his files.

### Setting up a machine

```bash
./install-claude.sh    # → ~/.claude/skills
./install-agy.sh       # → ~/.gemini/skills
```

Each script clones every source at its pinned commit and symlinks all the skills
into place, ours included. It's idempotent — re-run it any time. Links to skills
that no longer come from anywhere are cleaned up automatically.

Requires SSH access to GitHub. Check with `ssh -T git@github.com`.

### Adding a source

Drop a new `sources/<name>.lock` in, modelled on the existing one:

```
url        git@github.com:someone/their-skills.git
commit     <full 40-char sha>
ref        v2.0.0
pinned_at  2026-08-08
skills     skills/*
```

`skills` is a space-separated list of globs, relative to that repo's root, saying
where its skills live. A matched directory counts as a skill only if it contains a
`SKILL.md`, so READMEs and stray files are skipped.

### Adding our own skill

Make a directory under `core/skills/` with a `SKILL.md` in it, then re-run the
install script. See `core/skills/README.md`.

### When two places offer the same skill name

Later wins, and `core/skills/` is always deployed last — so our own skills override
anything upstream. Between external sources, the alphabetically later lockfile wins.
The install script prints every override it applies, so collisions are never silent.

This is the supported way to customise someone else's skill: copy it into
`core/skills/` under the same name and edit your copy. Never edit anything under
`.cache/` — it's overwritten on every install.

### Moving to newer versions

```bash
./update-skills.sh --status              # every pin, and what's newer
./update-skills.sh --list                # every skill that would be installed
./update-skills.sh                       # move all sources to their latest release
./update-skills.sh mattpocock            # just this one, to its latest release
./update-skills.sh mattpocock v1.2.0     # or to a specific tag, branch or commit
```

Bumping shows the commits and a diff **limited to the paths that source contributes
skills from**, asks for confirmation, then rewrites the pin in place, leaving the
lockfile's comments alone. Re-run the install script afterwards and commit `sources/`.

## Architecture

- `/sources` — pinned external skill repos, one lockfile each
- `/core/skills` — our own skills
- `/core/prompts` — strict prompts
- `/guides` — setup notes
- `/lib` — shared shell helpers
- `install-claude.sh`, `install-agy.sh`, `update-skills.sh`
