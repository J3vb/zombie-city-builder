# Roadmap

Small steps. Each milestone ends with something you can play.
Every milestone becomes a GitHub milestone, every bullet becomes an issue.

System details: [SYSTEMS.md](SYSTEMS.md). Game rules: [GDD.md](GDD.md).

---

## M0: Project setup

Goal: an empty Godot project that opens, runs and passes CI.

- Godot 4.5 project, folder layout, autoload stubs
- GitHub Actions: lint, format check, headless import, smoke test
- README, CLAUDE.md, docs

**Done when:** the game window opens with a placeholder checkerboard map and a clock, CI is green.

## M1: Playable prototype ("can I survive one night?")

Goal: prove the core idea with ugly placeholder art.

- Game clock with day/night and speed buttons
- 128 x 128 grid map with camera pan and zoom
- Place buildings instantly (no builders yet): house, farm, storage
- Resource stockpile with top-bar display
- Zombie manager: 500 zombies as arrays, drawn with MultiMesh
- Flow field to the city (no walls yet)
- Simple horde: zombies spawn at night at the map edge
- Zombies damage buildings; Command Post destroyed = game over
- Debug overlay (fps, zombie count, flow arrows)
- Benchmark: flow-field build time and zombie update time
- Light test: 30 lights + 500 zombies on the Compatibility renderer
- Game-over screen and restart

**Done when:** you can place buildings and watch a horde reach and destroy them at 60 fps with 500 zombies.

## M1.5: 3D city

Goal: the M1 game in 3D, with buildings that upgrade and a dark, gritty look. The owner chose this after playing M1.

- Desktop render benchmark complete ([#64](https://github.com/J3vb/zombie-city-builder/pull/64)). The sole hardware target is Windows x64 on the owner's Ryzen 9 7950X3D and RTX 4080 Super.
- Playable now: 3D terrain, building placeholders and 2D simulation grid.
- Playable now: camera pan, orbit, tilt, zoom and ground picking for placement.
- Walkers use one 3D MultiMesh. Add directional movement animation with the Walker art pass.
- Day/night sun, fog and night lighting
- Playable now: draw a curved street from Station 4 ([#67](https://github.com/J3vb/zombie-city-builder/issues/67)). Preview, cancel and commit the curve, join two ends or make a T-junction. Validate the full road width against terrain and occupied cells.
- Mark a residential plot on either side of a bend ([#68](https://github.com/J3vb/zombie-city-builder/issues/68)). Face the entrance toward the street, reserve space for the backyard and reject overlapping plots. Allow an empty plot to be removed and explain why an occupied plot prevents road removal.
- Grow a tent, shack and brick house on the same confirmed plot. Keep farmland and storage as painted zones with automatic growth and upgrades.
- Selection panel that shows a building's level and what its next upgrade waits for
- Temporary daily income so upgrades can be tested before M2's production
- Gritty low-poly art kit: materials, building models per level, zombie mesh, props
- Verify the Windows x64 game after the art pass.

**Done when:** you can draw a bend, mark two road-facing plots on it, watch a home reach level 3, and watch a horde attack the town at night in 3D, at 60 fps with 500 active Walkers on the reference desktop at 1080p.

## M2: Living town

Goal: citizens make the economy run.

- Citizens with needs (food, water, sleep), pathfinding with AStarGrid2D
- Zombies chase citizens within 4 tiles
- Job board and job assignment
- Builders build construction sites over time
- Production buildings: farm, well, lumber yard, scrap yard
- Daily upkeep and shortages
- Citizens flee to homes at night

**Done when:** a town of 10 citizens can feed itself for 5 days.

## M3: Walls and defense

Goal: the core fantasy. Build walls, hold the line.

- Drag-to-draw walls and barricades
- Gates (open, closed, auto-close at dusk)
- Flow field with wall break cost; zombies attack walls
- Wall damage, repair by builders
- Watchtower and rifle tower with ammo
- Defender job (citizens on walls)
- Horde nights every 3rd night with a warning and direction
- Noise system (gunfire draws zombies)

**Done when:** you can survive 10 days by building and fixing walls.

## M4: The outside and infection

Goal: the risky choices.

- Expedition screen: locations, team pick, timers
- Loot and text events with choices
- Survivors found and brought home
- Infection stages, clinic, medicine, quarantine
- Checkpoint gate with refugee inspection
- Power: generators, fuel, floodlights
- Night lighting (light draws zombies)

**Done when:** a full 15-day run has at least 3 real "hard choice" moments.

## M5: Depth and polish

Goal: a game you can keep playing.

- All zombie types (runner, brute, screamer, crawler)
- Adaptive horde director
- Tech tree with blueprints
- Save and load, autosave
- Settings screen (audio, UI scale, dyslexia font, keys)
- Main menu, pause, game over screens
- Win condition (campaign goal) and endless mode
- Balance pass

**Done when:** a 30-day run is fun and saves/loads without bugs.

## M6: Content and release prep

Goal: something you can share.

- Real art (replace the low-poly kit with final models)
- Music and sound effects
- Second map, or a map generator
- Tutorial (first 3 days guided)
- Package the Windows x64 game in CI ([#48](https://github.com/J3vb/zombie-city-builder/issues/48)).
- Performance pass (target 1000 zombies)

**Done when:** a stranger can download, learn and play it.

---

## Not planned (for now)

- Multiplayer
- Direct control of expedition teams
- Mod support
