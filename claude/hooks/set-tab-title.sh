#!/bin/bash
# Writes an OSC title escape to the real tty of the nearest ancestor process
# still attached to one (hook subprocesses run detached, tty "??").
title="$1"
pid=$$

while [ -n "$pid" ] && [ "$pid" != "1" ]; do
  tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  if [ -n "$tty" ] && [ "$tty" != "??" ]; then
    printf '\033]0;%s\007' "$title" > "/dev/$tty" 2>/dev/null && exit 0
  fi
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done
exit 0
