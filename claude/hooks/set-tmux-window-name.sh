#!/bin/bash
# Renames the tmux window containing this pane, if running inside tmux.
title="$1"
[ -n "$TMUX_PANE" ] || exit 0
win="$(tmux display-message -t "$TMUX_PANE" -p '#{window_id}' 2>/dev/null)"
[ -n "$win" ] && tmux rename-window -t "$win" "$title" 2>/dev/null
exit 0
