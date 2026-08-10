# CLAUDE.md (global)

## Tool preferences

- Prefer the `Edit`/`Write` tools over shell-based file editing (heredocs, `python3 - <<'PY'`, `sed -i`, sd, perl -pi, etc.) for changing file contents. These scripted rewrites bypass the dedicated file tools, are harder to review as a diff, and each novel invocation needs its own permission approval instead of being allowlistable.
- Only fall back to a shell script for edits Edit/Write genuinely can't express well — e.g. a mechanical transform across many files (bulk rename, regex sweep) where writing N individual Edit calls would be worse than one reviewable script.
- Don't chain unrelated commands with `&&`/`;` into one Bash call just to save a round trip — run them as separate calls so each stays a plain, allowlistable invocation.
