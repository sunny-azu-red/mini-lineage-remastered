---
name: commit-sweep
description: Sweep a change for dead code, stale docs and leftovers before it is committed, then stamp it. Use before every git commit (a hook refuses the commit until this skill has stamped the change), and whenever asked whether anything is left to clean up after a feature, any dead code or stale markdown.
---

# The commit sweep

What a change leaves behind is found by reading the change, never by remembering it. AGENTS.md
holds each rule; this is where a change tends to leave them broken. Fix what is plainly the
change's own leftover; ask about anything that is a judgment call.

## 1. Read the change

`git status --short` and `git diff HEAD`, plus every untracked file in full. The sweep covers
what will be committed, not only this session's edits.

## 2. What it removed or renamed, both ways

Grep across `lib`, `test`, `e2e`, `assets`, `config`, `priv`, `docs`, `AGENTS.md`, `README.md`
and `.claude`, never `legacy/`, `deps` or `_build`.

- **What pointed at it.** From the `-` lines, list every name that no longer appears on a `+` line:
  a function, module, attribute, assign, CSS class, element id, `data-` attribute, route, sort key,
  fixture, flash, and any word the player reads (a column header, a button, a label). A hit is
  stale unless it names something else (a Fallen Orc is a monster).
- **What it pointed at.** List everything the removed lines used: each function they called, module
  they aliased, class or id they wrote, assign they read, fixture, test helper, config key, hook,
  CSS custom property and dependency. Whatever has no user left besides its own definition, its
  tests and its docs is orphaned: remove it, then sweep what *it* used the same way. A rule in
  `Rules` and `docs/rules.md` is the exception, since a rule may be written ahead of what uses it.

## 3. What it added

Each new function, component, hook, CSS class, fixture and test helper is used somewhere other
than its definition. A public function called only from tests is dead.

The compiler finds unused private functions, aliases, imports and variables through `mix
precommit`, in either direction; the rest of steps 2 and 3 is the grep's.

## 4. The docs that describe what moved

- `AGENTS.md`: a new component, hook or shared control is written in by the same change; a rule
  whose example or named file changed says the new one.
- `docs/design.md` for a class, colour or look; `docs/rules.md` with `rules_test.exs` for a rule;
  `docs/roadmap.md` for where a system stands; `README.md` for a command or debug key.
- The touched modules' moduledocs and comments: one that narrates the change or how a bug was
  found goes, one citing a measurement the change moved expires.

## 5. Leftovers

`IO.inspect`, `dbg`, `console.log`, commented-out code, a `TODO` the change added, a test
narrowed with `@tag :only`, `.only` or `--only`, and scratch files inside the repo (they belong in
the scratchpad).

## 6. Report, then stamp

Tell the user what was found and fixed and what is left for them to decide. Then, after every fix
and as the last step, run from the repo root

```
python3 .claude/hooks/commit_sweep.py --stamp
```

which lets a `git commit` of the change as it stands through. Any edit afterwards voids it. The
shell has no `$CLAUDE_PROJECT_DIR` (only the hook's own run does), and the hook reads a whole
command before any of it runs, so the stamp is a command of its own, never chained to the commit.
