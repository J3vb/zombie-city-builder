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
- **Data:** `StarterMap.generate(map_def)` returns one terrain ID per cell. `Grid` holds those IDs, their travel costs from `data/terrain/terrain_set.tres`, and the occupancy overlay used by building placement and horde routing.
- **How:** the starter map has 128 × 128 cells of 32 simulation units. MapDef supplies the dimensions, tile size and terrain rectangles. Borders take precedence over water, then rubble, then ground. The playable world builds colored terrain meshes from Grid's terrain IDs in 16 × 16 chunks. Each tile spans four metres in the view.
  Grid maps a cell to its center and maps a simulation position back with floor division. Grid accepts a whole building footprint at once. An overlap or blocked cell rejects the claim. Releasing a footprint restores the terrain cost only on cells owned by that building.
- **Depends on:** nothing.
- **Milestone:** M1.

### Streets

Select Street and click control points on the ground. Enter commits the preview, Backspace removes the last point and Esc cancels. The gold marker identifies the Station 4 entrance. A street endpoint can join an existing end or branch from the middle of a street. The junction splits the routing graph while the original street retains its ID. The grid reserves the full corridor against construction and gives its cells a walking cost of one. Removing the last street on a cell restores the terrain cost.

### Road-facing plots and automatic growth

Each confirmed home plot stores its street ID, attachment point, frontage polygon, oriented house footprint and entrance cell. The preview marks the entrance in gold. Confirming a plot is free. Its reserved cells exclude other construction, while only the house itself blocks walkers. A home faces the street through every upgrade. A disconnected street cannot supply a new plot.

The grower rotates through upgrades, housing, farms and storage during daylight. It skips an unavailable site and saves up on a valid turn that lacks resources. A tent costs 20 wood. From day two, a shack costs another 30 wood and 10 scrap. From day four, brick costs another 40 wood and 30 scrap. Upgrades keep the same footprint and health fraction. Expansion uses wood from staffed lumber yards and scrap from staffed workshops. Paint at least a 3 × 3 area for a farm or a 2 × 2 area for storage. Both can grow through three stages.

Select Garden or Scrap workshop and click a clear footprint to order construction. A garden occupies one tile and costs 10 wood. A workshop takes 2 × 2 tiles and costs 20 wood and 10 scrap. Both can be placed before the first home. They have their own health, footprint and demolition refund. During M2 a staffed garden or workshop pays its completed shift at dawn.

Demolishing refunds half the initial construction cost once. A demolished home leaves its residential plot reserved. Remove Plot releases empty land. Removing a street clears its vacant plots. The game prevents removal of any road that would leave an occupied home without access to Station 4. Unzone leaves existing farm and storage buildings standing.

Run `res://scenes/tests/frontage_town.tscn` for a playable bend with a junction, two accepted home plots and a rejected overlap.

## 3. Building placement

- **What:** pick a building, see a ghost preview, place it, it gets built over time.
- **Data:** `BuildingDef` resource per building: id, name, size (cells), cost, build time, health, job slots, scene.
- **How:**
  - Ghost follows mouse, snaps to grid. Blocked or too expensive: turns red **and** shows a cross icon (not colour alone).
  - Walls use drag-to-draw (click start, drag, release) along a straight line.
  - On place: resources are reserved, a construction site appears, builders walk there and add work.
  - When done, the site swaps to the real building and the grid updates. Pathfinding gets a "dirty" signal.
  - The playable town uses `World.try_place_building()` for paid placement. It checks the footprint, nearby Walkers and stock. Map setup uses `World.spawn_building()` for unpaid placement. Both claim cells through Grid.
  - Demolition refunds 50 percent once. Enemy damage that destroys a building releases its cells without a refund. Read `Building.sim_bounds()` and `sim_center()` for targeting and placement. The building scene has a separate child for drawing and the damage bar.
- **Depends on:** Grid, Resources.
- **Zones and upgrades (M1.5):** the player draws curved streets, marks road-facing residential plots, and paints farmland and storage zones. The `Grower` grows homes on confirmed plots and farm or storage buildings in their zones and upgrades buildings through their `levels` (`BuildingLevelDef`: model, health, upgrade cost, unlock day). Same footprint at every level. Instant in M1.5, done by builders from M2. Walls, gates and towers stay hand-placed.
- **Milestone:** M1 (instant build), M1.5 (3D, upgrades), M2 (builders).

### Timed construction

Station 4 houses one dedicated builder who shares the town's food and water rations. Paid placement claims the footprint and debits the order once. The grower uses the same path for homes and zoned sites. Upgrades reserve their materials and keep the existing bed or production level active. An order takes its building definition's build time multiplied by the target level.

The builder picks the first reachable order, walks along the resident routing grid, then adds work on site. At dusk the builder returns to Station 4. Unfinished work persists overnight and through route changes. Completion keeps the building's identity and grid claim. A newly finished house grants its bed once, while an upgraded house retains its tenant. The inspector shows the target, progress and builder status. Canceling returns the unworked fraction of each paid resource rounded down. Canceling an upgrade keeps the existing building. Walkers can destroy a site with no refund.

