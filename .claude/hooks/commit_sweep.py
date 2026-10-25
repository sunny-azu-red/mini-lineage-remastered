#!/usr/bin/env python3
"""PreToolUse guard: no `git commit` until the commit-sweep skill has swept the change.

The skill ends with `commit_sweep.py --stamp`, which writes the working tree's hash, untracked
files included, into the git dir. A commit goes through only while that digest still matches, so an
edit after the sweep voids it. Exit 2 refuses the command and hands Claude the reason on stderr.
"""
import json
import os
import subprocess
import sys
import tempfile

# Importing the guard would otherwise leave a __pycache__ beside it, in the repo.
sys.dont_write_bytecode = True
from dev_build_guard import commands  # noqa: E402

# Git's own options that take a value, so `git -C dir commit` still reads as a commit.
VALUED = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}


def commits(words):
    if not words or os.path.basename(words[0]) != "git":
        return False
    words = words[1:]
    while words and words[0].startswith("-"):
        words = words[2:] if words[0] in VALUED else words[1:]
    return words[:1] == ["commit"]


def git(root, *args, env=None):
    return subprocess.run(
        ["git", "-C", root, *args], capture_output=True, check=True, env=env
    ).stdout


def digest(root):
    """The working tree as git would store it, untracked files included and whatever is staged,
    or None when it is HEAD's. Built in a throwaway index, so staging moves nothing."""
    with tempfile.TemporaryDirectory() as scratch:
        env = dict(os.environ, GIT_INDEX_FILE=os.path.join(scratch, "index"))
        git(root, "read-tree", "HEAD", env=env)
        git(root, "add", "-A", env=env)
        tree = git(root, "write-tree", env=env).decode().strip()
    return None if tree == git(root, "rev-parse", "HEAD^{tree}").decode().strip() else tree


def stamp_path(root):
    return os.path.join(root, git(root, "rev-parse", "--git-path", "claude-commit-sweep").decode().strip())


def main():
    root = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())

    if sys.argv[1:] == ["--stamp"]:
        with open(stamp_path(root), "w") as file:
            file.write(digest(root) or "")
        print("Swept: the change as it stands may be committed.")
        return 0

    command = json.load(sys.stdin).get("tool_input", {}).get("command", "")
    if not any(commits(words) for words in commands(command)):
        return 0

    try:
        current = digest(root)
        if current is None:
            return 0
        with open(stamp_path(root)) as file:
            if file.read().strip() == current:
                return 0
    except (OSError, subprocess.CalledProcessError):
        pass

    print(
        "Refused: this change has not been swept since it last moved. Run the commit-sweep skill "
        "(dead code, stale docs and leftovers), which stamps the change as its last step, then "
        "commit again.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
