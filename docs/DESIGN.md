# Hold the Gates: Technical Design

*   **Author:** J3vb (drafted with Claude)
*   **Status:** M0 and M1 built. M1.5 (3D view and building upgrades) proposed, reviewed once, see [reviews](reviews/review-report.md) and [3D review](reviews/review-3d-report.md)
*   **Date:** 2026-11-21

## Overview

A 3D city builder set in a zombie outbreak, with a rotating city-builder camera like Cities: Skylines. Built in Godot 4.5 with GDScript.

The simulation stays on a flat 2D tile grid. Only the view is 3D (see "3D view" below).

The player:

*   builds a walled town,
*   runs an economy of named survivors,
*   sends scavenging teams outside,
*   defends against roaming zombies and big hordes.

This document is the technical plan. Related docs:

*   [GDD.md](GDD.md): what the game is (rules, content, feel).
*   [SYSTEMS.md](SYSTEMS.md): every system, one section each.
*   [ROADMAP.md](ROADMAP.md): milestones M0 to M6.

### Milestones in one line each

| Milestone | Result |
|---|---|
| M0 | Project runs (placeholder map + clock) and passes CI. **Done.** |
| M1 | Prototype: place buildings, a horde attacks, game over. **Done (2D).** |
| M1.5 | 3D view, building upgrades, dark gritty look |
| M2 | Citizens, jobs, production |
| M3 | Walls, gates, towers, horde nights |
| M4 | Expeditions, infection, checkpoints, power |
| M5 | All zombie types, tech tree, save/load, settings, win/endless |
| M6 | Art, audio, tutorial, release builds |

### Glossary

*   **Command Post:** the town hall. If it falls, the game is over.
*   **Citizen:** a named survivor. Has health, hunger, morale, a skill and a job.
*   **Scrap:** salvaged metal. Main material for walls and towers.
*   **Checkpoint:** a gate with a waiting pen where newcomers are inspected.
*   **Infection timer:** time left before an infected citizen turns into a zombie.
*   **Horde night:** a night when a large wave attacks (every 3rd night from M3).
*   **Flow field:** a map that stores, for every tile, which way to walk to reach the city.
*   **Def:** a data file (`.tres` Resource) holding numbers for one thing, for example `ZombieDef`.
*   **Sim space:** the flat 2D space the game logic runs in. Positions are `Vector2`, one tile is 32 sim units.
*   **View space:** the 3D scene the player sees. One tile is 4 metres. `World.to_view()` converts sim space to view space.
*   **Building level:** the upgrade stage of a building (for example Tent, Shack, Brick house). Each level has its own model, health and stats.

## Problem Statement

This game joins a city builder and a tower defense. The city economy pays for the defense, and the defense decides where the city can grow.

The hard technical part is scale. A horde needs hundreds of zombies on screen, all finding a path into a city whose walls change during play.

We expect one scene node plus one path query per zombie to be too slow for 500 zombies in GDScript. The M1 benchmark checks the chosen approach.

Proposed solution:

*   Zombies are rows in arrays, not scene nodes.
*   All zombies are drawn in one batch (`MultiMeshInstance3D` from M1.5).
*   All zombies steer by one shared flow field, rebuilt only when the map changes.
*   Citizens are few (max 100), so they are simple nodes with grid A* pathfinding.

## Goals

*   **M1 performance:** see "Performance budget" under Non-Functional Requirements.
*   **Full core loop** (build, gather, manage, defend) by M4. Check: the M4 "done when" line in ROADMAP.md.
*   **Data, not code:** every gameplay number lives in a `.tres` file under `data/`. Check: rule in CLAUDE.md, checked in review.
*   **Easy to work on:** scripts under 300 lines (gdlint), one class per file, CI runs lint, format check, import and tests on every push.
*   **Original:** our own design, names and art.

## Non-Goals

*   Multiplayer.
*   Hills and terrain height that affect gameplay. The ground is flat; height is only visual.
*   Physics-based units or ragdolls.
*   Skeletal animation for zombies (they are one batched mesh; see Risks).
*   Mobile or console builds.
*   Mod support.
*   Exact replay after loading a save (zombie movement is not deterministic).
*   Direct control of expedition teams.

## Critical User Journeys (CUJs)

### CUJ 1: Survive the first night (M1)

*   **Given**: a new game on the starter map with a Command Post and starting resources.
*   **When**: the player places houses and farms. Night falls and a horde spawns near the map edge.
*   **Then**: zombies follow the flow field to the nearest building and damage it. When the Command Post reaches 0 health, the game pauses and the game-over screen shows the day number reached.

### CUJ 2: Wall off the town (M3)

*   **Given**: a town with builders and enough scrap.
*   **When**: the player drags a wall line around the town and leaves one gate.
*   **Then**:
    *   With the gate open, zombies path through the gate, because it is the cheapest route.
    *   With the gate closed, zombies path to the wall or gate tile on the cheapest route. Barricades cost less to break than walls, so zombies prefer them.
    *   When a wall tile reaches 0 health, the flow field rebuilds that same frame and zombies path through that tile.

### CUJ 3: Hard choice at the checkpoint (M4)

*   **Given**: a checkpoint with a guard and a clinic.
*   **When**: three refugees arrive and the clinic flags one as infected.
*   **Then**: the player picks Accept, Quarantine or Turn away for each. An accepted infected refugee turns into a zombie inside the walls when their infection timer reaches 0.

### CUJ 4: Scavenging run (M4)

