#!/usr/bin/env python3
"""Removes CLAUDE.md sections that install.sh assembled from fragments.

Each fragment's text is matched verbatim and cut out, so hand-written sections
you've added around them survive. A fragment whose text no longer appears (you
edited it) is reported on stderr as a `kept:` line and left in place.

Usage: strip-claude-md.py CLAUDE.md fragment.md [fragment.md ...]
       (writes the new CLAUDE.md to stdout)
"""
import os
import sys


def main():
    claude_md_path, *fragment_paths = sys.argv[1:]
    try:
        with open(claude_md_path) as f:
            text = f.read()
    except FileNotFoundError:
        text = ""
    for path in fragment_paths:
        with open(path) as f:
            block = f.read().strip()
        if not block:
            continue
        if block in text:
            text = text.replace(block, "")
            continue
        heading = next((l.strip() for l in block.splitlines() if l.startswith("#")), None)
        # A heading that's still there means the section was edited, so leave it
        # alone and say so. No heading means it was never installed — nothing to
        # report, or every --all run would list the features you don't use.
        if heading and heading in text.splitlines():
            name = os.path.basename(path)
            print(f"kept: {name} ({heading!r} edited since install)", file=sys.stderr)
    # Collapse the blank runs left behind by the removed blocks.
    lines = [line.rstrip() for line in text.splitlines()]
    out = []
    for line in lines:
        if line or (out and out[-1]):
            out.append(line)
    sys.stdout.write("\n".join(out).strip() + "\n")


if __name__ == "__main__":
    main()
