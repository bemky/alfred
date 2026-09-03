# alfred

Bootstrap repo for agentic coding setup. Currently covers Claude Code config
(`~/.claude`); intended to grow to cover other agentic coding tools/configs.

## Features

- **Status line** — two-line prompt showing model, folder, git branch, plan
  usage (5h/7d or monthly cost/limits, whichever the account uses), and
  context-window fill. Usage numbers are fetched in the background and
  cached per-profile so the status line never blocks on a network call.

  Subscription (5h/7d) account:
  ```
  Sonnet 5 | alfred • statusline-month-passed
  5h 42% (2h 18m) • 7d 61% (3d 4h) | ctx 28% (57k/200k)
  ```

  Console/monthly-billing account, with the work-hours-elapsed indicator:
  ```
  Sonnet 5 | alfred • statusline-month-passed
  cc 33% ($16/$50 exp Sep 13) • mo 12% ($60/$500 Oct 1) • mo passed %58 (9-5 M-F) | ctx 28% (57k/200k)
  ```
- **Tab/window title sync** — a hook updates the terminal tab title and (if
  running inside tmux) the tmux window name to reflect Claude's state:
  working (👷), waiting on a permission prompt (⁉️), or done (✅).

  ```
  claude 👷   ← while a prompt is being processed
  claude ⁉️   ← while waiting on a permission prompt
  claude ✅   ← once Claude stops and is idle
  ```
- **`gh api` brace-expansion allowlist** — a `PreToolUse` hook auto-approves
  `gh api` commands whose `{`/`}` characters are all inside single-quoted
  strings (e.g. GraphQL mutations), while still prompting on real shell
  brace expansion.
- **`/meeting-notes` command** — turns a pasted meeting transcript into a
  structured summary, saves it as an Apple Note, then walks through creating
  a GitHub issue for each bug/feature request one at a time with
  confirmation.
- **Global CLAUDE.md** — tool-preference rules (e.g. prefer `Edit`/`Write`
  over shell-based file edits) applied to every project.
- **Remote/headless overlay** (`--remote` install flag) — opt-in extras for
  shared servers: `permissions.defaultMode: bypassPermissions`, and
  multi-session/git-worktree guidance appended to `CLAUDE.md`.
- **Multi-profile support** — via `CLAUDE_CONFIG_DIR`, each profile gets its
  own credentials, settings, and usage cache so several logins can run
  side by side without clobbering each other.
- **Cross-platform install** — `install.sh` picks the right status-line and
  usage-fetch script for macOS (Keychain + BSD `date`) vs. Linux
  (`.credentials.json` + GNU `date`) automatically, and merges settings via
  `jq` without clobbering device-specific keys.

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

### Multiple profiles

To bootstrap a second profile (e.g. a separate work login via
`CLAUDE_CONFIG_DIR`), install into that dir instead:

```bash
CLAUDE_CONFIG_DIR=~/.claude-jll ./install.sh
```

All paths in `settings.fragment.json` and the shipped scripts resolve
`$CLAUDE_CONFIG_DIR` (falling back to `~/.claude`) at runtime, so each profile
reads its own credentials and writes to its own `/tmp` usage cache — profiles
never clobber each other's status line. Launch each profile with an alias
that sets the same env var, e.g.:

```bash
alias claude-jll='CLAUDE_CONFIG_DIR=~/.claude-jll claude'
```

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
