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
- Measured flow-field rebuilds, Walker updates and frame times during repeated gate changes with 500 Walkers on the reference PC. [Results and replay command](benchmarks/windows-desktop-500-walkers.md#gate-changes-with-500-active-walkers).
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
- Playable now: mark a residential plot on either side of a bend ([#68](https://github.com/J3vb/zombie-city-builder/issues/68)). Face the entrance toward the street, reserve the house and its entrance, and reject overlapping plots. Allow an empty plot to be removed and explain why an occupied plot prevents road removal.
- Playable now: a tent grows into a shack and brick house on the same confirmed plot. Farms and storage grow in painted zones and advance through all three stages using placeholder models ([#75](https://github.com/J3vb/zombie-city-builder/issues/75)). Staffed farm output is playable in M2. Each completed storage tier increases town capacity in M2.
- Playable now: click a roof to inspect the building's health, level, upgrade cost, unlock day and current blocker ([#74](https://github.com/J3vb/zombie-city-builder/issues/74)).
- Playable now: place a one-tile garden or a two-by-two scrap workshop on its own site, anywhere the building footprint is clear. Each can be inspected and demolished independently ([#77](https://github.com/J3vb/zombie-city-builder/issues/77)).
- Playable now: construction and upgrades draw on starting stock and staffed production.
- Art: the tent, shack and brick house models and their shared materials are on main ([#65](https://github.com/J3vb/zombie-city-builder/pull/65)). Station 4 now uses its fire-station model in the playable town. Farm and storage models, the Walker and props remain.
- Verify the Windows x64 game after the art pass.

**Done when:** you can draw a bend, mark two road-facing plots on it, watch a home reach level 3, and watch a horde attack the town at night in 3D, at 60 fps with 500 active Walkers on the reference desktop at 1080p.

## M2: Living town

Goal: citizens make the economy run.

- Citizens with needs (food, water, sleep), pathfinding with AStarGrid2D. Named residents now walk from a road-facing home to a reachable worksite. Food and water rations and dusk shelter are playable. Residents now sleep after reaching a shelter. A short night reduces the following day’s work pace.
- Playable now: Walkers pursue the closest exposed civilian within four tiles and deal contact damage on a cooldown ([#15](https://github.com/J3vb/zombie-city-builder/issues/15)).
- Playable now: automatic and manual worker assignment for gardens, farms, wells, lumber yards and scrap workshops. Each person works at most one completed shift per day.
- Playable now: the Station 4 builder travels to paid construction sites, completes buildings and upgrades over time, and returns at dawn to resume unfinished work. Inspect or cancel an order ([#17](https://github.com/J3vb/zombie-city-builder/issues/17)).
- Playable now: staffed production supplies food, water, wood and scrap at dawn. Completed storage increases capacity. Missed rations slow work until the next fully fed and watered dawn.
- Five-day economy check passed with ten people, two fields and three other workplaces. It starts with finished sites, pauses automatic growth and disables hordes. The replay also checks ration shortages and recovery.
- Playable now: workers and the builder shelter at dusk or when threatened, resume after danger clears, and become exposed if their shelter falls. Death releases the bed and job. Losing every resident ends the game ([#20](https://github.com/J3vb/zombie-city-builder/issues/20)).
- Fresh-start survival trial: at seed 4, three people had moved in by the first night. The 30-Walker wave destroyed Station 4 before dawn two. The defended opening below uses the same seed.

**Economy acceptance:** ten citizens can feed and water themselves for five days. Run `scenes/tests/supply_town.tscn` or the automated supply economy test.

## M3: Walls and defense

Goal: the core fantasy. Build walls, hold the line.

- Playable: drag barricades and palisades, preview the cost, pay for the entire line and have the builder complete it tile by tile (#21).
- Playable: gate tiles allow street crossings, manual opening and closing, and optional dusk closing. Closing waits for traffic to clear (#22).
- Playable: the Walker flow field weighs a breach by tier. Walkers use the open gate or attack a cheaper barrier when it closes. Destroyed segments reopen immediately (#23).
- Builders repair reachable damaged segments in daylight when the area is clear (#24). Rebuild destroyed segments with a paid order.
- Both tower types need a defender and ammo. The rifle tower reaches farther. Assign a named sentry to a completed palisade for close defense without ammo (#25, #26).
- A dusk warning gives the approach edge on every third night. Smaller groups arrive on the other nights (#27).
- Tower gunfire draws nearby Walkers toward the shot until the sound expires or they reach it (#28).

**Earlier five-night opening.** Two posted defenders, a gated barricade and three residents reached dawn six against waves of 30, 40, 50, 60 and 70. Station 4 retained all 500 HP and the town had 2 ammo left. The matching undefended replay lost on night one.

**Ten-night opening passed.** A lumber yard, scrap workshop and three staffed watchtowers held the north, east and north major waves on nights 3, 6 and 9. Four people reached dawn 11 with 12 food, 12 water and six rounds. Separate regression tests exercise wall damage, repair safety, breaches and sentry loss.

## M4: The outside and infection

Goal: the risky choices.

- The Veydam Basin map has six destinations, including two Veydam City sites. Send two to four residents with provisions and optional medicine. Watch them meet at an open gate, leave the map, and return through an open gate.
- Each location has its own search rolls and radio decision. Waiting for a player decision pauses the team. Choosing to stay can bring injuries, extra loot or pursuers.
- Returned teams deliver supplies once and can bring a named survivor to Station 4. Vacant home plots can house people displaced or recruited earlier.
- The Ember progresses through hidden Warm, visible Fever and Burn. A staffed clinic can detect a case and spend medicine to delay it. The Cold Room contains a resident who reaches a bed.
- Staff a checkpoint gate, wait for an inspection and choose admission, isolation or refusal. A medic can detect a Warm visitor that a guard alone would miss.
- Fuel from expedition sites powers generators. Night floodlights illuminate the town and attract nearby Walkers while supply meets demand. Switch individual sites in Services.

**15-day replay passed.** Two workers left for Halbo on day 7, Verbeek Farm on day 10 and the Police Post on day 13. Opening the stockroom and cell brought recruits and followers. At the farm the team chose grain and left the family. Six people reached dawn 16, with 46 water, three rounds, no stored food and Station 4 at full health. A separate fixture covers rare Ember turns and checkpoint decisions.

## M5: Depth and polish

Goal: a game you can keep playing.

- Walkers, Runners, Brutes, Screamers and Crawlers share the crowd simulation. Faster Runners appear from day 6, Crawlers from day 9 and the other two types from day 12.
- The director sets wave pressure at dusk from population, recent casualties and gunfire. The announced approach remains fixed through nightfall.
- Trade expedition blueprints and scrap for Fortify, Rebuild and Reclaim. Research improves wall repairs and fuel efficiency and unlocks the radio tower.
- Save and load, autosave
- Settings screen (audio, UI scale, dyslexia font, keys)
- Main menu, pause, game over screens
- Build the researched radio tower using Relay Station parts, then call Haven Point. Continue the same settlement in endless mode.
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
