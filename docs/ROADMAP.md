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

- Real art (tiles, buildings, units)
- Music and sound effects
- Second map, or a map generator
- Tutorial (first 3 days guided)
- Windows and Linux export in CI
- Performance pass (target 1000 zombies)

**Done when:** a stranger can download, learn and play it.

---

## Not planned (for now)

- Multiplayer
- 3D graphics
- Direct control of expedition teams
- Mod support
