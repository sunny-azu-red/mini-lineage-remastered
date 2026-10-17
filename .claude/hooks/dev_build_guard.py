#!/usr/bin/env python3
"""PreToolUse guard: no Mix command may compile into _build/dev while the dev server is up.

Two writers to one build corrupted beams and crashed a character mid-game (AGENTS.md, Working
here). Exit 2 refuses the command and hands Claude the reason on stderr.
"""
import json
import os
import re
import shlex
import socket
import sys

# Tasks that compile, or delete, the project's build. Bare `mix` is `mix dev`. Left out on purpose:
# test and precommit choose :test; e2e, build, prod, start and stop are the repo's own workflow, and
# the dev server has compiled what they would; help, format and deps.get compile nothing.
BUILDS = re.compile(
    r"compile(\..+)?|run|eval|dev|setup|do|clean|release|escript\.build|xref|dialyzer"
    r"|phx\.(server|routes|digest|gen\..+)|deps\.(compile|clean)|ecto\..+|esbuild|assets\..+|app\..+"
)
ISOLATED_ENVS = {"test", "e2e", "prod"}
WRAPPERS = {"nice", "timeout", "env", "command", "time", "exec", "nohup"}
ASSIGNMENT = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", re.S)


def isolated(env):
    build = env.get("MIX_BUILD_PATH", "")
    if build and not build.rstrip("/").endswith("_build/dev"):
        return True
    return env.get("MIX_ENV", "dev") in ISOLATED_ENVS


def builds_dev(words, env):
    """Whether one simple command builds :dev, given the variables set before it."""
    env = dict(env)
    while words and (match := ASSIGNMENT.match(words[0])):
        env[match.group(1)] = match.group(2)
        words = words[1:]
    while words and words[0] in WRAPPERS:
        words = words[1:]
        while words and (words[0].startswith("-") or words[0].isdigit()):
            words = words[1:]
        while words and (match := ASSIGNMENT.match(words[0])):
            env[match.group(1)] = match.group(2)
            words = words[1:]
    if not words or isolated(env):
        return False
    if words[0] == "iex":
        return "mix" in words and "-S" in words
    if words[0] != "mix":
        return False
    task = next((w for w in words[1:] if not w.startswith("-")), None)
    return task is None or BUILDS.fullmatch(task) is not None


def commands(command):
    """The simple commands in a line, split on ;, &&, || and | outside quotes."""
    try:
        lexer = shlex.shlex(command.replace("\n", ";"), posix=True, punctuation_chars=";&|")
        lexer.whitespace_split = True
        words = list(lexer)
    except ValueError:
        # Unbalanced quotes (a heredoc's apostrophe): fall back to reading line by line.
        for line in command.splitlines():
            try:
                yield from commands_of(shlex.split(line, comments=True))
            except ValueError:
                continue
        return
    yield from commands_of(words)


def commands_of(words):
    current = []
    for word in words:
        if word and set(word) <= set(";&|"):
            yield current
            current = []
        else:
            current.append(word)
    yield current


def refused(command):
    env = {}
    for words in commands(command):
        # `export MIX_ENV=test` holds for the rest of the command.
        if words[:1] == ["export"]:
            for word in words[1:]:
                if match := ASSIGNMENT.match(word):
                    env[match.group(1)] = match.group(2)
            continue
        if builds_dev(words, env):
            return True
    return False


def dev_port(root):
    if os.environ.get("PORT", "").isdigit():
        return int(os.environ["PORT"])
    try:
        with open(os.path.join(root, ".env")) as dotenv:
            for line in dotenv:
                if match := re.match(r"\s*(?:export\s+)?PORT=['\"]?(\d+)", line):
                    return int(match.group(1))
    except OSError:
        pass
    return 4000


def listening(port):
    with socket.socket() as probe:
        probe.settimeout(0.2)
        return probe.connect_ex(("127.0.0.1", port)) == 0


def main():
    command = json.load(sys.stdin).get("tool_input", {}).get("command", "")
    if not refused(command):
        return 0

    port = dev_port(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd()))
    if not listening(port):
        return 0

    print(
        f"Refused: the dev server is listening on :{port}, and this would compile into "
        "_build/dev beside it, which has corrupted beams before (AGENTS.md, Working here). "
        "Prefix MIX_ENV=test (or set MIX_BUILD_PATH), or ask the running app through "
        "Tidewave's project_eval.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
