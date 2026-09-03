#!/usr/bin/env bash
# Removes features that install.sh added to a Claude Code config dir. Takes the
# same feature flags as install.sh — pass the ones you want gone.
# Defaults to ~/.claude; pass --target=DIR (or CLAUDE_CONFIG_DIR) for a
# different profile.
# Only removes what install.sh put there: settings keys and hook entries are
# dropped only while they still match the fragment that installed them, so
# anything you've since changed by hand is reported and left alone. Other
# features' hooks in the same event survive.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: uninstall.sh [options]

Feature flags (pass the features to remove; at least one is required):
  --defaults                Editor prefs: model, thinking, effortLevel, TUI
  --status-line-5h          Status line (same feature as --status-line-monthly)
  --status-line-monthly     Status line (same feature as --status-line-5h)
  --status-tab-title        Terminal tab title sync
  --status-window-title     tmux window name sync
  --gh-expansion            `gh api` brace-expansion allowlist hook
  --meeting-notes           The /meeting-notes command
  --prefer-edit-tool        CLAUDE.md: Edit/Write preference section
  --bypass-permissions      permissions.defaultMode=bypassPermissions
  --git-worktree-guidance   CLAUDE.md: git-worktree section
  --all                     Every feature above
  --target DIR              Uninstall from DIR instead of
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
    --all)
      defaults=true; status_line=true; status_tab_title=true; status_window_title=true
      gh_expansion=true; meeting_notes=true; prefer_edit_tool=true
      bypass_permissions=true; git_worktree_guidance=true ;;
    --target)
      shift
      [ $# -gt 0 ] || { echo "alfred: --target needs a directory" >&2; exit 1; }
      target="$1" ;;
    # Rejected rather than accepted-as-written: bash doesn't tilde-expand after
    # `=` in a command argument, so --target=~/dir would point at a literal `~`
    # directory. Space-separated lets the shell expand it before we see it.
    --target=*) echo "alfred: use '--target DIR', not '--target=DIR'" >&2; exit 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "alfred: unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_dir="${target:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
fragments_dir="$repo_dir/claude/fragments"

if [ ! -d "$claude_dir" ]; then
  echo "alfred: nothing to uninstall: $claude_dir does not exist" >&2
  exit 1
fi

removed=()
[ "$defaults" = true ] && removed+=("defaults")
[ "$status_line" = true ] && removed+=("status-line")
[ "$status_tab_title" = true ] && removed+=("status-tab-title")
[ "$status_window_title" = true ] && removed+=("status-window-title")
[ "$gh_expansion" = true ] && removed+=("gh-expansion")
[ "$meeting_notes" = true ] && removed+=("meeting-notes")
[ "$prefer_edit_tool" = true ] && removed+=("prefer-edit-tool")
[ "$bypass_permissions" = true ] && removed+=("bypass-permissions")
[ "$git_worktree_guidance" = true ] && removed+=("git-worktree-guidance")

if [ -z "${removed[0]+x}" ]; then
  echo "alfred: pass at least one feature to remove (or --all)" >&2
  usage >&2
  exit 1
fi

# --- settings.json: drop each chosen feature's keys and hook entries ---
settings_fragments=()
[ "$defaults" = true ] && settings_fragments+=("$fragments_dir/settings/defaults.json")
[ "$status_line" = true ] && settings_fragments+=("$fragments_dir/settings/status-line.json")
[ "$status_tab_title" = true ] && settings_fragments+=("$fragments_dir/settings/status-tab-title.json")
[ "$status_window_title" = true ] && settings_fragments+=("$fragments_dir/settings/status-window-title.json")
[ "$gh_expansion" = true ] && settings_fragments+=("$fragments_dir/settings/gh-expansion.json")
[ "$bypass_permissions" = true ] && settings_fragments+=("$fragments_dir/settings/bypass-permissions.json")

settings_file="$claude_dir/settings.json"
if [ -n "${settings_fragments[0]+x}" ] && [ -f "$settings_file" ]; then
  stripped="$(python3 "$repo_dir/claude/unmerge-settings.py" "$settings_file" \
    "${settings_fragments[@]}")"
  echo "$stripped" > "$settings_file"
fi

# --- CLAUDE.md: cut out each chosen feature's section ---
claude_md_fragments=()
[ "$prefer_edit_tool" = true ] && claude_md_fragments+=("$fragments_dir/claude-md/prefer-edit-tool.md")
[ "$git_worktree_guidance" = true ] && claude_md_fragments+=("$fragments_dir/claude-md/git-worktree-guidance.md")

claude_md="$claude_dir/CLAUDE.md"
if [ -n "${claude_md_fragments[0]+x}" ] && [ -f "$claude_md" ]; then
  stripped="$(python3 "$repo_dir/claude/strip-claude-md.py" "$claude_md" \
    "${claude_md_fragments[@]}")"
  if [ "$stripped" = "# CLAUDE.md (global)" ]; then
    rm -f "$claude_md"
  else
    echo "$stripped" > "$claude_md"
  fi
fi

# --- scripts/commands the chosen features installed ---
[ "$status_line" = true ] && rm -f "$claude_dir/statusline-command.sh" "$claude_dir/fetch-usage.sh"
[ "$status_tab_title" = true ] && rm -f "$claude_dir/hooks/set-tab-title.sh"
[ "$status_window_title" = true ] && rm -f "$claude_dir/hooks/set-tmux-window-name.sh"
[ "$gh_expansion" = true ] && rm -f "$claude_dir/hooks/gh-api-allow-quoted-braces.py"
[ "$meeting_notes" = true ] && rm -f "$claude_dir/commands/meeting-notes.md"

rmdir "$claude_dir/hooks" "$claude_dir/commands" 2>/dev/null || true

features="$(IFS=,; echo "${removed[*]}")"
echo "alfred: removed from $claude_dir ($features)"
