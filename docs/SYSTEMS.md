# Systems

Every system the game needs, what it does, and how we build it.
Each system lists: **What**, **Data**, **How**, **Depends on**, **Milestone**.

Milestones (M0 to M6) are defined in [ROADMAP.md](ROADMAP.md).
Code layout and patterns are in [DESIGN.md](DESIGN.md).

---

## Contents

1. Game clock (day/night and waves)
2. Grid and map
3. Building placement
4. Resources and economy
5. Citizens and jobs
6. Walls, gates and checkpoints
7. Towers and defenders
8. Zombie AI
9. Flow-field pathfinding
10. Horde director (waves)
11. Infection
12. Expeditions (scavenging)
13. Combat and damage
14. Noise and light
15. Tech tree
16. UI and HUD
17. Save and load
18. Audio
19. Settings
20. Debug tools

---

## 1. Game clock

- **What:** time of day, day counter, game speed (pause, 1x, 2x, 3x).
- **Data:** `day: int`, `time_of_day: float` (0.0 to 1.0), `speed: int` (0 = paused, 1, 2, 3).
- **How:** autoload `GameClock`. Advances time in `_process` and uses a fixed-step accumulator to emit `sim_tick` 10 times per real second at 1x (30 at 3x, max 10 catch-up ticks per frame). Emits `day_started`, `dusk_started`, `night_started` on `EventBus`.
  One full day = 6 real minutes at 1x (tunable in `data/balance.tres`).
- **Depends on:** nothing.
- **Milestone:** M0 (done).

## 2. Grid and map

- **What:** the world is a grid of tiles. Each tile has terrain and maybe a building.
- **Data:** terrain types per tile from `StarterMap` (M1 used a `TileMapLayer`; M1.5 uses a type array plus `TerrainSet`). A `Grid` node holds `Dictionary[Vector2i, Building]` for what stands where, plus a base terrain cost array (from TileSet custom data) and an overlay for buildings and walls. Grid is the single source of truth: the flow field (zombies) and `AStarGrid2D` (citizens) are both built from it.
- **How:** tile size 32 px (set in the TileSet). First map is 128 x 128 tiles, generated at start by `starter_map.gd` from a simple layout (border, water, rubble). Hand-painted maps can come later.
  Cell/world conversion uses the TileMapLayer (`local_to_map`, `map_to_local`). Helpers: `is_free(cells)`, `occupy()`, `release()`, `get_cost(cell)`, `building_at(cell)`.
- **Depends on:** nothing.
- **Milestone:** M1.

## 3. Building placement

- **What:** pick a building, see a ghost preview, place it, it gets built over time.
- **Data:** `BuildingDef` resource per building: id, name, size (cells), cost, build time, health, job slots, scene.
- **How:**
  - Ghost follows mouse, snaps to grid. Blocked or too expensive: turns red **and** shows a cross icon (not colour alone).
  - Walls use drag-to-draw (click start, drag, release) along a straight line.
  - On place: resources are reserved, a construction site appears, builders walk there and add work.
  - When done, the site swaps to the real building and the grid updates. Pathfinding gets a "dirty" signal.
  - Demolish refunds 50 percent.
- **Depends on:** Grid, Resources.
- **Upgrades (M1.5):** each `BuildingDef` has `levels` (`BuildingLevelDef`: model, health, upgrade cost, unlock day, capacity). Same footprint at every level. Select a building, press Upgrade. Instant in M1.5, done by builders from M2.
- **Milestone:** M1 (instant build), M1.5 (3D, upgrades), M2 (builders).

## 4. Resources and economy

- **What:** stockpile of food, water, wood, scrap, fuel, medicine, ammo. Power is a live value, not stored.
- **Data:** autoload `Economy` with `Dictionary[StringName, int]`. Storage cap from storage buildings.
- **How:**
  - `can_afford(cost)`, `spend(cost)`, `add(id, amount)`. Emits `resource_changed(id, value)`.
  - Production buildings add on a timer while staffed.
  - Daily upkeep at `day_started`: each citizen eats 1 food and drinks 1 water.
  - Shortage effects: no food -> health and morale drop. No water -> faster health drop.
  - Power: generators give power while they have fuel. Buildings that need power stop when total demand is above supply.
- **Depends on:** Game clock.
- **Milestone:** M1 (stockpile), M2 (production, upkeep), M4 (power).

## 5. Citizens and jobs

- **What:** named survivors who live, eat, work, fight and can get infected.
- **Data:** `Citizen` node: name, health, hunger, morale, skill, job, home, infection stage.
- **How:**
  - Simple state machine: `Idle`, `GoingToWork`, `Working`, `GoingHome`, `Sleeping`, `Fleeing`, `Defending`, `OnExpedition`.
  - Jobs: a `JobBoard` node (child of World) keeps open job slots. Idle citizens take the nearest matching slot.
  - Movement uses Godot `AStarGrid2D`, which `Grid` keeps up to date (walls and buildings solid, gates follow open/closed). No navigation mesh to rebake.
  - At night or under attack, citizens flee to the nearest home or shelter unless they are defenders.
  - Morale: affected by food, deaths, infections inside, and wins. Low morale = slower work, and later, citizens leave.
