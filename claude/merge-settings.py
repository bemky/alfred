#!/usr/bin/env python3
"""Assembles a Claude Code settings.json from opt-in feature fragments and
overlays the result onto any existing settings.json, without disturbing
unrelated device-specific keys (enabledPlugins, feedbackSurveyState, ...).

Fragment hook arrays are concatenated per event (so e.g. the status-line and
gh-expansion fragments can each contribute their own PreToolUse entry)
instead of one fragment's hooks silently replacing another's. The assembled
result is then deep-merged onto the existing file: for a given event/key
that our fragments define, our value wins wholesale (so re-running with the
same flags doesn't duplicate hook entries); anything the existing file has
that our fragments don't touch is left alone.

Usage: merge-settings.py existing.json fragment.json [fragment.json ...]
       (existing.json may be a path to a nonexistent/empty file)
"""
import json
import sys


def load(path):
    try:
        with open(path) as f:
            text = f.read().strip()
    except FileNotFoundError:
        return {}
    return json.loads(text) if text else {}


def assemble(fragments):
    settings = {}
    hooks = {}
    for fragment in fragments:
        for key, value in fragment.items():
            if key != "hooks":
                settings[key] = value
        for event, entries in fragment.get("hooks", {}).items():
            hooks.setdefault(event, []).extend(entries)
    if hooks:
        settings["hooks"] = hooks
    return settings


def deep_merge(base, overlay):
    result = dict(base)
    for key, value in overlay.items():
        if isinstance(result.get(key), dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def main():
    existing_path, *fragment_paths = sys.argv[1:]
    existing = load(existing_path)
    assembled = assemble(load(p) for p in fragment_paths)
    result = deep_merge(existing, assembled)
    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