## 4. Resources and economy

- **What:** stockpile of food, water, wood, scrap, fuel, medicine, ammo. Power is a live value, not stored.
- **Data:** autoload `Economy` with `Dictionary[StringName, int]`. Station 4 holds 100 of each resource. Each completed storage building contributes 40, 80 or 140 at tiers one through three. An upgrade replaces its previous contribution. Destroying storage preserves existing stock and blocks further deposits until there is room. Returning paid materials on cancellation or demolition can exceed capacity.
- **How:**
  - `can_afford(cost)`, `spend(cost)`, `add(id, amount)`. Emits `resource_changed(id, value)`.
  - Staffed sites deliver completed shifts at dawn. New deliveries enter only up to the available per-resource capacity. The dawn report lists any discarded overflow.
  - Daily upkeep at `day_started`: each citizen eats 1 food and drinks 1 water.
  - Each missed food or water ration slows that resident’s work by 10 percentage points, down to 50%. Receiving both rations restores full pace. This affects production and construction. Health and morale are future systems.
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

### Playable first shifts

A home on confirmed frontage houses one named resident. A displaced resident can shelter at Station 4 and takes a vacant bed before a new resident joins. Each garden, farm, well, lumber yard or scrap workshop offers one job. The world job board assigns the nearest reachable vacancy. The building inspector can transfer a named worker or pause hiring. Grid passability and terrain weights feed a four-direction A* route to a free edge cell. A layout change invalidates the route. Residents leave for shelter after their shift or at dusk.

A shift needs 60 seconds of on-site work at full pace. Reassignment, demolition or dawn discards unfinished work. A completed shift survives demolition and pays once the next dawn, before each resident uses one food and one water. A garden produces 4 food, a farm produces 6, 9 or 12 food, a well produces 12 water, a lumber yard produces 16 wood and a scrap workshop produces 4 scrap. The HUD shows stored output, overflow, rations and shortages. Inspect an affected resident or Station 4 to see the reduced work pace.

Residents need 60 seconds of sleep between dusk and dawn. Time spent walking, blocked or on watch earns no sleep. A short night reduces the next day’s work pace by 20 percentage points, down to the shared 50% minimum. A full night clears fatigue. The home and Station 4 inspectors show sleep and fatigue.

### Civilian danger and shelter

Each Walker pursues the closest exposed person within four tiles. A building in its path still takes hits. At contact, a Walker deals 8 civilian damage once per attack cooldown. Civilians start with 40 health. A hit does not pass through a blocked corner. Reaching shelter protects the occupant until they leave or the building falls.

Workers head for their own home or Station 4, choosing the shorter reachable route in danger. The builder returns to Station 4. The amber marker and HUD warn of danger. Work pauses during flight, and unfinished construction stays claimed. After reaching safety, residents resume daytime work when the area clears. At dusk they stay inside. Death frees the bed and job. A surviving resident takes over a lost builder’s queue and eats one ration like everyone else. The loss screen distinguishes an empty town from the destruction of Station 4.

Run the staffing and crowd benchmark on the reference PC with `godot --path . --resolution 1920x1080 --disable-vsync --script res://tests/bench_residents.gd`. It builds and staffs 50 homes and workplaces, then measures six seconds with 500 active Walkers after a two-second warmup. Its Walkers deal zero civilian damage to hold the measured population constant while pursuit and flight run. The fresh-start replay and normal game use full damage.

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

### Playable perimeter

The grid holds one segment record per claimed cell. A shared mesh draws the whole line. Barricades cost 2 wood per tile, palisades cost 4 wood and 1 scrap, and gates cost 3 wood and 1 scrap. The builder works at a reachable neighbor. Stakes reserve the land immediately and allow traffic until the segment is complete. Use Demolish to cancel an unfinished segment and reclaim the unused fraction. Enemy destruction gives no refund.

A completed gate starts open. Manual closing and the optional dusk close both wait for the crossing to clear. Opening or breaching a gate restores the road or ground cost. Citizens use live passability. Walkers plan against a separate snapshot with fixed breach costs of 18 for barricades, 30 for gates and 48 for palisades. Live collision and damage still use the actual grid while a replacement flow field builds.

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

### Playable watchtower

One completed tower offers one job. An assigned resident walks to the platform, stays on duty at dusk, and gives up their production slot. The post protects its occupant until it falls. Each available shot targets the nearest living Walker within 16 tiles using the current crowd update. The watchtower deals 30 damage, has a 0.6-second cooldown and consumes one round. An empty post, empty magazine or empty range consumes nothing. The inspector shows the defender, range, shots fired and supply problems.

A new town starts with 36 ammo. The Station 4 inspector exchanges 2 scrap for a batch of 24 only when there is room for the full batch. The defended opening makes supplies and assignments before the night starts.

Palisades have an optional sentry slot in the wall inspector. A guard walks to the segment and fights within 1.8 tiles. A breach releases the guard immediately. The rifle tower reaches 23 tiles, the watchtower 16. A shot alerts nearby Walkers for up to six seconds. A visible civilian takes priority over sound.

