#!/usr/bin/env bash
# Bootstraps a Claude Code config dir on this machine from the files in this
# repo. Every feature below is opt-in via a flag — pass only what you want.
# Defaults to ~/.claude; pass --target=DIR (or CLAUDE_CONFIG_DIR) for a
# different profile, e.g. a separate work login.
# Safe to re-run: copies scripts/commands as-is, and merges settings into
# settings.json without clobbering device-specific keys (enabledPlugins,
# feedbackSurveyState, preferredNotifChannel, etc) or hooks our fragments
# don't touch.
set -euo pipefail

usage() {
  cat <<'USAGE'
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
USAGE
}

defaults=false
status_line=false
status_tab_title=false
status_window_title=false
gh_expansion=false
meeting_notes=false
prefer_edit_tool=false
bypass_permissions=false
git_worktree_guidance=false
target=""

while [ $# -gt 0 ]; do
  case "$1" in
    --defaults) defaults=true ;;
    --status-line-5h|--status-line-monthly) status_line=true ;;
    --status-tab-title) status_tab_title=true ;;
    --status-window-title) status_window_title=true ;;
    --gh-expansion) gh_expansion=true ;;
    --meeting-notes) meeting_notes=true ;;
    --prefer-edit-tool) prefer_edit_tool=true ;;
    --bypass-permissions) bypass_permissions=true ;;
    --git-worktree-guidance) git_worktree_guidance=true ;;
    --target)
      shift
      [ $# -gt 0 ] || { echo "alfred: --target needs a directory" >&2; exit 1; }
      target="$1" ;;
    # Rejected rather than accepted-as-written: bash doesn't tilde-expand after
    # `=` in a command argument, so --target=~/dir would install into a literal
    # `~` directory. Space-separated lets the shell expand it before we see it.
    --target=*) echo "alfred: use '--target DIR', not '--target=DIR'" >&2; exit 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "alfred: unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_dir="${target:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
fragments_dir="$repo_dir/claude/fragments"

case "$(uname -s)" in
  Darwin) os_suffix="osx" ;;
  Linux) os_suffix="linux" ;;
  *) echo "alfred: unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

mkdir -p "$claude_dir"

# --- CLAUDE.md: chosen fragments appended; untouched if none chosen ---
claude_md_fragments=()
[ "$prefer_edit_tool" = true ] && claude_md_fragments+=("$fragments_dir/claude-md/prefer-edit-tool.md")
[ "$git_worktree_guidance" = true ] && claude_md_fragments+=("$fragments_dir/claude-md/git-worktree-guidance.md")

if [ -n "${claude_md_fragments[0]+x}" ]; then
  claude_md="$claude_dir/CLAUDE.md"
  appended="$(python3 "$repo_dir/claude/append-claude-md.py" "$claude_md" \
    "${claude_md_fragments[@]}")"
  echo "$appended" > "$claude_md"
fi

# --- scripts/commands: only the ones the chosen features need ---
if [ "$status_line" = true ]; then
  cp "$repo_dir/claude/statusline-command-$os_suffix.sh" "$claude_dir/statusline-command.sh"
  cp "$repo_dir/claude/fetch-usage-$os_suffix.sh" "$claude_dir/fetch-usage.sh"
  chmod +x "$claude_dir/statusline-command.sh" "$claude_dir/fetch-usage.sh"
fi

if [ "$status_tab_title" = true ]; then
  mkdir -p "$claude_dir/hooks"
  cp "$repo_dir/claude/hooks/set-tab-title.sh" "$claude_dir/hooks/set-tab-title.sh"
  chmod +x "$claude_dir/hooks/set-tab-title.sh"
fi

if [ "$status_window_title" = true ]; then
  mkdir -p "$claude_dir/hooks"
  cp "$repo_dir/claude/hooks/set-tmux-window-name.sh" "$claude_dir/hooks/set-tmux-window-name.sh"
  chmod +x "$claude_dir/hooks/set-tmux-window-name.sh"
fi

if [ "$gh_expansion" = true ]; then
  mkdir -p "$claude_dir/hooks"
  cp "$repo_dir/claude/hooks/gh-api-allow-quoted-braces.py" "$claude_dir/hooks/gh-api-allow-quoted-braces.py"
fi

if [ "$meeting_notes" = true ]; then
  mkdir -p "$claude_dir/commands"
  cp "$repo_dir/claude/commands/meeting-notes.md" "$claude_dir/commands/meeting-notes.md"
fi

# --- settings.json: one fragment per chosen feature ---
settings_fragments=()
[ "$defaults" = true ] && settings_fragments+=("$fragments_dir/settings/defaults.json")
[ "$status_line" = true ] && settings_fragments+=("$fragments_dir/settings/status-line.json")
[ "$status_tab_title" = true ] && settings_fragments+=("$fragments_dir/settings/status-tab-title.json")
[ "$status_window_title" = true ] && settings_fragments+=("$fragments_dir/settings/status-window-title.json")
[ "$gh_expansion" = true ] && settings_fragments+=("$fragments_dir/settings/gh-expansion.json")
[ "$bypass_permissions" = true ] && settings_fragments+=("$fragments_dir/settings/bypass-permissions.json")

# ${arr[@]+"${arr[@]}"} so an empty array doesn't trip `set -u` on bash < 4.4.
settings_file="$claude_dir/settings.json"
merged="$(python3 "$repo_dir/claude/merge-settings.py" "$settings_file" \
  ${settings_fragments[@]+"${settings_fragments[@]}"})"
echo "$merged" > "$settings_file"

installed=()
[ "$defaults" = true ] && installed+=("defaults")
[ "$status_line" = true ] && installed+=("status-line")
[ "$status_tab_title" = true ] && installed+=("status-tab-title")
[ "$status_window_title" = true ] && installed+=("status-window-title")
[ "$gh_expansion" = true ] && installed+=("gh-expansion")
[ "$meeting_notes" = true ] && installed+=("meeting-notes")
[ "$prefer_edit_tool" = true ] && installed+=("prefer-edit-tool")
[ "$bypass_permissions" = true ] && installed+=("bypass-permissions")
[ "$git_worktree_guidance" = true ] && installed+=("git-worktree-guidance")

if [ -n "${installed[0]+x}" ]; then
  features="$(IFS=,; echo "${installed[*]}")"
else
  features="none"
fi
echo "alfred: installed Claude Code config into $claude_dir ($features)"
