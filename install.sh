#!/usr/bin/env bash
# Bootstraps a Claude Code config dir on this machine from the files in this
# repo. Defaults to ~/.claude; pass CLAUDE_CONFIG_DIR to target a different
# profile (e.g. `CLAUDE_CONFIG_DIR=~/.claude-jll ./install.sh`).
# Safe to re-run: copies scripts/commands as-is, merges settings.fragment.json
# into settings.json without clobbering device-specific keys (enabledPlugins,
# feedbackSurveyState, preferredNotifChannel, etc).
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

mkdir -p "$claude_dir/hooks" "$claude_dir/commands"

cp "$repo_dir/claude/CLAUDE.md" "$claude_dir/CLAUDE.md"
cp "$repo_dir/claude/statusline-command.sh" "$claude_dir/statusline-command.sh"
cp "$repo_dir/claude/fetch-usage.sh" "$claude_dir/fetch-usage.sh"
cp "$repo_dir/claude/hooks/set-tab-title.sh" "$claude_dir/hooks/set-tab-title.sh"
cp "$repo_dir/claude/hooks/gh-api-allow-quoted-braces.py" "$claude_dir/hooks/gh-api-allow-quoted-braces.py"
cp "$repo_dir/claude/commands/meeting-notes.md" "$claude_dir/commands/meeting-notes.md"
chmod +x "$claude_dir/statusline-command.sh" "$claude_dir/fetch-usage.sh" "$claude_dir/hooks/set-tab-title.sh"

settings_file="$claude_dir/settings.json"
fragment_file="$repo_dir/claude/settings.fragment.json"

if [ -f "$settings_file" ]; then
  merged="$(jq -s '.[0] * .[1]' "$settings_file" "$fragment_file")"
else
  merged="$(cat "$fragment_file")"
fi

echo "$merged" > "$settings_file"

echo "alfred: installed Claude Code config into $claude_dir"