*   **Given**: four idle citizens and a known supermarket location.
*   **When**: the player sends two of them with gear.
*   **Then**: they leave through a gate, a timer runs, one text event asks a choice, and they return with loot. Each has a chance of injury or a bite (odds set in the location's `LocationDef`).

### CUJ 5: Save and continue (M5)

*   **Given**: a game on day 12 with walls, citizens and zombies on the map.
*   **When**: the player saves, quits and loads.
*   **Then**: every saved value matches its value before saving (floats within 0.001). Derived data (flow field, spatial hash) is rebuilt on load. Each system's RNG state is restored, so loading does not reroll known outcomes.

## Proposed Architecture

### Engine and renderer

*   Godot 4.5. CI pins the exact version (`GODOT_VERSION: 4.5.1-stable` in `.github/workflows/ci.yml`).
*   GDScript with static types everywhere.
*   Renderer: Compatibility. It runs on integrated GPUs. M4 adds many 2D lights, so M1 includes a light test (see Risks).

### Big picture

```text
 Autoloads
 +----------+  +-----------+  +---------+   later: SaveManager, AudioManager, Settings
 | EventBus |  | GameClock |  | Economy |
 +----------+  +-----------+  +---------+
      ^ low-rate signals: day/dusk/night started, building placed/destroyed, game over

 World scene (one per game; freed on new game or load)
 +---------------------------------------------------------------------------+
 |  Terrain (TileMapLayer)                                                   |
 |     |                                                                     |
 |     v                                                                     |
 |   Grid --changed--> World --build()--> FlowField (data object)            |
 |     |                                     |                               |
 |     |                     direction_at()  v                               |
 |     +---- building_at() ---------> ZombieManager <--spawn()-- HordeDirector|
 |     |                                                                     |
 |     +---- AStarGrid2D ----> Citizens (M2)          JobBoard (M2)          |
 |                                                                           |
 |  BuildTool, CameraRig, Buildings container, DebugOverlay                  |
 +---------------------------------------------------------------------------+
 HUD and GameOver screens sit next to World under Main.
```

### Patterns

*   **Grid is the single source of truth** for what stands where and what each tile costs to cross. The flow field (zombies) and `AStarGrid2D` (citizens, M2) are both built from it.
*   **Autoloads:** `EventBus`, `GameClock`, `Economy` (later `SaveManager`, `AudioManager`, `Settings`). `GameClock` and `Economy` hold per-game state, so a new game calls their `reset()`. Kept as autoloads because UI, buildings and tests reach them from anywhere.
*   **World-owned systems:** `Grid`, `ZombieManager`, `HordeDirector`, `BuildTool`, later `JobBoard`. Freed and recreated with World, so no reset code.
*   **EventBus is for low-rate events only** (a few per second): day/dusk/night started, building placed or destroyed, resource changed, game over. Combat (hits, shots) never goes through it. Grid changes go straight from Grid to World, not through the bus.
*   **UI rules:** UI reads state from EventBus signals and autoload getters. UI changes state only through this command list: `BuildTool.select()`, `BuildTool.clear()`, `GameClock.set_speed()`, `Main.new_game()`, and later gate, checkpoint and expedition commands.
*   **Data as Resources:** all `*Def` scripts live in `scripts/data/`, their `.tres` files in `data/`. The author edits numbers in the Godot inspector.
*   **Randomness:** each system owns its own seeded `RandomNumberGenerator`. No global `randf()`.

### 3D view (M1.5)

The owner chose a full 3D view with a city-builder camera (decided 2026-11-21, after M1).

*   **Logic stays 2D.** Grid, flow field, zombie movement, spatial hash and build rules keep working in sim space (`Vector2`, 32 units per tile). Their maths does not change for 3D.
*   **One definition of the conversion.** `World` owns `view_scale` (from `MapDef`, 0.125, so one tile = 4 m) and defines `to_view(p: Vector2) -> Vector3 = Vector3(p.x, 0, p.y) * view_scale` and `to_sim(v: Vector3) -> Vector2 = Vector2(v.x, v.z) / view_scale`. Systems may copy `view_scale` once at setup for hot loops (`ZombieManager`), but must use the same formula.
*   **Picking without physics.** `CameraRig.ray_to_ground(origin, dir)` intersects the mouse ray with the ground plane `y = 0`. For placing, that point gives the cell. For selecting, the ray is first tested against each building's footprint box (its height comes from its level), nearest hit wins, so clicking a tall roof selects that building and not the ground behind it.
*   **Terrain** is built in chunks of 16 x 16 tiles, one `ArrayMesh` each (vertex colours, small per-tile shade change). Chunks keep each mesh under the Compatibility renderer's per-object light limit and help culling. Water is drawn 0.3 m lower, with side quads so there are no gaps. The `TileMapLayer` is removed.
*   **Buildings** are `Node3D`. Each building level has its own look. The footprint never changes between levels, so upgrades never touch the Grid or the flow field.
*   **Zombies** are drawn by one `MultiMeshInstance3D` (shadows off). Each zombie turns towards where it walks and bobs a little, so the crowd does not look frozen.
*   **Camera:** pan (WASD, screen edges), rotate (Q/E, middle mouse drag), zoom (wheel), tilt (R/F; right mouse stays "cancel"), pitch 30 to 75 degrees, the point it looks at kept inside the map.
*   **Light:** a `DayNight` node moves the sun and changes light colour, fog and ambient light from `GameClock.time_of_day` (curves in `LightingDef`). It replaces the 2D `NightTint`. Lights are visual only until floodlights matter for gameplay (M3/M4).
*   **Renderer:** Compatibility, kept for low-end laptops. The owner's Windows ARM laptop is the reference machine for M1.5.
*   **3D test scene** (`scenes/tests/bench_3d.tscn`, merged in #58, exported with the "Windows ARM64 3D bench" preset): walled town, 30 street lights, shadows, 500 to 2000 zombies in one MultiMesh. It measures draw cost only (its zombies walk straight to the centre).

### Building upgrades (M1.5)

*   `BuildingDef.levels: Array[BuildingLevelDef]`. Level 1 is what you place; its cost is the placement cost.
*   Rule: every level of a building has the same footprint.
*   **The rules live on `Building`** (`upgrade_blocker() -> String`, `upgrade() -> bool`), so M2's job board can call them too. `BuildTool.upgrade(building)` is only the UI command and calls `building.upgrade()`.
*   **Allowed when:** a next level exists, it is not night (`GameClock.is_night()` is false), `GameClock.day >= next.min_day`, and `Economy.can_afford(next.upgrade_cost)`. Blocking at night stops upgrades being used as an instant heal during an attack.
*   **On success:** spend, `level += 1`, keep the same health fraction (`health = roundi(float(health) * new_max / old_max)`), swap the look, emit `EventBus.building_upgraded(building)`. On failure nothing changes.
*   Upgrades are instant in M1.5. From M2, an upgrade becomes a construction job for builders, and level stats like beds and storage get effects.
*   **Temporary income:** M1 has no production, so M1.5 adds a flat `daily_income` (`BalanceDef`) paid at each `day_started`. M2 replaces it with real production. Without it, one house upgrade would eat the whole start stock.
*   **Selecting:** with no building chosen in the build bar, clicking a building selects it and opens the `InfoPanel`. Clicking empty ground, pressing Esc, or choosing a build-bar entry clears the selection.

### Art direction

Dark and gritty, mid-apocalypse (owner, 2026-11-21).

*   **Palette:** desaturated olive, brown, grey and rust. Accents: fire orange (light sources), blood red, sickly green-grey for zombies.
*   **Mood:** low sun, fog, long dusk, dark nights. Wrecked cars, rubble, dead trees, boarded windows, scrap walls.
*   **Readable chaos (pillar 4) wins over mood, as hard rules:**
    *   `LightingDef` has a minimum ambient light level and a maximum fog density near the camera.
    *   At night zombies get a faint emissive tint (strength in `LightingDef`), so they read against the dark ground.
    *   Damaged buildings show a health bar; the selected building shows an outline.
    *   UI text is never dark on dark.
    *   Check before each art PR merges: a night screenshot at 30 degrees pitch where every zombie group and every damaged building is visible.
*   **Upgrades must be visible:** each level is taller or more solid than the last (tent, then shack, then brick house).
*   **How the art is made until M6:** low-poly models built in Godot scenes from simple shapes (boxes, prisms, cylinders) with a few shared materials that use Godot's built-in `NoiseTexture2D` for grime (no texture generator script). In M6 they are replaced by Blender models or restyled CC0 kits (licence checked per kit).

### Zombies as data

*   `ZombieManager` holds parallel packed arrays: position, health, type, state, attack cooldown.
*   **Index rule:** a zombie's row index is only valid inside the current frame. Nothing stores an index across frames. `kill()` queues a death; deaths are removed at the end of the frame with swap-remove.
*   **Public API (kept stable so the core can be swapped to C# later):** `spawn(pos, def) -> bool`, `damage(index, amount)`, `kill(index)`, `query(pos, radius, out) -> int`, `alert(pos, radius)` (M3), `count() -> int`, `to_dict()` / `from_dict()` (M5).
*   **Drawing:** one `MultiMeshInstance2D` sized to `max_zombies` at start. Each frame writes all transforms in one bulk call and sets `visible_instance_count`.
*   **Spatial hash:** flat arrays reused every frame. `query()` writes into a caller-owned buffer.
*   Zombies spawn in batches over a few frames (batch size in `BalanceDef`).

### Zombie movement and attacks

Each frame (in `_process`, using `delta * GameClock.speed`; nothing moves at speed 0), for each zombie:

1.  **Chase (M2):** if a citizen is within the chase radius, steer straight at it.
2.  **Flow step:** otherwise read the direction of the current tile. If there is none (unreachable), steer towards the Command Post.
3.  **Blocked check:** look at the tile half a tile ahead. If it is blocked (building, wall, closed gate), stop and attack it on a cooldown via `Grid.building_at(cell).take_damage()`. Zombie types change this check only (for example, a Crawler treats barricades as open). There is one flow field for all types.
4.  **Separation:** a small push away from nearby zombies.
5.  **Clamp:** a zombie never ends a step inside a blocked tile, and moves at most half a tile per step (long frames are split). Crowding at gates and breaches is accepted: zombies queue and push.

### Citizens (M2)

*   `Node2D` nodes (no physics bodies), max 100.
*   Pathfinding with Godot `AStarGrid2D`. `Grid` keeps it up to date: buildings and walls solid, gates follow open/closed.
*   Separation push between citizens. No navigation mesh, so nothing to rebake.

### Save files (M5)

*   One JSON file per slot, with `version`, per-system RNG states, and one section per system.
*   Packed arrays are stored as base64 of `var_to_bytes()`.
*   Saves are never loaded as Godot Resources (`.tres`/`.res`), because those can contain scripts.

### Folders

```text
scenes/      main, ui, world, buildings, units, tests
scripts/     autoload, data (all *Def), main, world, buildings, units, systems, ui
data/        balance.tres, maps/, buildings/, zombies/
assets/      sprites, tiles, audio, fonts
tests/       test_case.gd, run_tests.gd, test_*.gd, bench_*.gd
docs/        design docs, reviews/
```

## Alternatives Considered

### Engine choice

#### Alternative A: Unity

*   **Pros**: large tutorial base and asset store. C#. DOTS (Unity's mass-unit system).
*   **Cons**: the 2023 runtime-fee change reduced trust. Larger install. No Python-like language.
*   **Reason for Rejection**: Godot is free, open source, a small download, and GDScript is close to Python, which the author knows.

#### Alternative B: Three.js / web stack

*   **Pros**: the author knows Three.js. Runs in a browser.
*   **Missing**: editor, UI system, tilemaps, pathfinding, audio buses, export pipeline.
*   **Reason for Rejection**: a city builder needs a lot of UI and tools. Godot has these built in.

### View

#### Alternative C: keep 2D top-down (the M1 view)

*   **Pros**: already built, cheapest art, fastest.
*   **Cons**: looks like a map, not a city. Upgrades are hard to show.
*   **Reason for Rejection**: the owner wants a Cities: Skylines / SimCity feel after playing M1.

#### Alternative C2: 2D isometric (SimCity 2000/3000 style)

*   **Pros**: city look with less performance risk; sprites instead of models.
*   **Cons**: fixed camera angle (no rotation), every building needs sprites drawn for the angle, depth sorting work.
*   **Reason for Rejection**: the owner chose full 3D. Kept as the fallback if the 3D test fails on the target laptop.

#### Alternative C3: move the simulation to metres in 3D space

*   **Pros**: one coordinate system everywhere.
*   **Cons**: touches every Def, test and system that M1 finished, for no gameplay gain.
*   **Reason for Rejection**: the 2D sim plus one `to_view()` conversion keeps M1's tested logic unchanged.

### Crowd simulation

#### Alternative D: each zombie is a node with NavigationAgent2D

*   **Pros**: less code, uses built-in Godot features.
*   **Cons**: we expect hundreds of nodes and path queries to cost too much in GDScript, and paths go stale when walls change.
*   **Reason for Rejection**: hypothesis; the M1 benchmark checks the chosen approach.

#### Alternative E: zombie core in C# or GDExtension from day one

*   **Pros**: much faster loops.
*   **Cons**: second language and build step, harder for the author, slower to iterate.
*   **Reason for Rejection**: deferred behind the stable `ZombieManager` API. Revisit if M1 profiling misses the budget.

#### Alternative F: navigation mesh for citizens

*   **Pros**: smooth paths, built-in avoidance.
*   **Cons**: must rebake when walls change; a second walkability model that can disagree with the grid.
*   **Reason for Rejection**: `AStarGrid2D` reads the same grid as the flow field.

### Saving

#### Alternative G: binary saves (`FileAccess.store_var`)

*   **Pros**: smaller, exact types.
*   **Cons**: not readable, harder to debug and migrate.
*   **Reason for Rejection**: a JSON envelope with base64 blocks for big arrays gives both.

## Risks and Mitigations

| Risk | Impact | Mitigation | When to revisit |
|---|---|---|---|
| Flow-field rebuild too slow in GDScript | Frame drops when the map changes | Bucket queue; at most one rebuild per frame; M1 benchmark. **Triggered:** first measure was 25 ms (Godot 4.5.1, headless), so rebuilds run on a worker thread (next row) | Rebuild > 8 ms at 128 x 128 |
| Many walls break in one horde | Many rebuilds | One rebuild per frame covers all changes that frame | M3 playtest |
| Rebuild moved to a worker thread causes data races | Wrong paths, crashes | Worker reads a copy of the cost array, writes a back buffer, main thread swaps; a change during a build sets "rebuild again" | Active since the M1 benchmark |
| Zombie update too slow at 500 | Below 60 fps | Bulk MultiMesh buffer, flat spatial hash | M1: zombie update > 6 ms |
| GDScript can't reach the target | Scope cut | Swap `ZombieManager` core to C#/GDExtension behind the same API | After M1 profile |
| Crowds jam at gates and breaches | Zombies stuck | Clamp + separation; accept queueing; tune in M3 | M3 playtest |
| Many 2D lights slow on the Compatibility renderer | Night runs slow | M1 light test scene: 30 lights + 500 zombies. Replaced by the 3D test scene in M1.5 | M1 |
| 3D too slow on the owner's low-end ARM laptop | Unplayable on the test machine | 3D test scene before the rebuild (draw cost only); exported ARM64 build re-measured after PR A (real zombie update) and PR C (final art); shadow and light settings; fall back to isometric 2D (Alternative C2) | Fewer than 30 fps with 500 zombies at any check |
| Compatibility renderer light limits (8 lights per object by default) | Night lights pop or look wrong | Terrain in 16 x 16 tile chunks; few real lights (Command Post, fires); fake glow with emissive meshes | M1.5 night test |
| Zombies look stiff without skeletal animation | Crowd looks fake | Turn to heading, height bob, per-zombie colour and size variation; vertex-shader shamble later | M1.5 playtest |
| No artist: placeholder 3D looks cheap | Owner loses interest | Low-poly kit with shared gritty materials, fog and lighting carry the mood; real models in M6 | After M1.5 screenshots |
| Picking errors at shallow camera angles | Wrong building selected | Pitch 30 degrees or steeper; selection tests footprint boxes before the ground; tested at 30 degrees with a tall building | M1.5 |
| Tall buildings hide zombies and breaches | Player misses attacks | Night screenshot check at 30 degrees; if it fails, fade buildings between camera and zombies | M1.5 art PR |
| Saves not restoring correctly | Lost progress | Round-trip test per system | M5 |
| Loading a malicious save file | Code execution | JSON only, never load saves as Resources | Always |

## Non-Functional Requirements

*   **Performance budget (M1):** 60 fps with 500 zombies on a 128 x 128 map, on a mid-range laptop (4-core CPU, integrated GPU). The author's own laptop is the reference machine; record its specs in the M1 benchmark issue.
    *   flow-field rebuild: 8 ms or less
    *   zombie update + draw: 6 ms or less per frame
    *   M2 adds 50 citizens with the same 60 fps target.
*   **Performance floor (M1.5, 3D):** 30 fps with 500 zombies on the owner's low-end Windows ARM laptop (the reference machine from M1.5 on) at the lowest settings. Measured with exported ARM64 builds: the 3D test scene before PR A, the game after PR A and after PR C. The 60 fps target stays for a mid-range laptop and is checked again in M6.
*   **Saves:** carry a version number from M5 on.
*   **Accessibility:** UI scale setting, OpenDyslexic font option. No information by colour alone: the blocked ghost also shows a cross icon, and zombie types differ in size and shape, not only colour.

## Open Questions

*   **Map size:** is 128 x 128 right? Decide after the M1 benchmark.
*   **Art style:** decided: 3D, dark and gritty (see Art direction).
*   **Zoning:** SimCity-style zones where buildings grow by themselves, or place and upgrade each building by hand? Asked 2026-11-21; must be answered before PR B starts. The plan below assumes by hand.
*   **Roads:** do buildings need road access (for upgrades or citizens)? Not in M1.5.
*   **Game name:** decided: Hold the Gates.

## Future Improvements

*   **Hand-painted and generated maps** beyond the simple starter layout.
*   **Sector-based flow field repair:** rebuild only the changed area, if full rebuilds become a problem.

--------------------------------------------------------------------------------

## Detailed Implementation Plan

### M0 (done in the first commit)

These files exist and pass CI. They are the contract the M1 work builds on.

| File | What it does |
|---|---|
| `project.godot` | Name "Hold the Gates", main scene `scenes/main/main.tscn`, Compatibility renderer, 1920x1080 `canvas_items` stretch, autoloads, input actions (below) |
| `scripts/autoload/event_bus.gd` | Signals: `building_placed(building)`, `building_destroyed(building)`, `resource_changed(id, value)`, `day_started(day)`, `dusk_started(day)`, `night_started(day)`, `game_over(day)` |
| `scripts/autoload/game_clock.gd` | `day` (starts at 1), `time_of_day` (0.0 dawn to 1.0), `speed` (0 to 3), `set_speed()`, `reset()`, `is_night()`. Fixed-step accumulator: `sim_tick(dt)` with fixed dt = 1 / `sim_ticks_per_second`, more ticks at higher speed, max `max_catch_up_ticks * speed` per frame (remainder dropped). Time advances per tick. At 1.0 it wraps, `day` += 1, `day_started` fires |
| `scripts/autoload/economy.gd` | `stock: Dictionary[StringName, int]`, `reset(start)`, `get_amount()`, `add()` (clamps at 0), `can_afford(cost)`, `spend(cost)` (all or nothing). Every change emits `resource_changed` |
| `scripts/data/balance_def.gd`, `data/balance.tres` | Global numbers (time, zombies, start resources). Defaults in the script are the starting values |
| `scripts/data/map_def.gd`, `data/maps/starter_map.tres` | Map size, tile size, border width, water and rubble rectangles, Command Post cell |
| `scenes/main/main.tscn`, `scripts/main/main.gd` | M0 placeholder: checkerboard map, camera, clock label, speed keys |
| `tests/test_case.gd`, `tests/run_tests.gd` | Zero-dependency runner. Test files extend `TestCase`; one fresh instance per `test_*` method; `assert_true`, `assert_eq` record failures; exit code 1 on any failure |
| `tests/test_smoke.gd`, `test_economy.gd`, `test_game_clock.gd` | 11 tests |
| `.github/workflows/ci.yml` | `lint` job (gdtoolkit 4, Python 3.12) and `godot` job (downloads 4.5.1-stable, imports, runs tests, runs main scene 120 frames; fails on `SCRIPT ERROR`, `Parse Error` or `ERROR:` in the log). Runs on push to main and on pull requests |
| `.gdlintrc` | max line length 100, max file lines 300 |

Input actions: WASD = camera, mouse wheel = zoom, left mouse = `place`, right mouse / Esc = `cancel`, F3 = `debug_overlay`, Space = pause, 1/2/3 = speed. M1 adds `debug_spawn` (F5), `debug_resources` (F6), `debug_skip_night` (F7).

### M1 rules every file follows

*   **Cell index:** `index = y * map_width + x`.
*   **Building anchor:** a building's cell is its top-left cell; it covers `size` cells to the right and down.
*   **Cost type:** `Dictionary[StringName, int]`.
*   **Grid changes:** `Grid` emits its own `changed` signal. `World` sets a dirty flag and rebuilds the flow field once at the end of that frame.
*   **New game sequence (`Main.new_game()`):** free the old World, `GameClock.reset()`, `Economy.reset(balance.start_resources)`, create a new World, set speed 1.
*   **Game over:** `CommandPost` emits `EventBus.game_over(GameClock.day)`. `Main` sets speed 0 and shows the game-over screen.

### M1 files

#### 1. `scripts/data/` new Defs (Create)

| Def | Fields (type, unit) | First values |
|---|---|---|
| `TerrainDef` in TileSet custom data, not a script | `cost: int` per tile (-1 = impassable) | ground 1, rubble 3, water -1, border -1 |
| `ZombieDef` (`zombie_def.gd`) | `id`, `speed: float` (px/s), `health: int`, `building_damage: int`, `attack_cooldown: float` (s), `radius: float` (px), `color` | walker: 40, 30, 5, 1.0, 10 |
| `BuildingDef` (`building_def.gd`) | `id`, `display_name`, `size: Vector2i`, `cost`, `max_health: int`, `is_goal: bool`, `scene: PackedScene`, `color` | command_post 3x3, free, 500 hp. house 2x2, 20 wood, 100 hp. farm 3x3, 30 wood, 80 hp. storage 2x2, 25 wood + 10 scrap, 120 hp. All `is_goal = true` |
| `BuildCatalog` (`build_catalog.gd`) | `buildings: Array[BuildingDef]` | house, farm, storage (no Command Post) |
| `BalanceDef` additions | `camera_pan_speed` (px/s), `camera_zoom_min`, `camera_zoom_max`, `edge_scroll_margin` (px), `separation_strength`, `demolish_refund` (0..1), `debug_spawn_count` | 1200, 0.25, 2.0, 12, 60.0, 0.5, 100 |

Storage has no gameplay effect in M1 (storage caps come in M2).

#### 2. `assets/tiles/terrain.png`, `assets/tiles/terrain_tileset.tres` (Create)

*   A 4-tile placeholder strip (ground, rubble, water, border), 32 px each, drawn as flat colours with a pattern so they differ without colour.
*   TileSet with one atlas and a custom data layer `cost: int`.

#### 3. `scenes/world/world.tscn`, `scripts/world/world.gd` (Create)

*   Children: `Terrain` (TileMapLayer), `Grid`, `Buildings` (Node2D), `ZombieManager`, `HordeDirector`, `BuildTool`, `CameraRig`, `DebugOverlay`.
*   `_ready()`: runs `StarterMap.generate(terrain, map_def)`, then `Grid.setup(terrain)`, places the Command Post, builds the flow field, injects references (`grid`, `flow_field`, `zombie_manager`) into children.
*   Owns `var flow_field: FlowField`. On `Grid.changed` sets `_dirty = true`; in `_process` rebuilds once if dirty and records `last_build_ms`.
*   Goals = every cell of every building with `is_goal`.

#### 4. `scripts/world/starter_map.gd` (Create)

*   Static `generate(layer: TileMapLayer, def: MapDef)`: ground everywhere, `border_width` ring of border tiles, water and rubble rectangles from the def.

#### 5. `scripts/world/grid.gd` (Create)

*   `setup(layer)`: reads size from `layer.get_used_rect()`, reads `cost` custom data into `base_cost: PackedInt32Array`.
*   `cost: PackedInt32Array` = base cost, or `BLOCKED` (-1) where a building stands. (Walls with break cost come in M3.)
*   `occupant: Dictionary[Vector2i, Building]`.
*   `in_bounds(cell)`, `is_free(cells) -> bool` (in bounds, cost > 0, no occupant), `occupy(cells, building)`, `release(cells)` (restores `base_cost`), `building_at(cell) -> Building`, `cell_to_world(cell)`, `world_to_cell(pos)` (both via the TileMapLayer).
*   Signal `changed`, emitted by `occupy` and `release`.

#### 6. `scripts/world/camera_rig.gd` (Create)

*   Camera2D. Pan with WASD and screen edges (always on in M1), zoom with the wheel, clamp to map bounds from `Grid`. Numbers from `BalanceDef`.

#### 7. `scripts/systems/flow_field.gd` (Create)

*   `class_name FlowField extends RefCounted`.
*   `build(cost: PackedInt32Array, size: Vector2i, goals: PackedInt32Array)`.
*   Rules:
    *   8 neighbours. Step cost = cost of the tile entered x 10 (straight) or x 14 (diagonal). Goal tiles have integration 0.
    *   Tiles with cost -1 are never entered. No diagonal step if either side tile is blocked (no corner cutting).
    *   Building tiles that are goals are seeds, even though their cost is -1.
    *   Dial's bucket queue, `integration: PackedInt32Array`, unreached = `UNREACHED` (2^31 - 1).
    *   `direction: PackedByteArray`: 0 = N, 1 = NE, 2 = E, 3 = SE, 4 = S, 5 = SW, 6 = W, 7 = NW, 255 = none. Each tile points to the neighbour with the lowest integration value; ties go to the lowest direction number. Goal and unreached tiles get 255.
*   `direction_at(cell) -> Vector2`: unit vector, or `Vector2.ZERO` for 255 or out of bounds.
*   Example, 3x3 open grid, goal at the centre (1,1): top-left (0,0) gets 3 (SE), top-middle (1,0) gets 4 (S), right-middle (2,1) gets 6 (W).

#### 8. `scripts/systems/spatial_hash.gd` (Create)

*   `RefCounted`. `rebuild(positions, count, bucket_size)` with a counting sort into `cell_start` and `items`.
*   `query(pos, radius, out: PackedInt32Array) -> int`: writes indices with distance <= radius into `out` (resized if too small), returns how many.

#### 9. `scripts/units/zombie_manager.gd` (Create)

*   `Node2D` with a `MultiMeshInstance2D` child (QuadMesh 20 x 20 px, `use_colors = true`). Buffer layout: 8 floats transform + 4 floats colour per instance.
*   State enum: `HORDE`, `ATTACK` (more states in later milestones).
*   API as in "Zombies as data". `spawn()` returns false at `max_zombies`. `damage()` queues a kill at 0 health.
*   Movement as in "Zombie movement and attacks" (chase off in M1).
*   Exposes `last_update_ms` for the debug overlay.

#### 10. `scripts/buildings/building.gd`, `scenes/buildings/building.tscn` (Create)

*   `Building extends Node2D`. Draws a placeholder rect with an outline and the first letter of its name.
*   `def`, `cell`, `health`. `take_damage(amount)`. At 0: `release` cells, emit `building_destroyed`, `queue_free()`.
*   `demolish()`: refund `demolish_refund` of the cost, release cells, emit `building_destroyed`, `queue_free()`. M1 has no demolish input yet (M2).

#### 11. `scripts/buildings/command_post.gd`, `scenes/buildings/command_post.tscn` (Create)

*   Extends `Building`. On reaching 0 health also emits `EventBus.game_over(GameClock.day)`.

#### 12. `scripts/world/build_tool.gd` (Create)

*   `select(def)`, `clear()`, `place(cell) -> bool`.
*   Ghost follows the mouse cell. Validation order: in bounds, `Grid.is_free(cells)`, no live zombie in the footprint (`ZombieManager.query`), `Economy.can_afford`. Invalid = red tint plus cross icon.
*   `place()` on valid: `Economy.spend`, instantiate `def.scene`, `Grid.occupy`, emit `building_placed`. On invalid: change nothing, return false.
*   `cancel` input clears the selection.

#### 13. `scripts/systems/horde_director.gd` (Create)

*   Own `RandomNumberGenerator` (seeded at new game).
*   On `night_started(day)`: queue `horde_base + day * horde_growth` walkers. Spawns `spawns_per_frame` per frame on random passable cells in the ring just inside the border.

#### 14. `scenes/ui/hud.tscn`, `scripts/ui/hud.gd` (Create)

*   Top bar: resources, day, clock, speed buttons (highlight the current speed every frame from `GameClock.speed`).
*   Bottom bar: one button per `BuildCatalog` entry, calls `BuildTool.select()`.
*   Created by Main, lives next to World.

#### 15. `scenes/ui/game_over.tscn`, `scripts/ui/game_over.gd` (Create)

*   Shows "You held out until day N". Button "New game" calls `Main.new_game()`.

#### 16. `scenes/ui/debug_overlay.tscn`, `scripts/ui/debug_overlay.gd` (Create)

*   CanvasLayer, toggled by F3. Shows fps, zombie count, `World.last_build_ms`, `ZombieManager.last_update_ms`.
*   Draws flow arrows only for tiles visible on screen.
*   Cheat keys F5/F6/F7 only when `OS.is_debug_build()`.

#### 17. `scenes/main/main.tscn`, `scripts/main/main.gd` (Modify)

*   Replace the M0 placeholder: hold World, HUD and GameOver. Implement `new_game()` and game over as in "M1 rules".

#### 18. `scenes/tests/light_test.tscn` (Create)

*   Starter map, 30 `PointLight2D`, `CanvasModulate` night colour, 500 zombies spawned at start. Used by hand to read fps.

#### 19. Tests (Create)

| File | Cases |
|---|---|
| `test_flow_field.gd` | 3x3 example above gives the stated directions; a blocked middle column forces a path around; an enclosed tile gets 255 and `UNREACHED`; no corner cutting past a blocked tile |
| `test_spatial_hash.gd` | points at distance 9, 10, 11 from the query with radius 10 return the first two; empty query returns 0 |
| `test_grid.gd` | occupy makes cells not free and cost -1; release restores base cost; `changed` fires once per call; out-of-bounds cells are not free |
| `test_zombie_manager.gd` | spawn up to `max_zombies` then false; kill twice in one frame keeps arrays the same length and consistent after end-of-frame removal; damage to 0 removes the zombie |
| `test_build_tool.gd` | place fails without changing stock or grid when too expensive or blocked; succeeds and spends when valid |
| `test_horde_director.gd` | day 3 queues `horde_base + 3 * horde_growth`; every spawn cell is passable and inside the border |
| `test_building.gd` | damage to 0 releases cells and emits `building_destroyed`; Command Post also emits `game_over` |
| `test_game_clock.gd` (extend) | 1 real second at speed 2 gives 20 ticks; catch-up cap holds |
| `bench_flow_field.gd` | not run in CI. `godot --headless --script res://tests/bench_flow_field.gd` prints build ms for 128 x 128 |

Tests that need nodes add them to the tree root, and free them at the end.

### Verification Plan

*   **CI (every push):** lint, format check, import with no errors, all tests pass, main scene runs 120 frames with no errors.
*   **M1 pass criteria (manual, on the reference laptop):**
    *   `bench_flow_field.gd` reports 8 ms or less.
    *   With 500 zombies, the debug overlay shows 60 fps and `ZombieManager.last_update_ms` 6 or less.
    *   Light test scene holds 60 fps, or the result is recorded and a renderer decision is made.
    *   CUJ 1 played by hand.
*   Results go in the M1 benchmark issue.


### M1.5: 3D view and building upgrades

Goal: the M1 game in 3D with a city-builder camera, buildings with three levels (two upgrades each), and the dark gritty look. M1 gameplay rules stay the same except where listed.

| PR | Contents | Playable after it? |
|---|---|---|
| 0 | 3D test scene and ARM64 test export. **Merged (#58).** Owner reports fps before PR A | n/a |
| A | Terrain from data, World/camera/picking/build ghost/buildings/zombies/day-night in 3D, debug overlay text only | Yes: box buildings, capsule zombies |
| B | Flow arrows in 3D, building levels, selection, InfoPanel, upgrades, temporary income | Yes: upgrades work, levels shown as taller boxes |
| C | Gritty art kit: materials, models per level, zombie mesh, props, final lighting | Yes: final M1.5 look |

After PR A and PR C: export Windows x86_64 and ARM64 builds; the owner reads fps on the ARM laptop (Performance floor).

#### Rules every M1.5 file follows

*   Conversion as in "3D view": `World.to_view()` / `to_sim()`; hot loops may cache `view_scale`.
*   Sim code (`Grid`, `FlowField`, `SpatialHash`, `HordeDirector`, `ZombieManager` movement, `BuildTool` validation) uses no 3D types.
*   `Building.sim_center() -> Vector2` is the building's position in sim space. Sim code uses it, never `position`.
*   A building model's origin is the centre of its footprint, on the ground.
*   New numbers go in a Def (`BalanceDef`, `MapDef`, `LightingDef`, `BuildingLevelDef`, `TerrainSet`, `ZombieDef`).

#### PR A

##### A1. Defs and data (Create / Modify)

| Def | Fields | First values |
|---|---|---|
| `TerrainDef` (Create, `scripts/data/terrain_def.gd`) | `id: StringName`, `cost: int` (-1 = impassable), `color: Color`, `height: float` (m) | ground (1, olive, 0), rubble (3, grey-brown, 0), water (-1, dark green-blue, -0.3), border (-1, near black, 0) |
| `TerrainSet` (Create, `scripts/data/terrain_set.gd`, `data/terrain/terrain_set.tres`) | `types: Array[TerrainDef]` as sub-resources (index = type id), `shade_variation: float` | ground 0, rubble 1, water 2, border 3; 0.06 |
| `MapDef` (Modify) | add `view_scale: float`, `map_seed: int`; `tile_size` comment no longer mentions a TileSet | 0.125, 1 |
| `BalanceDef` (Modify) | camera group replaced: `camera_pan_speed` (m/s), `camera_rotate_speed` (rad/s), `camera_drag_rotate` (rad/px), `camera_tilt_speed` (deg/s), `camera_zoom_step` (factor), `camera_distance_min/max/start` (m), `camera_pitch_min/max/start` (deg); `edge_scroll_margin` stays | 40, 1.6, 0.01, 60, 1.15, 10 / 160 / 60, 30 / 75 / 55 |
| `ZombieDef` (Modify) | add `mesh: Mesh`, `mesh_y_offset: float` (m), `model_scale: float`, `turn_rate: float` (rad/s), `bob_amplitude: float` (m), `bob_speed: float` (rad/s) | `data/zombies/walker.tres` gets a `CapsuleMesh` sub-resource (radius 0.3, height 1.7, material with `vertex_color_use_as_albedo`) until PR C; 0.85 (capsule origin is its centre; 0 for the PR C mesh); 1.0, 6.0, 0.05, 6.0 |
| `LightingDef` (Create, `scripts/data/lighting_def.gd`, `data/lighting.tres`) | `sun_color: Gradient`, `sun_energy: Curve`, `ambient_color: Gradient`, `ambient_min: float`, `fog_color: Gradient`, `fog_density: Curve`, `fog_density_max: float`, `moon_color: Color`, `moon_energy: float`, `moon_pitch: float` (deg), `zombie_night_emission: float`, `shadows: bool` (all sampled by `time_of_day`) | PR A: `sun_color` 0.0 `#ffcf9a`, 0.35 `#fff4e0`, 0.7 `#ff9a5a`; `sun_energy` 0.0 0.3, 0.35 1.0, 0.7 0.3; `ambient_color` `#b8c0c8` day to `#46507a` at 0.75; `ambient_min` 0.25 (energy); `fog_color` `#9aa39a`; `fog_density` 0.002 flat; `fog_density_max` 0.01; moon `#8fa0d8`, 0.25, 50; `zombie_night_emission` 0; shadows on. PR C tunes them |

`project.godot` (Modify): add input actions `camera_rotate_left` (Q), `camera_rotate_right` (E), `camera_tilt_up` (R), `camera_tilt_down` (F). Middle-mouse drag is read directly in `CameraRig`.

##### A2. `scripts/world/starter_map.gd` (Modify)

*   `generate(def: MapDef) -> PackedByteArray`: one terrain type id per tile, same layout rules as M1. No TileMapLayer.

##### A3. `scripts/world/grid.gd` (Modify)

*   `setup(map_size: Vector2i, terrain_types: PackedByteArray, terrain: TerrainSet, tile: float)`: stores `types`, fills `base_cost` from `terrain.types[type].cost`.
*   `occupant: Dictionary[Vector2i, Building]`; `occupy(cells, building: Building)`; `building_at(cell) -> Building`.
*   `cell_to_world(cell) = (Vector2(cell) + Vector2(0.5, 0.5)) * tile` (cell centre, same as M1). `world_to_cell(pos) = Vector2i(floor(pos / tile))`. `world_size() = Vector2(size) * tile`.

##### A4. `scripts/world/terrain_mesh.gd` (Create)

*   `class_name TerrainMesh extends Node3D`. `build(grid: Grid, terrain: TerrainSet, view_tile: float, rng: RandomNumberGenerator)` creates one `MeshInstance3D` child per 16 x 16 tile chunk.
*   Per tile: two triangles (6 vertices, no index array) at `TerrainDef.height`, colour = `TerrainDef.color` darkened or lightened by up to `shade_variation`. Where a tile's height differs from its east or south neighbour, add a side quad between the two heights.
*   Built with `SurfaceTool`: top faces get normal UP; side quads face the lower tile (wound so they are visible from it). One shared `StandardMaterial3D` with `vertex_color_use_as_albedo = true`, roughness 1, `cull_mode = CULL_DISABLED` as a safety net for side quads.

##### A5. `scenes/world/world.tscn`, `scripts/world/world.gd` (Modify)

*   Root is `Node3D`. Children: `Terrain` (TerrainMesh), `Grid`, `Buildings` (Node3D), `ZombieManager`, `HordeDirector`, `BuildTool`, `CameraRig`, `DayNight`, `DebugOverlay`. `NightTint` and `_update_tint()` are deleted.
*   Owns `var rng := RandomNumberGenerator.new()`, seeded from `map_def.map_seed`.
*   `_ready()` order: load `map_def` and the terrain set; `view_scale = map_def.view_scale`; `rng.seed = map_def.map_seed`; `types = StarterMap.generate(map_def)`; `grid.setup(map_def.size, types, terrain_set, map_def.tile_size)`; `terrain.build(grid, terrain_set, view_tile(), rng)`; `camera.world = self`; `camera.set_bounds(Rect2(Vector2.ZERO, grid.world_size() * view_scale))` (view-space XZ, metres); `build_tool.world = self`; spawn the Command Post; `camera.look_at_sim(command_post.sim_center())`; connect `grid.changed`; build the flow field; `zombies.setup(self)`; `horde.setup(self, Time.get_ticks_usec())` (unchanged from M1); `day_night.setup()`; `debug_overlay.world = self`.
*   Adds `view_scale`, `to_view()`, `to_sim()`, `view_tile() -> float` (= `tile_size * view_scale` = 4). `tile_size()` returns `Vector2(map_def.tile_size, map_def.tile_size)` (sim units).
*   `spawn_building(def, cell)` calls `building.setup(def, cell, self)`.
*   Flow-field rebuild code unchanged.

##### A6. `scenes/world/camera_rig.tscn` (Create), `scripts/world/camera_rig.gd` (Replace)

*   `CameraRig extends Node3D` (the point it looks at, on the ground) with a `Camera3D` child (`fov` 50, `far` 600). Controls as in "3D view", numbers from `BalanceDef`. Start at `camera_distance_start`, `camera_pitch_start`, yaw 0.
*   State: `distance: float`, `pitch_deg: float` (positive, 30 to 75; the bench used negative pitch, so the camera offset is `Vector3(0, sin(pitch), cos(pitch)) * distance`), `bounds: Rect2`, `world: World`.
*   API: `set_bounds(rect: Rect2)`, `pan(dir: Vector2, delta: float)` (dir in screen terms, rotated by yaw), `rotate_by(radians)`, `tilt_by(degrees)`, `zoom_by(factor)` (clamps `distance`), `_clamp()` (keeps the rig's XZ inside `bounds`). `_process` and `_unhandled_input` only call these.
*   `look_at_sim(p: Vector2)` (needs `world`, set by World).
*   `static func ray_to_ground(origin: Vector3, dir: Vector3) -> Variant`: point on `y = 0`, or `null` when `dir.y >= 0`.
*   `mouse_ray() -> Array` (origin, dir) from `Camera3D.project_ray_origin/normal`.
*   `target() -> Vector3` (rig position, used by the debug overlay).
*   Written from `scripts/debug/bench_camera_3d.gd`.

##### A7. `scripts/world/build_tool.gd` (Modify)

*   `extends Node3D`. Mouse cell: `world.camera.mouse_ray()` → `ray_to_ground()` → `world.to_sim()` → `grid.world_to_cell()`. Validation and `place()` unchanged.
*   Ghost: child `MeshInstance3D` box of the footprint, 0.5 m high, unshaded transparent material (white 40 percent alpha valid, red 50 percent invalid), plus two crossed thin boxes on top shown only when invalid. No `_draw`. When the mouse ray misses the ground, the ghost is hidden and clicks do nothing.

##### A8. `scripts/buildings/building.gd`, `command_post.gd`, `scenes/buildings/*.tscn` (Modify)

*   `extends Node3D`. `setup(def, anchor, world: World)`. `sim_center() -> Vector2` = footprint centre in sim space; `position = world.to_view(sim_center())`.
*   Look in PR A: a `MeshInstance3D` box of the footprint (minus 0.3 m each side), 3 m high, colour from `def.color`. Health bar 1 m above the roof, shown when damaged: two `MeshInstance3D` with `QuadMesh` (back dark, front red), unshaded material with `billboard_mode = ENABLED` and `no_depth_test = true`; the front quad's X scale = health fraction. No `_draw`.
*   Callers switched to `sim_center()`: `zombie_manager.gd` (`target`), `world.gd` (camera start), `tests/test_zombie_manager.gd`.

##### A9. `scripts/units/zombie_manager.gd`, `scenes/units/zombie_manager.tscn` (Modify)

*   `extends Node3D`, child `MultiMeshInstance3D` (`cast_shadow = off`). Movement code unchanged except `target` (A8).
*   `setup()`: `transform_format = TRANSFORM_3D`, `FLOATS_PER_INSTANCE = 16`, mesh = `load("res://data/zombies/walker.tres").mesh` (load, not preload; see CLAUDE.md gotcha). `view_scale` copied from World. `_rng.seed = world.map_def.map_seed + 1`.
*   New arrays, resized in `setup`, set in `spawn`, moved in swap-remove: `_heading: PackedFloat32Array` (radians; 0 = facing +Z, eased towards the move direction at `turn_rate`), `_phase: PackedFloat32Array` (random at spawn from `_rng`).
*   `_time: float` advances by the scaled `dt`, so the bob stops when paused.
*   `_upload()`: 16 floats per instance: basis = rotation about Y by heading, times `model_scale`; origin = `Vector3(p.x, 0, p.y) * view_scale`, plus on Y `mesh_y_offset` + bob `sin(_time * bob_speed + _phase[i]) * bob_amplitude`; then colour. Mesh material uses `vertex_color_use_as_albedo`. `custom_aabb` covers the map in view space, y from -1 to 4 m.

##### A10. `scripts/world/day_night.gd`, `scenes/world/day_night.tscn` (Create)

*   `DayNight extends Node3D`; `day_night.tscn` holds a `DirectionalLight3D` and a `WorldEnvironment` whose Environment has `background_mode = COLOR`, `ambient_light_source = COLOR`, `fog_enabled = true`. `setup()` loads `data/lighting.tres`.
*   `apply(t: float)` does all the work; `_process` calls `apply(GameClock.time_of_day)`. Tests call `apply()` directly.
*   Axes: north = -Z, east = +X. `t` = 0 is sunrise in the east, `night_at` (0.7) is sunset in the west. Sun elevation in degrees = `70 * sin(PI * t / night_at)`, yaw goes from east (+X) through south to west (-X) across that span. From `night_at` to 1.0 the light is the moon: pitch `moon_pitch`, yaw fixed from the south-west, `moon_color`, `moon_energy`.
*   Light colour, energy, background and fog colour sampled from `LightingDef`; `ambient_light_energy = maxf(ambient_min, sampled)`; fog density capped at `fog_density_max`.

##### A11. `scripts/ui/debug_overlay.gd` (Modify)

*   Root becomes a plain `Node`; F3 toggles visibility of its `Layer` (CanvasLayer) child only. Text stats unchanged. The 2D flow-arrow drawing is removed in PR A (arrows come back in B1 as a `MeshInstance3D` child).

##### A12. Remove

*   `tools/make_terrain.gd`, `assets/tiles/terrain.png`, `assets/tiles/terrain.png.import`, `assets/tiles/terrain_tileset.tres`, `scenes/tests/light_test.tscn`, `scripts/debug/light_test.gd` (the 3D test scene replaces it).

##### A13. Docs

*   `docs/SYSTEMS.md`: Grid setup from terrain types, 3D camera controls, zombie drawing, day/night.

#### PR B

##### B1. Flow arrows (`scripts/ui/debug_overlay.gd`)

*   Adds a child `MeshInstance3D` with an `ImmediateMesh`: one line per tile with a direction, 0.1 m above the ground, only within `debug_arrow_radius` (`BalanceDef`, 40 m) of `world.camera.target()`.

##### B2. `scripts/data/building_level_def.gd` (Create), `building_def.gd` (Modify)

*   `BuildingLevelDef`: `name: String`, `model: PackedScene` (may be null until PR C), `height: float` (m, used for the placeholder box and for picking), `max_health: int`, `upgrade_cost: Dictionary[StringName, int]` (empty for level 1), `min_day: int`.
*   `BuildingDef`: add `levels: Array[BuildingLevelDef]`; remove `max_health` (now per level). `cost` stays the placement cost; `color` stays for the placeholder. Helpers `level_def(n) -> BuildingLevelDef` (1-based), `max_level() -> int`.
*   Levels are sub-resources inside the four building files: `data/buildings/command_post.tres`, `house.tres`, `farm.tres`, `storage.tres`.

| Building | Level 1 | Level 2 | Level 3 |
|---|---|---|---|
| House (2x2) | Tent, 100 hp, 2.0 m | Shack, 180 hp, 3.5 m, 30 wood + 10 scrap, day 2 | Brick house, 300 hp, 6.5 m, 40 wood + 30 scrap, day 4 |
| Farm (3x3) | Plot, 80 hp, 0.5 m | Fenced field, 140 hp, 1.5 m, 25 wood, day 2 | Greenhouse, 220 hp, 4.0 m, 20 wood + 30 scrap, day 4 |
| Storage (2x2) | Tarp pile, 120 hp, 2.0 m | Shed, 200 hp, 3.5 m, 30 wood, day 2 | Warehouse, 350 hp, 7.0 m, 30 wood + 40 scrap, day 4 |
| Command Post (3x3) | Command Post, 500 hp, 6.0 m | (levels later) | |

Level 1 health equals the M1 values, so M1 balance does not change.

`BalanceDef` adds `daily_income: Dictionary[StringName, int]` = 20 wood, 10 scrap (temporary, removed in M2). `World` pays it on `EventBus.day_started`.

##### B3. `scripts/buildings/building.gd` (Modify)

*   `level: int = 1`. `max_health()` reads the current level. Look: `level_def.model` if set, else the placeholder box with `level_def.height`.
*   `upgrade_blocker() -> String`, first failing check wins: "Max level", "Can't build at night", "Unlocks on day N", "Needs " + every missing resource as "N name" joined by ", ". Empty string = allowed.
*   `upgrade() -> bool`: if `upgrade_blocker()` is empty: `Economy.spend(next.upgrade_cost)`, `level += 1`, health as in "Building upgrades", swap the look, emit `EventBus.building_upgraded(self)`, return true. Else change nothing, return false.
*   `pick_box() -> AABB`: footprint x current height in view space, used for selection.

##### B4. `scripts/world/build_tool.gd` (Modify)

*   `signal selection_changed(building: Building)`. `selected_building: Building`.
*   Left click with no def selected: test the mouse ray against every building's `pick_box()`, nearest hit wins; no hit clears the selection. `select(def)` and `cancel` also clear it.
*   `upgrade(building) -> bool` calls `building.upgrade()` (UI command).

##### B5. `scenes/ui/info_panel.tscn`, `scripts/ui/info_panel.gd` (Create); `scenes/main/main.tscn`, `scripts/main/main.gd` (Modify)

*   Bottom-left panel shown while `selected_building` is set: name, "Level 2 of 3", health, next level name, height and health, cost, Upgrade button (disabled, with the blocker text under it). Button calls `BuildTool.upgrade()`.
*   `main.tscn` holds the InfoPanel next to the HUD; `main.gd` calls `info_panel.bind(world.build_tool)` after each `new_game()`, like `_hud.bind`.

##### B6. `scripts/autoload/event_bus.gd` (Modify)

*   `signal building_upgraded(building: Node)`.

#### PR C

##### C1. Materials (`assets/materials/*.tres`, Create)

*   `StandardMaterial3D` files using `NoiseTexture2D` for grime: concrete, rust metal, old wood, brick, tarp, dirt, asphalt, zombie skin. No generator script.

##### C2. Models (Create)

*   `scenes/models/<building>_<level>.tscn`: 10 scenes built from primitive meshes with the shared materials, following Art direction; set as `BuildingLevelDef.model`. Heights match the B2 table.
*   `tools/make_zombie_mesh.gd`: merges body, head and reaching arms into one `ArrayMesh` at `assets/models/zombie_walker.res` (a MultiMesh needs one mesh). Set as `walker.tres` `mesh`.
*   Props: wrecked car, rubble pile, dead tree. Placed by `StarterMap` rules on rubble tiles and on ground near the border, drawn with one `MultiMeshInstance3D` per prop type (visual only, no grid cost).

##### C3. `data/lighting.tres` (Modify)

*   Final gritty curves: low warm sun, grey-green fog, dark blue nights, `zombie_night_emission`; one fire-orange `OmniLight3D` at the Command Post.
*   `DayNight.apply()` sets the zombie material's emission energy from `zombie_night_emission` (zero by day).

#### Tests (M1.5)

| File | Cases |
|---|---|
| `test_grid.gd` (modify, PR A) | setup from a type array: water -1, rubble 3; `cell_to_world((1, 2))` = (48, 80); `world_to_cell` inverse; occupy/release as before but with `Building.new()` (freed after) instead of `Node2D.new()`. No TileSet preload |
| `test_terrain_mesh.gd` (create, A) | 32 x 32 map makes 4 chunks; a 4 x 4 all-ground map has 96 vertices (16 tiles x 6); a water tile next to ground adds side quads |
| `test_world_view.gd` (create, A) | `to_sim(to_view(p))` equals `p` within 0.001; cell (0,0) centre maps to (2, 0, 2) m |
| `test_camera_rig.gd` (create, A) | `ray_to_ground((0,10,0), (0,-1,1).normalized())` = (0,0,10); upward ray = `null`; zoom stays within min/max; rig clamped inside bounds |
| `test_zombie_manager.gd` (modify, A) | positions from `cp.sim_center()`; after a kill and swap-remove, `_heading` and `_phase` stay with their zombie; `visible_instance_count == count()` |
| `test_day_night.gd` (create, A) | after `apply(0.35)` the light energy is higher than after `apply(0.85)`; `ambient_light_energy >= ambient_min` at every t in steps of 0.05 |
| `test_building.gd` (modify, B) | uses `level_def(1).max_health` instead of `max_health` |
| `test_building_upgrade.gd` (create, B) | upgrade spends, raises the level, keeps the health fraction (50/100 hp becomes 90/180), keeps cells; blocked with no change when poor, at max level, before `min_day`, or at night; blocker texts as in B3 |
| `test_build_tool.gd` (modify, B) | with the camera at 30 degrees pitch, a ray through a 6.5 m brick house roof selects that house, not the cell behind it; clicking empty ground clears the selection |
| `test_economy.gd` (modify, B) | `daily_income` is paid once per `day_started` |

#### Verification (M1.5)

*   CI as before (lint, format, import, tests, main scene 120 frames).
*   Before PR A: the owner reports the 3D test scene's fps on the ARM laptop. 30 or more with 500 zombies at some setting = go; otherwise stop and revisit Alternative C2.
*   After PR A and after PR C: exported ARM64 build, owner reads fps with 500 zombies (F3 overlay). Below 30: lower settings first, then cut art.
*   After PR C, by hand: CUJ 1 in 3D; place a house and upgrade it to level 3 over a few days; rotate and zoom at night; the night readability screenshot (Art direction). Screenshots in the PR.

--------------------------------------------------------------------------------

*Drafted with EGM*
