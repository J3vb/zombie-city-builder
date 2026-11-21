# CLAUDE.md

Guide for Claude Code working in this repo.

## Project

2D top-down zombie city builder. Godot 4.5, GDScript only.
Read before big changes: `docs/DESIGN.md` (architecture), `docs/SYSTEMS.md` (per-system spec), `docs/ROADMAP.md` (milestones). Story and names for text: `docs/LORE.md`.

## The owner

- Self-taught, mostly writes Python and SQL. Dyslexic.
- Keep explanations short and plain. No jargon without a one-line explanation.
- Ask before big rewrites or changing the architecture in `docs/DESIGN.md`.

## Commands

```sh
godot --headless --import                              # import, catches parse errors
godot --headless --script res://tests/run_tests.gd     # unit tests, exit 1 on failure
gdlint scripts tests
gdformat scripts tests                                 # auto-format
```

Run tests and lint before every commit.

## Code rules

- Static types everywhere: `var x: int`, `func f(a: int) -> void`.
- One class per file. Files under 300 lines (gdlint enforces this).
- **No gameplay numbers in scripts.** Put them in `data/balance.tres` (`BalanceDef`) or a `*Def` resource in `data/`.
- Autoloads: `EventBus`, `GameClock`, `Economy` (later `SaveManager`, `AudioManager`, `Settings`). `GameClock` and `Economy` hold per-game state, so a new game must call their `reset()`. All other game systems live under the World scene.
- `EventBus` is for low-rate events only (a few per second). Combat (hits, shots) never goes through it.
- Zombies are rows in packed arrays inside `ZombieManager`, not nodes. Never store a zombie index across frames.
- `Grid` is the single source of truth for what stands where and tile costs. Flow field and citizen A* read from it.
- All randomness goes through a system's own seeded `RandomNumberGenerator`. No global `randf()`/`randi()`.
- Never load save files as Resources (`.tres`/`.res`). JSON only.
- Minimal comments. A `##` doc line on top of each script saying what it is for.

## Gotchas

- A script error inside a test stops that test silently. CI fails on any `SCRIPT ERROR` line, so check the full test output, not only the pass count.
- Scripts that are part of the World scene should `load()` Def resources at runtime instead of `preload()`ing them if they are also used as typed function arguments. Preloading during the scene's compile created a second copy of the `ZombieDef` script, and typed checks then failed.
- Tool scripts run with `--script` can't use autoload names directly; use `root.get_node("GameClock")`.

## Tests

- Put tests in `tests/test_<thing>.gd`, extend `TestCase`, name methods `test_*`.
- Use `assert_true` and `assert_eq`.
- Every new system gets at least one test for its core logic.

## Workflow

- Work on a branch, open a PR to `main`. CI must be green.
- One GitHub issue per roadmap bullet. Reference it in the PR (`Closes #12`).
- For new systems, update `docs/SYSTEMS.md` if behaviour changes from the spec.
- Design changes: draft in `docs/DESIGN.md`, review with fresh-context reviewers (Elephant-Goldfish method, reports in `docs/reviews/`), then build.

EGM artifact directory: docs/reviews
