#!/usr/bin/env python3
# Auto-allow `gh api` calls when every {/} character sits inside a single-quoted
# shell string. Bypasses Claude Code's brace-expansion safety prompt for the
# PR-workflow GraphQL mutations, while leaving real brace expansion (e.g.
# `gh api {repos,users}/...`) to the normal permission flow.
import json
import sys

data = json.load(sys.stdin)
cmd = data.get("tool_input", {}).get("command", "")

if not cmd.lstrip().startswith("gh api"):
    sys.exit(0)

in_single_quote = False
for ch in cmd:
    if ch == "'":
        in_single_quote = not in_single_quote
    elif ch in "{}" and not in_single_quote:
        sys.exit(0)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason": "gh api: braces only in single-quoted strings",
    }
}))
