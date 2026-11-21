# Review Report: M1.5 3D view and building upgrades (Elephant-Goldfish)

- **Target:** `docs/DESIGN.md`, M1.5 parts (3D view, Building upgrades, Art direction, View alternatives, 3D risks, M1.5 detailed plan). Context: GDD, ROADMAP, CLAUDE.md, current code.
- **Date:** 2026-11-21
- **Why:** after playing M1 the owner asked for a Cities: Skylines / SimCity feel, buildings that upgrade, full 3D, and a dark gritty mid-apocalypse look.
- **Reviewers (fresh context, read-only):** Skeptical Architect (zoom out), Implementation Readiness (checked the plan against the code), Design Critic.

## Results

| Reviewer | Verdict | Blockers | Major | Nits |
|---|---|---|---|---|
| Skeptical Architect | Direction sound, revise before PR A | 1 | 6 | 5 |
| Implementation Readiness | PR A not buildable as written | 3 | 13 | 4 |
| Implementation Readiness, round 2 | PR A almost ready | 0 | 6 | 8 |
| Design Critic | Sim/view split holds; 5 major gaps | 0 | 7 | 6 |

## Consolidated actions

Priority: 🔴 Blocker, 🟡 Major, 🟢 Nit. Status: ✅ fixed in the plan, ⚖️ kept with reason, ❓ asked the owner.

| # | Finding | Raised by | Status |
|---|---|---|---|
| R1 | 🔴 3D test scene and camera script not in the repo; gate undefined; dead report link | All three | ✅ Bench merged (#58) as "PR 0"; gate defined; this report added |
| R2 | 🔴 PR A left 2D code (zombies, debug overlay, NightTint, Camera2D calls) that breaks under a 3D World | Readiness | ✅ Zombies and DayNight moved into PR A; overlay arrows removed in A, back in B; NightTint deleted in A |
| R3 | 🔴 World `_ready` order, `tile_size()`, camera start undefined | Readiness, Architect | ✅ A5 spells out the order and every accessor |
| R4 | 🟡 Bench measures draw cost only, not the real zombie update; no re-measure after art | Architect, Critic | ✅ Exported ARM64 build re-measured after PR A and PR C |
| R5 | 🟡 One terrain mesh hits the Compatibility per-object light limit | Architect, Critic | ✅ Terrain in 16 x 16 tile chunks |
| R6 | 🟡 Zoning question could make the upgrade PR a dead end | Architect, Critic | ❓ Asked the owner 2026-11-21; must be answered before PR B |
| R7 | 🟡 Texture and material generator scripts are throwaway work | Architect | ✅ Materials use Godot's `NoiseTexture2D`; only the zombie mesh keeps a small tool (a MultiMesh needs one mesh) |
| R8 | 🟡 Upgrade rules split between Building and BuildTool | Architect | ✅ Rules on `Building`; BuildTool only forwards the UI command |
| R9 | 🟡 `spent`, demolish refund and `capacity` serve M2 features | Architect | ✅ Moved to M2 |
| R10 | 🟡 Two reference machines; M1 numbers never measured on the ARM laptop | Architect, Critic | ✅ ARM laptop is the M1.5 reference; 60 fps mid-range target rechecked in M6 |
| R11 | 🟡 No income in M1.5, so upgrades can't be played; instant upgrade works as a mid-attack heal | Critic | ✅ Temporary `daily_income`; no upgrades at night |
| R12 | 🟡 Ground-plane picking selects the wrong building behind tall roofs | Critic | ✅ Selection tests footprint boxes first; test at 30 degrees |
| R13 | 🟡 "Readable wins over mood" had no rule or check | Critic | ✅ Minimum ambient, maximum fog, zombie night emission, night screenshot check |
| R14 | 🟡 Grid, BuildTool, Building, camera input, terrain mesh, DayNight, InfoPanel wiring underspecified | Readiness | ✅ A1 to B6 rewritten with types, values, files and callers |
| R15 | 🟡 Integer rounding bug in the health-fraction rule | Readiness | ✅ `roundi(float(health) * new_max / old_max)` |
| R16 | 🟡 Camera test impossible inside the pitch clamp | Readiness | ✅ Static `ray_to_ground()` tested directly |
| R17 | 🟡 Right mouse both tilts and cancels | Readiness | ✅ Tilt moved to R/F |
| R18 | 🟢 Bob phase used the row index (jumps after swap-remove) | Critic, Readiness | ✅ `_phase` array |
| R19 | 🟢 Formula numbers in the plan instead of Defs | Architect, Readiness | ✅ In `ZombieDef` / `LightingDef` / `BalanceDef` |
| R20 | 🟢 Level-1 health changed M1 balance | Critic, Readiness | ✅ Level 1 keeps M1 values |
| R21 | 🟢 Zombies casting shadows | Critic | ✅ `cast_shadow = off` |
| R22 | 🟢 Exact float compare in tests; "upgrade three times" wording; lights' gameplay role in GDD; occupant typing; file deletions; signal typing | Various | ✅ Fixed |

## Round 2 (Implementation Readiness, PR A only)

Verdict: almost ready, 0 blockers, 6 major, 8 nits. All fixed in the plan:

- Zombie mesh source, capsule ground offset (`mesh_y_offset`), RNG seed, buffer format.
- DayNight: `apply(t)` API, elevation formula, axes, moon direction, ambient as energy, Environment settings in the scene.
- CameraRig: full API (`set_bounds`, `pan`, `rotate_by`, `tilt_by`, `zoom_by`, `_clamp`), positive pitch, fov and far.
- `test_grid` uses `Building.new()`; terrain normals and side-quad facing; health bar as billboard quads.
- Nits: `_ready` order completed, DebugOverlay root a `Node`, `MapDef.map_seed` (not `seed`), first lighting values, ghost hidden on a missed ray, heading 0 = +Z, SYSTEMS.md listed, owner of `zombie_night_emission`.

## Left for the owner

- **Zoning or hand placement** (R6), before PR B.
- **FPS numbers** from the 3D test on the ARM laptop, before PR A.