Builders finish queued construction first, then travel to a damaged segment by daylight. They restore six HP per work second when no living Walker is within four tiles. Danger interrupts the repair and the builder checks again after the area clears. A destroyed segment needs a new paid order.

## 8. Zombie AI

- **What:** hundreds of zombies, cheap per unit.
- **Data:** one `ZombieManager` node holds arrays of position, velocity, health, type, state. The manager publishes the living rows in one batch after removing deaths. A scene child draws the packed batch with one `MultiMeshInstance3D`.
- **How:**
  - Zombies are **not** individual nodes. They are rows in arrays. This is the key performance choice.
  - States: `Horde` (follow flow field), `Attack` (hit a blocked tile), `Chase` (citizen nearby, M2), `Investigate` (heard noise, M3), `Roam` (wander, M3).
  - Each frame: read the flow-field direction at the zombie's cell, add a small separation push from neighbours (spatial hash), move. Full steps in DESIGN.md "Zombie movement and attacks".
  - Spatial hash: flat reused arrays, rebuilt every frame. Used for separation and (M3) tower targeting.
  - Attack check uses the Grid: if the next tile is a wall, closed gate or building, stop and attack it on a cooldown.
  - From M2: if a citizen is within the chase radius, the zombie chases it directly instead of following the field.
  - Types (Walker, Runner, Brute, Screamer, Crawler) are `ZombieDef` resources with speed, health, damage, wall damage multiplier.
  - Type-specific movement uses the same shared flow field. Differences live in the blocked check (for example, a Crawler treats barricade tiles as passable). No field per type.
  - Target: 500 zombies at 60 fps on the reference Windows desktop. Stretch: 1000 (M6).
- **Depends on:** Flow field, Grid.
- **Milestone:** M1 (Walker, horde + attack buildings), M2 (chase), M3 (walls, roam, investigate), M5 (all types).

## 9. Flow-field pathfinding

- **What:** one shared path map that tells every zombie which way to walk to the city.
- **Data:** cost, integration and direction arrays. One shared field for all goals. Exact rules: DESIGN.md item 12.
- **How:**
  1. **Cost field:** terrain cost from TerrainSet (ground 1, rubble 3), open gate 1, wall or closed gate = break cost. Water and map border = impassable.
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

The director announces the approach edge at dusk before nights 3, 6 and 9, then spawns that major wave along the announced edge. The other nights send one fifth of the major-wave count from across the border. These values are configurable in BalanceDef.

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

Bites and expedition injuries may start the Ember. Every 36 simulation hours it advances one stage. Fever costs 25 percentage points of work pace. A staffed clinic reveals hidden cases in town. Giving a diagnosed resident one medicine delays progression by 18 hours. A Cold Room provides two quarantine beds. A resident must reach the ward before it contains a turn. Losing the ward releases its occupants.

Every third dawn a checkpoint with a free pen can receive a refugee. A posted guard needs an hour of on-site time to inspect them. Fever is visible under the lamp. Diagnosing Warm requires a staffed clinic. The player can admit the visitor, reserve a reachable Cold Room bed, or send them away.

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

Select Expeditions on the HUD to open the Veydam Basin map. One team of two to four residents can travel at a time. The Station 4 builder remains available in town. Departure costs one food and one water per traveller. A medical kit uses one medicine and prevents one injury. Before the team leaves the map, Recall returns its provisions. Travellers give up their job assignments and walk through a completed open gate to the map edge. Off-map travellers use their packed rations.

Each search hour rolls local loot and injury risk, doubled at night. Every destination has a distinct decision. Finishing the trip brings the team back at the original map edge. A blocked return waits for a reachable open gate. Only when the team reaches it does the town receive loot and any recruited survivor. The town stock limit still applies.

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
  - The clock drives the 3D sun, ambient lighting and fog. Torches and floodlights are later visual and gameplay work.
- **Milestone:** M3 (noise), M4 (light).

A connected fuel generator supplies four units for six running hours per fuel. Each switched-on floodlight requests two units at night. Insufficient supply darkens all lamps. The Services panel lists each generator and light and displays current supply, demand and fuel. A powered light illuminates the 3D town and attracts Walkers within ten tiles.

## 15. Tech tree

- **What:** unlock buildings and upgrades.
- **Data:** `TechDef`: id, cost, requires (other techs), unlocks (building ids).
- **How:** blueprints found on expeditions plus scrap. UI is a simple tree screen.
- **Milestone:** M5.

In Services, open Research and radio. Fortify doubles safe wall repair speed. Rebuild makes a fresh can of generator fuel last 50% longer. Reclaim unlocks the radio tower. Each step consumes a blueprint and scrap and requires the previous step. Complete a tower with radio parts from the Relay Station and transmit to Haven Point. The call pauses the clock and records the win. Endless resumes the existing town, or can be selected before making the call.

Later waves mix fast Runners, wall-breaking Brutes, noise-making Screamers and low Crawlers that fit under barricades and take less ranged damage. From day six, the director forecasts strength at dusk using settled population, recent losses and accumulated noise. The shared path field stays in use across all five types.

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
