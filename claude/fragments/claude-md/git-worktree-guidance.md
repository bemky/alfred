## Concurrent sessions

- Multiple Claude Code sessions may be working in the same project directory at once. Do your work in a git worktree (`git worktree add ../<project>-<branch> -b <branch>`) rather than editing files directly in the shared checkout, to avoid collisions with other sessions' uncommitted changes.
- Don't run installs, dependency upgrades, or other commands that mutate the shared project directory itself (not just its git-tracked files) unless the task specifically requires it there — prefer running those inside your worktree.
- Clean up the worktree (`git worktree remove`) once your branch is merged or abandoned, rather than leaving it around.
