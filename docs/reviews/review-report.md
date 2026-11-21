# Design Review Report (Elephant-Goldfish)

How the plans in `docs/` were reviewed, what the reviewers found, and what changed.

Method: [Elephant-Goldfish Model](https://github.com/google/elephant-goldfish-model) (Google, Apache-2.0).
The **Elephant** (the drafting session, with full context) wrote the docs. **Goldfish** reviewers are fresh agents with no chat history. Each read only the docs and its own reviewer persona from the EGM repo. The author (you) makes the final calls.

- **Target:** `docs/DESIGN.md` (with `GDD.md`, `SYSTEMS.md`, `ROADMAP.md` as context)
- **Date:** 2026-11-21
- **Mode:** consolidated (no stops between stages), two rounds of fixes

## Stages run

| Stage | Reviewers | Result |
|---|---|---|
| 5. Zoom out | Skeptical Architect, Inventive Catalyst | 0 blockers, 9 major, 9 nits |
| 6. Comprehension | Fresh reader, DESIGN.md only | 8 major, 6 nits |
| 7. Critique | Design Critic, Structural, Style | 2 blockers, 22 major, 30 nits |
| *Fix round 1* | Elephant | DESIGN.md rewritten, SYSTEMS/ROADMAP/GDD aligned |
| 8. Zoom out (again) | Skeptical Architect | Pass with changes: 7 major, 10 nits |
| 9. Implementation readiness | Implementation Readiness | 3 blockers, 11 major, 6 nits |
| *Fix round 2* | Elephant | Detailed plan rewritten, M0 skeleton built |

Skipped: the "codebase details" reviewer in stage 9 (no code existed yet to check against).

## Consolidated actions

Priority: 🔴 Blocker, 🟡 Major, 🟢 Nit. Status: ✅ fixed, ⚖️ kept with reason.

### Architecture

| # | Finding | Raised by | Status |
|---|---|---|---|
| A1 | 🔴 No Risks and Mitigations section | Structural, Design Critic | ✅ Risk table with triggers |
| A2 | 🟡 Two pathfinding models (flow field + nav mesh) that can drift | Zoom Out, Catalyst, Critic | ✅ Citizens use `AStarGrid2D` built from the same Grid |
| A3 | 🟡 Flow-field goals unclear; citizens as goals would keep it stale; walls as goals break gate routing | Comprehension, Catalyst, Critic | ✅ Goals = non-wall buildings only. Zombies chase citizens locally |
| A4 | 🟡 Wall cost tied to current health causes rebuild storms | Catalyst, Critic | ✅ Cost by wall tier; damage never dirties the grid |
| A5 | 🟡 0.5 s rate limit contradicts "updates within 0.5 s" | Comprehension, Catalyst, Critic | ✅ One rebuild per frame, no throttle until the benchmark asks |
| A6 | 🟡 Worker-thread rebuild planned before any profiling, with race risks | Zoom Out, Critic | ✅ M1 is single-threaded; threading rules recorded in Risks |
| A7 | 🟡 Swap-remove makes zombie indices unstable | Critic | ✅ Index rule: valid one frame only, deaths removed at frame end |
| A8 | 🟡 Per-frame zombie cost not broken down; MultiMesh per-instance calls are slow | Catalyst, Critic | ✅ Budget split (8 ms field, 6 ms zombies), bulk buffer, flat hash |
| A9 | 🟡 High-rate combat events through the global EventBus | Catalyst | ✅ Combat never goes through EventBus |
| A10 | 🟡 `grid_changed` on the global bus with unused payload and backwards throttle | Zoom Out (stage 8) | ✅ Grid signals World directly; one rebuild per frame |
| A11 | 🟡 Autoload rule contradicted by GameClock/Economy holding per-game state | Zoom Out (stage 8) | ⚖️ Kept as autoloads (easy access for UI and tests); rule rewritten honestly; `reset()` on new game |
| A12 | 🟡 "Exact restore" promise needs determinism the design can't give | Zoom Out (stage 8), Catalyst | ✅ Promise narrowed; per-system seeded RNG rule added; exact replay is a non-goal |
| A13 | 🟡 Save format undefined for packed arrays and RNG | Catalyst, Critic | ✅ JSON + base64 `var_to_bytes`, never load saves as Resources |
| A14 | 🟡 Per-noise flow fields and a second "NoiseBus" contradict the one-field design | Zoom Out (stage 8) | ✅ `ZombieManager.alert()`, zombies steer straight to the noise |
| A15 | 🟡 Tower targets held across frames break the index rule | Zoom Out (stage 8) | ✅ Towers query and fire in the same frame |
| A16 | 🟢 Type-specific movement (crawlers, runners) not addressed | Zoom Out (stage 8) | ✅ Lives in the blocked check, one shared field |
| A17 | 🟢 Many 2D lights on the Compatibility renderer untested | Critic | ✅ Light test scene in M1 |

### Plan completeness

| # | Finding | Raised by | Status |
|---|---|---|---|
| P1 | 🔴 M0 depended on M1 files and could not run | Readiness | ✅ M0 built and tested: placeholder map, clock, CI |
| P2 | 🔴 "Hand-painted map" can't be done by Claude Code and was unspecified | Readiness | ✅ Generated starter map from `MapDef`; terrain cost in TileSet custom data |
| P3 | 🔴 Flow-field rules (diagonals, corners, ties, sentinels) open | Readiness | ✅ Exact rules + worked 3x3 example |
| P4 | 🟡 M1 plan missed camera, map, Command Post, game over, world scene | Zoom Out, Comprehension | ✅ All added |
| P5 | 🟡 Balance numbers hard-coded in scripts | Zoom Out, Comprehension, Readiness | ✅ `BalanceDef`, `MapDef`, Def table with first values |
| P6 | 🟡 Clock semantics, building API, BuildTool API, ZombieManager details, restart sequence open | Readiness | ✅ Written into the plan |
| P7 | 🟡 Horde spawned inside impassable border | Readiness | ✅ Spawns on the passable ring inside the border |
| P8 | 🟡 HUD listing `data/buildings/` breaks in exported builds | Readiness | ✅ `BuildCatalog` resource |
| P9 | 🟡 Test runner contract and test cases vague | Readiness, Zoom Out | ✅ Runner built; test table with inputs and expected results |
| P10 | 🟡 CI unspecified; import exit code doesn't catch script errors | Readiness, Comprehension | ✅ Workflow built; fails on error lines in the log |
| P11 | 🟢 Custom test runner vs GUT/gdUnit4 | Zoom Out | ⚖️ Kept: ~40 lines, no addon to vendor, runs headless |

### Docs and style

| # | Finding | Raised by | Status |
|---|---|---|---|
| D1 | 🟡 Claims stated as facts without measurement | Style, Critic | ✅ Marked as hypotheses checked by the M1 benchmark |
| D2 | 🟡 Untestable goals ("easy", "clear") | Style, Critic | ✅ Measurable checks |
| D3 | 🟡 Alternatives missing (C# core, nav mesh, binary saves) and weak reasons | Structural, Critic | ✅ Added, grouped by decision |
| D4 | 🟡 Section order and heading levels | Structural | ✅ Fixed |
| D5 | 🟡 Cross-doc mismatches (zombie counts, signals, tick rate, wall tiers, art timing, stone resource) | All | ✅ Aligned |
| D6 | 🟢 Glossary missing; milestones not defined in DESIGN | Comprehension | ✅ Added |
| D7 | 🟢 Colour-only information conflicts with accessibility goal | Zoom Out (stage 8) | ✅ Cross icon on blocked ghost; zombie types differ by shape |
| D8 | 🟢 Win condition and endless mode not scheduled | Zoom Out (stage 8) | ✅ Added to M5 |

## Left for the author

- **2D vs 3D.** The plan is 2D top-down. You have Three.js experience; if you want 3D, that changes art, camera and performance plans.
- **Map size** (128 x 128) is decided after the M1 benchmark.
- **Art style and game name** before M6.

## Next review

Run stage 9 (implementation readiness) again before M2 starts, on a new M2 plan section.
