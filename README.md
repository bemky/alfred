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

Picks the OS-specific `statusline-command-{osx,linux}.sh` and
`fetch-usage-{osx,linux}.sh` variant based on `uname -s` and installs it as
the generic `statusline-command.sh` / `fetch-usage.sh` (macOS uses Keychain
via `security` and BSD `date`; Linux reads `~/.claude/.credentials.json`
directly and uses GNU `date`).

For a headless/shared server (not a personal laptop), pass `--remote`:

```bash
./install.sh --remote
```

This additionally appends `claude/CLAUDE.remote.md` to `CLAUDE.md` and merges
`claude/settings.remote.fragment.json` into `settings.json` — currently:
multi-session/git-worktree guidance, and `permissions.defaultMode:
bypassPermissions` (no confirmation prompts, including for destructive
commands). Deliberately opt-in and kept out of the base install.

## Layout

- `claude/CLAUDE.md` — global user instructions
- `claude/CLAUDE.remote.md` — appended to `CLAUDE.md` with `--remote`
- `claude/settings.fragment.json` — portable subset of `settings.json`
  (model, hooks, statusLine, effort/tui prefs)
- `claude/settings.remote.fragment.json` — merged into `settings.json` with
  `--remote` (permission-bypass and other server-only settings)
- `claude/statusline-command-{osx,linux}.sh`, `claude/fetch-usage-{osx,linux}.sh`
  — status line + usage, per OS (installed as `statusline-command.sh` /
  `fetch-usage.sh`)
- `claude/hooks/` — hook scripts referenced by `settings.fragment.json`
- `claude/commands/` — custom slash commands

## Updating

After changing something in `~/.claude` that should be portable, copy it back
into this repo (mirroring the layout above) and commit.
