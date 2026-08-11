#!/usr/bin/env bash
# Bootstraps ~/.claude on this machine from the files in this repo.
# Safe to re-run: copies scripts/commands as-is, merges settings.fragment.json
# into settings.json without clobbering device-specific keys (enabledPlugins,
# feedbackSurveyState, preferredNotifChannel, etc).
#
# Pass --remote for headless/shared servers: layers settings.remote.fragment.json
# (e.g. permission-bypass settings you do NOT want on a personal laptop) on top
# of the base settings, and appends CLAUDE.remote.md (e.g. multi-session/worktree
# guidance) to CLAUDE.md.
set -euo pipefail

remote=false
for arg in "$@"; do
  case "$arg" in
    --remote) remote=true ;;
    *) echo "alfred: unknown argument: $arg" >&2; exit 1 ;;
  esac
done

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_dir="$HOME/.claude"

case "$(uname -s)" in
  Darwin) os_suffix="osx" ;;
  Linux) os_suffix="linux" ;;
  *) echo "alfred: unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

mkdir -p "$claude_dir/hooks" "$claude_dir/commands"

cp "$repo_dir/claude/CLAUDE.md" "$claude_dir/CLAUDE.md"
if [ "$remote" = true ]; then
  cat "$repo_dir/claude/CLAUDE.remote.md" >> "$claude_dir/CLAUDE.md"
fi
cp "$repo_dir/claude/statusline-command-$os_suffix.sh" "$claude_dir/statusline-command.sh"
cp "$repo_dir/claude/fetch-usage-$os_suffix.sh" "$claude_dir/fetch-usage.sh"
cp "$repo_dir/claude/hooks/set-tab-title.sh" "$claude_dir/hooks/set-tab-title.sh"
cp "$repo_dir/claude/hooks/gh-api-allow-quoted-braces.py" "$claude_dir/hooks/gh-api-allow-quoted-braces.py"
cp "$repo_dir/claude/commands/meeting-notes.md" "$claude_dir/commands/meeting-notes.md"
chmod +x "$claude_dir/statusline-command.sh" "$claude_dir/fetch-usage.sh" "$claude_dir/hooks/set-tab-title.sh"

settings_file="$claude_dir/settings.json"
fragment_files=("$repo_dir/claude/settings.fragment.json")
if [ "$remote" = true ]; then
  fragment_files+=("$repo_dir/claude/settings.remote.fragment.json")
fi

if [ -f "$settings_file" ]; then
  merged="$(jq -s 'reduce .[1:][] as $f (.[0]; . * $f)' "$settings_file" "${fragment_files[@]}")"
else
  merged="$(jq -s 'reduce .[1:][] as $f (.[0]; . * $f)' "${fragment_files[@]}")"
fi

echo "$merged" > "$settings_file"

echo "alfred: installed Claude Code config into $claude_dir$([ "$remote" = true ] && echo " (remote overlay applied)")"
