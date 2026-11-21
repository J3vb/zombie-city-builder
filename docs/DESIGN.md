# Zombie City Builder: Technical Design

*   **Author:** J3vb (drafted with Claude)
*   **Status:** Proposed (Goldfish review rounds 1 and 2 resolved, see [reviews](reviews/review-report.md))
*   **Date:** 2026-11-21

## Overview

A 2D top-down city builder set in a zombie outbreak. Built in Godot 4.5 with GDScript.

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
| M1 | Prototype: place buildings, a horde attacks, game over |
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

## Problem Statement

This game joins a city builder and a tower defense. The city economy pays for the defense, and the defense decides where the city can grow.

The hard technical part is scale. A horde needs hundreds of zombies on screen, all finding a path into a city whose walls change during play.

We expect one scene node plus one path query per zombie to be too slow for 500 zombies in GDScript. The M1 benchmark checks the chosen approach.

Proposed solution:

*   Zombies are rows in arrays, not scene nodes.
*   All zombies are drawn in one batch (`MultiMeshInstance2D`).
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
*   3D graphics.
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

#### Alternative C: 3D

*   **Pros**: more depth and lighting options.
*   **Cons**: more art work, higher performance cost, harder camera and mouse picking.
*   **Reason for Rejection**: 3D is a non-goal for this project.

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
| Many 2D lights slow on the Compatibility renderer | Night runs slow | M1 light test scene: 30 lights + 500 zombies | M1 |
| Saves not restoring correctly | Lost progress | Round-trip test per system | M5 |
| Loading a malicious save file | Code execution | JSON only, never load saves as Resources | Always |

## Non-Functional Requirements

*   **Performance budget (M1):** 60 fps with 500 zombies on a 128 x 128 map, on a mid-range laptop (4-core CPU, integrated GPU). The author's own laptop is the reference machine; record its specs in the M1 benchmark issue.
    *   flow-field rebuild: 8 ms or less
    *   zombie update + draw: 6 ms or less per frame
    *   M2 adds 50 citizens with the same 60 fps target.
*   **Saves:** carry a version number from M5 on.
*   **Accessibility:** UI scale setting, OpenDyslexic font option. No information by colour alone: the blocked ghost also shows a cross icon, and zombie types differ in size and shape, not only colour.

## Open Questions

*   **Map size:** is 128 x 128 right? Decide after the M1 benchmark.
*   **Art style:** pixel art or clean vector shapes? Decide before M6.
*   **Game name:** decide before M6.

## Future Improvements

*   **Hand-painted and generated maps** beyond the simple starter layout.
*   **Sector-based flow field repair:** rebuild only the changed area, if full rebuilds become a problem.

--------------------------------------------------------------------------------

## Detailed Implementation Plan

### M0 (done in the first commit)

These files exist and pass CI. They are the contract the M1 work builds on.

| File | What it does |
|---|---|
| `project.godot` | Name "Zombie City Builder", main scene `scenes/main/main.tscn`, Compatibility renderer, 1920x1080 `canvas_items` stretch, autoloads, input actions (below) |
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

--------------------------------------------------------------------------------

*Drafted with EGM*
