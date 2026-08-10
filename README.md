# alfred

Bootstrap repo for agentic coding setup. Currently covers Claude Code config
(`~/.claude`); intended to grow to cover other agentic coding tools/configs.

## Install

```bash
./install.sh
```

Copies `claude/*` into `~/.claude/` and merges `claude/settings.fragment.json`
into `~/.claude/settings.json` (via `jq`, additive — won't clobber
device-specific keys like `enabledPlugins` or `feedbackSurveyState`).

## Layout

- `claude/CLAUDE.md` — global user instructions
- `claude/settings.fragment.json` — portable subset of `settings.json`
  (model, hooks, statusLine, effort/tui prefs)
- `claude/statusline-command.sh`, `claude/fetch-usage.sh` — status line + usage
- `claude/hooks/` — hook scripts referenced by `settings.fragment.json`
- `claude/commands/` — custom slash commands

## Updating

After changing something in `~/.claude` that should be portable, copy it back
into this repo (mirroring the layout above) and commit.
