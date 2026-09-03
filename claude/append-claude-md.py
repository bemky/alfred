#!/usr/bin/env python3
"""Appends CLAUDE.md sections from fragments, leaving existing content alone.

Additive and idempotent: a fragment already present verbatim is skipped, so
re-running the installer never duplicates a section, and anything you've
written into CLAUDE.md yourself survives. A fragment whose heading is already
in the file but whose body differs (you edited it) is also skipped rather than
appended a second time — both cases are reported on stderr as `kept:` lines.

Usage: append-claude-md.py CLAUDE.md fragment.md [fragment.md ...]
       (CLAUDE.md may be a path to a nonexistent file; result goes to stdout)
"""
import os
import sys

HEADER = "# CLAUDE.md (global)"


def heading_of(block):
    for line in block.splitlines():
        if line.startswith("#"):
            return line.strip()
    return None


def main():
    claude_md_path, *fragment_paths = sys.argv[1:]
    try:
        with open(claude_md_path) as f:
            text = f.read().strip()
    except FileNotFoundError:
        text = ""
    if not text:
        text = HEADER
    kept = []
    for path in fragment_paths:
        with open(path) as f:
            block = f.read().strip()
        if not block:
            continue
        name = os.path.basename(path)
        heading = heading_of(block)
        if block in text:
            kept.append(f"{name} (already present)")
        elif heading and heading in text.splitlines():
            kept.append(f"{name} ({heading!r} present but edited)")
        else:
            text = f"{text}\n\n{block}"
    for note in kept:
        print(f"kept: {note}", file=sys.stderr)
    sys.stdout.write(text + "\n")


if __name__ == "__main__":
    main()