- **Depends on:** Grid, Buildings, Economy, Clock.
- **Milestone:** M2.

## 6. Walls, gates and checkpoints

- **What:** the main defense layer.
- **Data:** `WallSegment` (1 tile, health, tier), `Gate` (open/closed/locked), `Checkpoint` (gate + holding pen + guard slot).
- **How:**
  - Wall tiles are grid cells with a health entry in a dictionary (no node per wall tile).
  - Wall tiles are blocked for zombies but have a fixed **break cost by tier** in the flow field set in the wall's `BuildingDef` (for example barricade 20, wall 60). Damage does not change the cost. A closed gate uses the wall tier it is built in. Zombies walk around walls if a cheaper path exists, and attack the wall on the cheapest route if not.
  - When a wall tile is destroyed, the Grid marks itself changed and the flow field rebuilds the same frame.
  - Gates: open = citizens pass, zombies also pass. Auto-close at dusk (setting).
  - Checkpoint: refugees wait in the pen for one in-game hour. A guard inspects. Clinic upgrade reveals infection. You pick Accept, Quarantine or Turn away.
  - Builders auto-repair damaged walls when no enemies are near.
- **Depends on:** Grid, Building placement, Flow field, Citizens.
- **Milestone:** M3 (walls, gates), M4 (checkpoint).

## 7. Towers and defenders

- **What:** shoot zombies from walls.
- **Data:** `TowerDef`: range, fire rate, damage, ammo per shot, needs defender (bool).
- **How:**
  - On each fire tick (rate from `TowerDef`) the tower queries the spatial hash and fires at the closest zombie in range, in the same frame. Nothing is stored between frames.
  - Shots are instant hit with a short tracer line (no bullet physics).
  - Without a defender or ammo the tower does nothing.
  - Defender citizens can also stand on a wall tile and fight melee/short range.
- **Depends on:** Zombie spatial hash, Economy (ammo), Citizens.
- **Milestone:** M3.

## 8. Zombie AI

- **What:** hundreds of zombies, cheap per unit.
- **Data:** one `ZombieManager` node holds arrays of position, velocity, health, type, state. Drawing uses `MultiMeshInstance2D`.
- **How:**
  - Zombies are **not** individual nodes. They are rows in arrays. This is the key performance choice.
  - States: `Horde` (follow flow field), `Attack` (hit a blocked tile), `Chase` (citizen nearby, M2), `Investigate` (heard noise, M3), `Roam` (wander, M3).
  - Each frame: read the flow-field direction at the zombie's cell, add a small separation push from neighbours (spatial hash), move. Full steps in DESIGN.md "Zombie movement and attacks".
  - Spatial hash: flat reused arrays, rebuilt every frame. Used for separation and (M3) tower targeting.
  - Attack check uses the Grid: if the next tile is a wall, closed gate or building, stop and attack it on a cooldown.
  - From M2: if a citizen is within the chase radius, the zombie chases it directly instead of following the field.
  - Types (Walker, Runner, Brute, Screamer, Crawler) are `ZombieDef` resources with speed, health, damage, wall damage multiplier.
  - Type-specific movement uses the same shared flow field. Differences live in the blocked check (for example, a Crawler treats barricade tiles as passable). No field per type.
  - Target: 500 zombies at 60 fps on a mid laptop. Stretch: 1000 (M6).
- **Depends on:** Flow field, Grid.
- **Milestone:** M1 (Walker, horde + attack buildings), M2 (chase), M3 (walls, roam, investigate), M5 (all types).

## 9. Flow-field pathfinding

