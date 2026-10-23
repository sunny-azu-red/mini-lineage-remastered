---
name: balance-study
description: Measure a change to the game's balance with bench/ladder.exs and bench/compare.exs, against the bar, before and after. Use when asked to run the benchmarks or the bench, to measure, check or study balance, to compare two builds, and on your own after any change to a fight's numbers, a monster, an item, a skill, a price, a reward (EXP, SP, Adena), the private server rates, the trainer's list, or bench/ladder.exs itself.
---

# Balance study

A change that moves a fight is measured, never guessed. The bar and the calls already made are in
`docs/direction.md` (Balance); read them first. Never reason from the dev database.

Every block below runs from the repo root and leaves the shell there: variables do not survive
between shell calls, so each block works its paths out again. Every Mix command carries
`MIX_ENV=test`, since the dev server is usually up and the guard hook refuses a `:dev` build.

## The rates

The game is balanced at rules §22's **private rates**, EXP and SP ×5 and Adena ×20, and the bar,
`docs/balance.md` and every reading are taken at them. Without them the game runs at retail's ×1.
The bench plays whatever `.env.test` sets (`EXP_RATE`, `SP_RATE`, `ADENA_RATE`), and each reading
opens with a `Rates:` line and keeps them in its JSON settings. Before reading one, check that line
says ×5, ×5 and ×20, and if it does not, fix `.env.test` from `.env.test.example` and run it again.
A change to the private rates themselves is a balance change like any other: measured before and
after, written into rules §22's table, every env file and both of `.github/workflows/ci.yml`'s jobs
in the same commit (`rules_test.exs` holds the table to `.env.example` and `.env.test.example`;
nothing checks CI's), and `docs/balance.md` rewritten from the reading.

## 1. Decide what to run

- **Which sets**: `--only "Human Fighter,Orc Mystic"`, the sets the change touches, since no set's
  runs read another's. The bar's spread is measured only across the sets in the reading, so add the
  current fastest and slowest sets too, or run them all when the change could move a set to either
  end. A change to something every set uses (the fight, a shared price) runs them all.
- **Routine or final**: `--matrix <prefix>` is 200 runs a path at three settings: `defaults` (rest
  to full, 20 potions), `harsh` (rest below half, none), `potions` (half, 20). `--final` adds
  `harsher` (30%, none) and is the reading `docs/balance.md` is rewritten from. A routine matrix of
  every set takes about 2 minutes on 8 cores and a final about 3; one set a fraction of that.
- Readings go in `tmp/bench/readings/` (git-ignored), never a scratchpad, which a restart wipes.

## 2. The baseline: the commit before the change

```bash
R=$PWD; W=$(dirname "$R")/$(basename "$R")-base   # beside the repo: live reload watches all of it
mkdir -p "$R/tmp/bench/readings"
git worktree remove --force "$W" 2>/dev/null; git worktree prune
git worktree add "$W" <commit before the change>   # HEAD if the change is uncommitted
(cd "$W" && ENV_FILE=$R/.env.test MIX_DEPS_PATH=$R/deps MIX_ENV=test nice -n 19 \
  mix run --no-start bench/ladder.exs --matrix "$R/tmp/bench/readings/<label>_base" --only "<sets>")
```

`ENV_FILE` hands the worktree the repo's `.env.test`, which git does not carry, so both readings play
the private rates; `compare.exs` refuses two taken at different rates. The first run compiles every
dependency into the worktree's own `_build/test`, which adds minutes.
If Mix asks for `deps.get` there, the base commit's `mix.lock` differs: stop and say so. Never run
`deps.get` with the shared `MIX_DEPS_PATH`, which would rewrite the deps under the running server.

## 3. The variant: the working tree

```bash
MIX_ENV=test nice -n 19 \
  mix run --no-start bench/ladder.exs --matrix "$PWD/tmp/bench/readings/<label>_after" --only "<sets>"
```

Use the same runs, top level and `--only` as the baseline. `compare.exs` refuses only a different
top level, rest, potions or rates, or a different count of runs; a set in one reading and not the other is
dropped without a word. Run the two one after the other, since each takes every scheduler.

## 4. Compare, setting by setting

```bash
for s in defaults harsh potions; do   # add harsher after --final
  echo "== $s"
  MIX_ENV=test mix run --no-start bench/compare.exs \
    tmp/bench/readings/<label>_base_$s.json tmp/bench/readings/<label>_after_$s.json
done
grep -h FLAG tmp/bench/readings/<label>_after_*.txt
```

Time is compared run for run, over runs that reached the top in both, so a run the change saves from
dying does not move a set's mean; with fewer than 10 such runs a set's change shows `-` and its time is
neither judged nor counted in the spread. Off-meta rows are never held to the bar, and their `FLAG: beats the meta` lines are only in
the matrix's `.txt` files, hence the grep: a build the rules let win is a rule to fix.

## 5. Report

- **Passes**: say so with the numbers that moved, set by set.
- **Fails**: stop. Report the failing rows and what they mean, and let the owner decide. Never tune
  a number quietly to get under the bar; a deliberate gap has been accepted before when it fits the
  design. A call made goes into `docs/direction.md`, under "Calls already made".

## 6. When the change is kept

- Take a `--final` reading of the build and rewrite `docs/balance.md` from what it prints: its
  "Measured on" paragraph names every rule the reading stands on.
- `git worktree remove --force "$(dirname "$PWD")/$(basename "$PWD")-base"`.

## Changing the bench itself

`bench/ladder.exs` plays the meta: its own weapon's line, a shield only beside a one-handed sword or
staff, each one-handed path again off-meta with the other shield choice. A cache or precomputed
table that speeds it must leave a 400-run `--final` reading byte-identical: diff each setting's
`.txt` against the one taken before.
