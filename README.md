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
- **Bypass-permissions overlay** — sets
  `permissions.defaultMode: bypassPermissions` for headless/shared servers
  (no confirmation prompts, including for destructive commands — never for
  a personal laptop).
- **Git-worktree guidance** — CLAUDE.md guidance to use a git worktree per
  concurrent session instead of editing a shared checkout directly.
- **Multi-profile support** — via `CLAUDE_CONFIG_DIR` (or `--target`), each
  profile gets its own credentials, settings, and usage cache so several
  logins can run side by side without clobbering each other.
- **Cross-platform install** — `install.sh` picks the right status-line and
  usage-fetch script for macOS (Keychain + BSD `date`) vs. Linux
  (`.credentials.json` + GNU `date`) automatically.

## Install

Every feature is opt-in — pass only the flags for what you want:

```bash
./install.sh --defaults --status-line-5h --status-tab-title --gh-expansion
```

```
Usage: install.sh [options]

Feature flags (opt-in; pass none and nothing is installed):
  --defaults                Editor prefs: model=sonnet, always-on thinking,
                             effortLevel=medium, fullscreen TUI
  --status-line-5h          Status line: usage stats + context-window fill
  --status-line-monthly     Status line: usage stats + context-window fill
                             (same status line as --status-line-5h; the
                             script auto-detects subscription vs. monthly
                             billing at runtime — pass either or both)
  --status-tab-title        Sync the terminal tab title to Claude's state
  --status-window-title     Sync the tmux window name to Claude's state
  --gh-expansion            Auto-allow `gh api` brace-expansion when braces
                             are only inside single-quoted strings
  --meeting-notes           Install the /meeting-notes command
  --prefer-edit-tool        CLAUDE.md: prefer Edit/Write over shell-based
                             file edits
  --bypass-permissions      permissions.defaultMode=bypassPermissions
                             (no confirmation prompts — headless/shared
                             servers only, never a personal laptop)
  --git-worktree-guidance   CLAUDE.md: use a git worktree per concurrent
                             session instead of the shared checkout
  --target DIR              Install into DIR instead of
                             ${CLAUDE_CONFIG_DIR:-~/.claude}
  -h, --help                Show this help
```

Copies only the scripts/commands the chosen flags need into the target dir,
and merges the corresponding `claude/fragments/settings/*.json` fragments
into `settings.json` (additive — won't clobber device-specific keys like
`enabledPlugins`/`feedbackSurveyState`, or hooks the chosen fragments don't
touch), and appends the corresponding `claude/fragments/claude-md/*.md`
sections to `CLAUDE.md` (also additive — sections you wrote yourself are never
overwritten). Safe to re-run with the same flags: hook entries aren't
duplicated, and a `CLAUDE.md` section that's already there is skipped rather
than appended twice. A section whose heading is present but whose body you've
edited is left as you edited it and reported as a `kept:` line.

Picks the OS-specific `statusline-command-{osx,linux}.sh` and
`fetch-usage-{osx,linux}.sh` variant based on `uname -s` and installs it as
the generic `statusline-command.sh` / `fetch-usage.sh` (macOS uses Keychain
via `security` and BSD `date`; Linux reads `~/.claude/.credentials.json`
directly and uses GNU `date`).

## Uninstall

Re-running `install.sh` with a flag dropped installs the remaining features but
does not remove the one you dropped. To take a feature back out, name it:

```bash
./uninstall.sh --status-tab-title
./uninstall.sh --all --target ~/.claude-jll
```

`uninstall.sh` takes the same feature flags as `install.sh` (plus `--all`) and
requires at least one. For each feature it deletes the scripts/commands that
feature installed, drops its settings keys, and removes its hook entries from
each event — leaving other features' hooks in those same events alone, and
pruning any group or event left empty.

It only removes what it installed. A settings key whose value no longer matches
the fragment (you switched `model` back to `opus`, say) and a `CLAUDE.md`
section you've edited are both left in place and reported as `kept:` lines, so
uninstalling `defaults` won't undo a choice you made yourself. `CLAUDE.md` is
deleted only if nothing but the header survives.

### Multiple profiles

To bootstrap a second profile (e.g. a separate work login), install into
that dir instead — either flag works the same:

```bash
./install.sh --status-line-5h --target ~/.claude-jll
CLAUDE_CONFIG_DIR=~/.claude-jll ./install.sh --status-line-5h
```

`--target` is space-separated on purpose: bash only tilde-expands after `=` in
an assignment, not in a command argument, so `--target=~/.claude-jll` would
install into a directory literally named `~`. Written with a space, your shell
expands `~` before the script sees it. The `=` spelling is rejected with a
message rather than silently misfiling your config.

All paths in the settings fragments and the shipped scripts resolve
`$CLAUDE_CONFIG_DIR` (falling back to `~/.claude`) at runtime, so each profile
reads its own credentials and writes to its own `/tmp` usage cache — profiles
never clobber each other's status line. Launch each profile with an alias
that sets the same env var, e.g.:

```bash
alias claude-jll='CLAUDE_CONFIG_DIR=~/.claude-jll claude'
```

## Layout

- `claude/fragments/claude-md/*.md` — CLAUDE.md sections, one per opt-in
  flag (`prefer-edit-tool`, `git-worktree-guidance`); appended to the
  target's `CLAUDE.md`
- `claude/fragments/settings/*.json` — one settings fragment per opt-in
  flag (`defaults`, `status-line`, `status-tab-title`, `status-window-title`,
  `gh-expansion`, `bypass-permissions`)
- `claude/merge-settings.py` — assembles the chosen fragments into
  `settings.json`, concatenating hook arrays per event so features don't
  clobber each other's hooks, and overlays the result onto any existing
  `settings.json` without disturbing keys the fragments don't touch
- `claude/unmerge-settings.py` — the inverse: drops a fragment's keys and hook
  entries from `settings.json`, skipping (and reporting) anything whose value
  has changed since install
- `claude/append-claude-md.py` — appends a fragment's section to `CLAUDE.md`
  unless it's already there, leaving the rest of the file untouched
- `claude/strip-claude-md.py` — cuts a fragment's section back out of
  `CLAUDE.md`, leaving hand-written sections around it intact
- `claude/statusline-command-{osx,linux}.sh`, `claude/fetch-usage-{osx,linux}.sh`
  — status line + usage, per OS (installed as `statusline-command.sh` /
  `fetch-usage.sh`)
- `claude/hooks/` — hook scripts referenced by the settings fragments
- `claude/commands/` — custom slash commands

## Updating

After changing something in `~/.claude` that should be portable, copy it back
into this repo (mirroring the layout above) and commit.