- **What:** one shared path map that tells every zombie which way to walk to the city.
- **Data:** cost, integration and direction arrays. One shared field for all goals. Exact rules: DESIGN.md item 12.
- **How:**
  1. **Cost field:** terrain cost from TileSet data (ground 1, rubble 3), open gate 1, wall or closed gate = break cost. Water and map border = impassable.
  2. **Integration field:** Dijkstra with a bucket queue (Dial's algorithm) from all goal cells. Goals = Command Post and non-wall buildings only. Citizens are not goals.
  3. **Flow field:** each tile points to its cheapest neighbour.
  - Rebuild at most once per frame when the Grid has changed. Add a throttle only if the M1 benchmark shows a need.
  - 128 x 128 = 16k tiles. Budget: 8 ms. Benchmarked in M1. If too slow: worker thread with a copied cost array and double buffer, or a C#/GDExtension helper.
- **Depends on:** Grid.
- **Milestone:** M1 (no walls), M3 (wall break cost).

## 10. Horde director

- **What:** decides when and how many zombies come.
- **Data:** `WaveDef` list or a formula: day number -> horde size, type mix, spawn edge.
- **How:**
  - Ambient: keep N roamers on the map (N grows over days).
  - Horde nights: every 3rd night (tunable). Warning at dusk with the direction it comes from.
  - Spawns at the map edge outside player vision.
  - Reacts to the player: big noise or a large city raises pressure.
- **Depends on:** Clock, Zombie AI.
- **Milestone:** M1 (horde every night), M3 (horde nights, roamers), M5 (adaptive).

## 11. Infection

- **What:** bites infect citizens. Infection spreads unless handled.
- **Data:** on Citizen: `infection_stage` (0 none, 1, 2, 3), `infection_timer`, `known` (bool).
- **How:**
  - Zombie hit on a citizen: chance to infect based on zombie type.
  - Stage goes up every X hours. Medicine slows it. Stage 3 -> citizen dies and spawns a zombie on the spot.
  - Stage 1 is hidden. Stage 2 shows signs (slower work). A clinic with a medic reveals stage 1.
  - Quarantine building: infected inside cannot spread and do not turn into a free zombie in the streets.
  - Checkpoint refugees have a hidden infection roll.
- **Depends on:** Citizens, Zombie AI, Buildings.
- **Milestone:** M4.

## 12. Expeditions

- **What:** send teams to locations on a world map to bring back loot and survivors.
- **Data:** `LocationDef`: name, distance (hours), danger, loot table, unique finds. `Expedition`: team, gear, location, state, timer.
- **How:**
  - Team leaves through a gate, walks off the map, disappears from the city.
  - Off-screen sim: travel time, then a loot roll and a danger roll per hour on site.
  - Text events with choices (stored as `EventDef` resources).
  - Return: loot added, injuries applied, maybe a "followed" debuff that spawns zombies near the gate.
  - If not home by night: higher danger roll.
- **Depends on:** Citizens, Economy, Clock.
- **Milestone:** M4.

## 13. Combat and damage

- **What:** one shared way to deal damage.
- **How:** direct calls: `Building.take_damage()` and `ZombieManager.damage()`. Combat never goes through `EventBus`. How UI and audio hear about combat is decided when the first one needs it.
- **Milestone:** M1.

## 14. Noise and light

- **What:** zombies are drawn to noise, and to light at night.
- **How:**
  - Noisy things call `ZombieManager.alert(position, radius)` (gunfire, building, generators).
  - Zombies in radius switch to `Investigate` and steer straight to the noise point (same blocked check as chase). No extra flow field.
  - Light sources register with the night system. At night, roaming zombies drift towards lit areas inside a range.
  - Night visuals: `CanvasModulate` darkens the scene, `PointLight2D` for torches and floodlights.
- **Milestone:** M3 (noise), M4 (light).

## 15. Tech tree

- **What:** unlock buildings and upgrades.
- **Data:** `TechDef`: id, cost, requires (other techs), unlocks (building ids).
- **How:** blueprints found on expeditions plus scrap. UI is a simple tree screen.
- **Milestone:** M5.

## 16. UI and HUD

- **Top bar:** resources, day, time, speed buttons.
- **Bottom bar:** build menu by category (Housing, Food, Industry, Defense, Services).
- **Side panel:** selected building or citizen info.
- **Alerts:** horde warning, wall under attack (click to jump), infection found, expedition back.
- **Screens:** main menu, pause, settings, expedition map, tech tree, game over.
- Built with Godot `Control` nodes and a shared `Theme`. Large readable font (dyslexia friendly option, see Settings).
- **Milestone:** M1 (basic top bar + build menu), grows each milestone.

## 17. Save and load

- **What:** save the whole game to a file and load it back.
- **How:**
  - Each saveable thing has `to_dict()` and `from_dict()`.
  - `SaveManager` autoload collects all into one dictionary, writes JSON to `user://saves/slot_N.json`.
  - Includes a `version` number and the seeds/states of each system's own `RandomNumberGenerator`, so loading does not reroll known outcomes. Zombie movement is not deterministic, and that is fine. Old saves get migrated or rejected with a message.
  - Zombie arrays saved as base64 of `var_to_bytes()`. Flow field and spatial hash are rebuilt on load, not saved.
  - Never load a save as a Godot Resource (they can contain scripts).
  - Autosave at each dawn.
- **Milestone:** M5.

## 18. Audio

- **What:** music and sound effects.
- **How:** `AudioManager` autoload with buses `Master`, `Music`, `SFX`, `UI`. Music changes with day/night/horde. Zombie groans are pooled (max ~16 voices) so hundreds of zombies don't overload audio.
- **Milestone:** M6 (placeholder sounds earlier are fine).

## 19. Settings

- **What:** player options.
- **Options:** volume per bus, fullscreen, UI scale, font choice (includes a dyslexia-friendly font such as OpenDyslexic), edge scroll on/off, key bindings, auto-close gates at dusk.
- **How:** saved to `user://settings.cfg` with `ConfigFile`.
- **Milestone:** M5.

## 20. Debug tools

- **What:** speed up testing.
- **How:** debug overlay (F3): fps, zombie count, flow-field arrows, grid costs. Cheat keys: spawn horde, add resources, skip to night. Only in debug builds.
- **Milestone:** M1.
