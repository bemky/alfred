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

Feature flags (opt-in; pass none and only base editor prefs are installed):
  --status-line-5h          Status line: usage stats + context-window fill
  --status-line-monthly     Status line: usage stats + context-window fill
                             (same status line as --status-line-5h; the
                             script auto-detects subscription vs. monthly
                             billing at runtime — pass either or both)
  --status-tab              Sync the terminal tab title to Claude's state
  --status-window-tile      Sync the tmux window name to Claude's state
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
  --target=DIR              Install into DIR instead of
                             ${CLAUDE_CONFIG_DIR:-~/.claude}
  -h, --help                Show this help
USAGE
}

status_line=false
status_tab=false
status_window_tile=false
gh_expansion=false
meeting_notes=false
prefer_edit_tool=false
bypass_permissions=false
git_worktree_guidance=false
target=""

for arg in "$@"; do
  case "$arg" in
    --status-line-5h|--status-line-monthly) status_line=true ;;
    --status-tab) status_tab=true ;;
    --status-window-tile) status_window_tile=true ;;
    --gh-expansion) gh_expansion=true ;;
    --meeting-notes) meeting_notes=true ;;
    --prefer-edit-tool) prefer_edit_tool=true ;;
    --bypass-permissions) bypass_permissions=true ;;
    --git-worktree-guidance) git_worktree_guidance=true ;;
    --target=*) target="${arg#--target=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "alfred: unknown argument: $arg" >&2; usage >&2; exit 1 ;;
  esac
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

# --- CLAUDE.md: assembled from opt-in fragments; untouched if none chosen ---
claude_md_fragments=()
[ "$prefer_edit_tool" = true ] && claude_md_fragments+=("$fragments_dir/claude-md/prefer-edit-tool.md")
[ "$git_worktree_guidance" = true ] && claude_md_fragments+=("$fragments_dir/claude-md/git-worktree-guidance.md")

if [ "${#claude_md_fragments[@]}" -gt 0 ]; then
  {
    echo "# CLAUDE.md (global)"
    echo
    for f in "${claude_md_fragments[@]}"; do
      echo
      cat "$f"
    done
  } > "$claude_dir/CLAUDE.md"
fi

# --- scripts/commands: only the ones the chosen features need ---
if [ "$status_line" = true ]; then
  cp "$repo_dir/claude/statusline-command-$os_suffix.sh" "$claude_dir/statusline-command.sh"
  cp "$repo_dir/claude/fetch-usage-$os_suffix.sh" "$claude_dir/fetch-usage.sh"
  chmod +x "$claude_dir/statusline-command.sh" "$claude_dir/fetch-usage.sh"
fi

if [ "$status_tab" = true ]; then
  mkdir -p "$claude_dir/hooks"
  cp "$repo_dir/claude/hooks/set-tab-title.sh" "$claude_dir/hooks/set-tab-title.sh"
  chmod +x "$claude_dir/hooks/set-tab-title.sh"
fi

if [ "$status_window_tile" = true ]; then
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

# --- settings.json: base prefs + one fragment per chosen feature ---
settings_fragments=("$fragments_dir/settings/base.json")
[ "$status_line" = true ] && settings_fragments+=("$fragments_dir/settings/status-line.json")
[ "$status_tab" = true ] && settings_fragments+=("$fragments_dir/settings/status-tab.json")
[ "$status_window_tile" = true ] && settings_fragments+=("$fragments_dir/settings/status-window-tile.json")
[ "$gh_expansion" = true ] && settings_fragments+=("$fragments_dir/settings/gh-expansion.json")
[ "$bypass_permissions" = true ] && settings_fragments+=("$fragments_dir/settings/bypass-permissions.json")

settings_file="$claude_dir/settings.json"
merged="$(python3 "$repo_dir/claude/merge-settings.py" "$settings_file" "${settings_fragments[@]}")"
echo "$merged" > "$settings_file"

installed=()
[ "$status_line" = true ] && installed+=("status-line")
[ "$status_tab" = true ] && installed+=("status-tab")
[ "$status_window_tile" = true ] && installed+=("status-window-tile")
[ "$gh_expansion" = true ] && installed+=("gh-expansion")
[ "$meeting_notes" = true ] && installed+=("meeting-notes")
[ "$prefer_edit_tool" = true ] && installed+=("prefer-edit-tool")
[ "$bypass_permissions" = true ] && installed+=("bypass-permissions")
[ "$git_worktree_guidance" = true ] && installed+=("git-worktree-guidance")

if [ "${#installed[@]}" -gt 0 ]; then
  features="$(IFS=,; echo "${installed[*]}")"
else
  features="none (base editor prefs only)"
fi
echo "alfred: installed Claude Code config into $claude_dir ($features)"
