#!/usr/bin/env python3
"""Removes feature fragments from an existing Claude Code settings.json.

The inverse of merge-settings.py. For every key a fragment defines, the key is
dropped from settings.json only if the current value still deep-equals what the
fragment installed — anything you've since changed by hand is left alone, so
uninstalling `defaults` won't clobber a model you picked yourself. Hook entries
are matched individually within their event/matcher group, so removing one
feature's hooks leaves other features' hooks in the same event intact; groups
and events that end up empty are pruned.

Keys and hook entries that no longer match are reported on stderr as `kept:`
lines, so the caller can tell the user what it deliberately didn't touch.

Usage: unmerge-settings.py existing.json fragment.json [fragment.json ...]
       (writes the new settings.json to stdout)
"""
import json
import sys


def load(path):
    try:
        with open(path) as f:
            text = f.read().strip()
    except FileNotFoundError:
        return {}
    try:
        value = json.loads(text) if text else {}
    except json.JSONDecodeError as e:
        sys.exit(f"alfred: {path} is not valid JSON ({e}); fix it by hand first")
    if not isinstance(value, dict):
        sys.exit(f"alfred: {path} must contain a JSON object, got {type(value).__name__}")
    return value


def matcher_of(group):
    return group.get("matcher")


def strip_keys(existing, fragment, path, kept):
    """Drop fragment-installed keys from existing, recursing into nested dicts."""
    result = {}
    for key, value in existing.items():
        if key not in fragment:
            result[key] = value
            continue
        expected = fragment[key]
        where = f"{path}.{key}" if path else key
        if isinstance(value, dict) and isinstance(expected, dict):
            pruned = strip_keys(value, expected, where, kept)
            if pruned:
                result[key] = pruned
        elif value == expected:
            pass  # ours, untouched — remove it
        else:
            kept.append(f"{where} (changed since install)")
            result[key] = value
    return result


def strip_hooks(existing_events, fragment_events, kept):
    result = {}
    for event, groups in existing_events.items():
        fragment_groups = fragment_events.get(event, [])
        if not fragment_groups or not isinstance(groups, list):
            result[event] = groups
            continue
        surviving = []
        for group in groups:
            if not isinstance(group, dict):
                surviving.append(group)
                continue
            ours = [
                entry
                for fragment_group in fragment_groups
                if matcher_of(fragment_group) == matcher_of(group)
                for entry in fragment_group.get("hooks", [])
            ]
            if not ours:
                surviving.append(group)
                continue
            entries = [entry for entry in group.get("hooks", []) if entry not in ours]
            if entries:
                surviving.append({**group, "hooks": entries})
        if surviving:
            result[event] = surviving
    return result


def main():
    existing_path, *fragment_paths = sys.argv[1:]
    settings = load(existing_path)
    kept = []
    for fragment in (load(p) for p in fragment_paths):
        hooks = settings.get("hooks")
        settings = strip_keys(
            settings, {k: v for k, v in fragment.items() if k != "hooks"}, "", kept
        )
        if isinstance(hooks, dict) and "hooks" in fragment:
            hooks = strip_hooks(hooks, fragment["hooks"], kept)
            if hooks:
                settings["hooks"] = hooks
            else:
                settings.pop("hooks", None)
    for note in kept:
        print(f"kept: {note}", file=sys.stderr)
    json.dump(settings, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
