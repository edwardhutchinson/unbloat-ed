# Our own skills

Skills written by us, as opposed to the pinned external repos in `../../sources/`.

Add one by creating a directory here with a `SKILL.md` inside:

```
core/skills/my-skill/SKILL.md
```

Then re-run `./install-claude.sh`. A directory without a `SKILL.md` is ignored, so
this README doesn't get deployed.

These are deployed **last**, so a skill here overrides an upstream skill of the same
name — the install script says so when it happens. That's the supported way to
customise someone else's skill: copy it here under the same name and edit your copy,
rather than editing anything under `.cache/`, which is overwritten on every install.
