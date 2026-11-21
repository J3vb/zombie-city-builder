# Game Design Document

Game name: **Hold the Gates**.

Short sections. Read top to bottom once, then use it as a lookup.
Story, world and names: [LORE.md](LORE.md).

---

## 1. The pitch

You lead a small group of survivors after the outbreak.
Build a town inside walls, keep people fed and healthy, send teams out to scavenge the ruins, and hold the walls when the dead come.

The city grows. The dead grow faster. Every wall you build is a promise you have to keep.

## 2. Design pillars

These are the rules we check every feature against.

1. **The wall is the heart.** Walls, gates and checkpoints are the main tool, not an afterthought. Where you build them is the biggest decision in the game.
2. **Every survivor counts.** Citizens are few and named. Losing one hurts. Infection makes you choose.
3. **Outside is dangerous but needed.** You can't win by hiding. The best resources are out in the ruins.
4. **Readable chaos.** Hundreds of zombies on screen, but you always see what is happening and why.
5. **Small, then deep.** Easy to start, many systems to master later.

## 3. Camera and look

- 3D, with a city-builder camera like Cities: Skylines: pan, rotate, zoom and tilt. The game still runs on a tile grid underneath.
- You paint zones (housing, farmland, storage) like SimCity; buildings grow and upgrade on their own in visible steps (tent, shack, brick house).
- Dark and gritty, mid-apocalypse: rust, scrap walls, wrecked cars, dead trees, fog, fires.
- Readable first: zombies and walls always stand out, even at night.
- Night is dark. Light sources (fires, floodlights) set the mood from M1.5 and start to matter for gameplay in M3/M4.

> Why 3D? The owner played the 2D prototype (M1) and wanted a real city feel with buildings you can watch grow. The logic stays 2D, so the zombie numbers still work.

## 4. Core loop

```
 BUILD  ->  GATHER  ->  MANAGE  ->  DEFEND
   ^                                   |
   +-----------------------------------+
```

- **Build:** paint zones (homes, farms, storage) and let buildings grow; place walls, gates and towers by hand.
- **Gather:** citizens work jobs inside. Expedition teams scavenge outside.
- **Manage:** food, water, health, morale, infection, power.
- **Defend:** zombies roam and probe the walls. Big hordes hit at set times.

### One day in the game

| Phase | What happens |
|---|---|
| Morning | Plan. Assign jobs. Send expeditions. |
| Day | Citizens work. Zombies are slow and scattered. Build and repair. |
| Dusk | Warning. Expeditions should be home. Man the walls. |
| Night | Zombies are faster and drawn to light and noise. Horde nights hit hardest. |

## 5. Win and lose

- **Lose:** the last citizen dies or turns, or the town hall (Command Post) falls.
- **Win (campaign map, M5):** survive N days, or reach a goal like "fix the radio tower and call for rescue".
- **Endless mode (M5):** survive as long as possible. Score = days survived + people alive.

## 6. Resources

| Resource | From | Used for |
|---|---|---|
| Food | Farms, hunting, scavenging | Feeding citizens |
| Water | Wells, rain collectors | Drinking, farms |
| Wood | Lumber yard, scavenging | Basic buildings, barricades |
| Scrap | Scavenging, salvage yard | Walls, tools, towers |
| Fuel | Scavenging, later a refinery | Generators, vehicles |
| Medicine | Scavenging, clinic (craft) | Healing, slowing infection |
| Ammo | Workshop (from scrap) | Towers, armed defenders |
| Power | Generators (uses fuel) | Floodlights, electric fences |

Rare items (radio parts, vehicle parts, blueprints) are only found outside. They unlock tech.

## 7. Citizens

- Each citizen has a name, health, hunger, morale and a skill (farmer, builder, fighter, medic, scavenger).
- Citizens need a home bed, food and water each day.
- Jobs: assigned automatically to free buildings, or by hand.
- New citizens arrive as survivors found on expeditions, or as refugees at the gate (risky, see Checkpoints).

## 8. Infection

The key twist. Infection is a resource you manage, not just a game over.

- Bitten citizens become **Infected**. They hide it at first.
- Infected stage 1 to 3 over a few days. Stage 3 = turns into a zombie **inside** the walls.
- Medicine slows it. A clinic can detect it. Quarantine stops spread.
- Refugees at the gate may carry infection. **Checkpoints** let you inspect before letting them in.
- Hard choice: turn people away, quarantine, or risk it.

## 9. Walls, gates and checkpoints

- **Barricade:** cheap wood, weak, fast to build.
- **Wall:** scrap, strong, slower.
- **Gate:** lets citizens and expeditions pass. Can be opened or locked. Weak point.
- **Checkpoint:** a gate with a holding area. Newcomers wait there to be inspected. Needs a guard.
- **Watchtower:** sits on walls, gives vision and a ranged defender slot.
- Walls take damage and need repair. Builders repair between waves.
- Zombies attack the easiest way in. Open gates are easiest, then cheap walls (barricades), then strong walls. You can build a deliberate weak point (a "kill zone") to steer them.

## 10. Defense

- **Defenders:** citizens with the fighter job, posted on walls and towers.
- **Towers:** need a defender and ammo. Types: rifle tower, spotlight tower, later flame and noise lure.
- **Traps:** spike pits, noise makers that pull zombies away, fire trenches.
- Defense uses ammo. No ammo = only melee at the wall.

## 11. Zombies

| Type | Trait |
|---|---|
| Walker | Slow, common. Comes in groups. |
| Runner | Fast, weak. Finds gaps. |
| Brute | Slow, huge health, smashes walls. |
| Screamer | Weak, but its scream pulls nearby zombies to it. |
| Crawler | Low, hard to hit, slips under barricades. |

Behaviour:
- **Roaming:** small groups wander the map, drawn by noise and light.
- **Probing:** if they find the wall, they hit it and gather more.
- **Hordes:** every few nights a big wave marches from the map edge straight to the city.
- Noise (gunfire, construction, generators) and light at night attract them. This is a real trade-off.

## 12. Expeditions

- Pick a team (2 to 4 citizens), gear and a map location.
- Locations: supermarket, hospital, police station, gas station, farm, relay station (radio parts)...
- Outcome is simulated off-screen with a risk roll and short text events ("They found a survivor. Bring her back?").
- Risks: injury, bites, death, getting followed home by a horde.
- Later option: control the team directly on the map (stretch goal).

## 13. Progression

- **Zones and upgrades:** you paint zones; buildings grow on them and upgrade by themselves through 3 levels. Each level costs resources (paid automatically), unlocks on a set day, and gives more health and capacity (beds, storage, output). Walls, gates and towers are still placed by hand.

- **Tech tree** unlocked with blueprints found outside plus scrap.
- Tiers: Survive (wood, farms) -> Fortify (walls, towers, workshop) -> Rebuild (power, clinic, vehicles) -> Reclaim (clear zones, radio, rescue).
- **Districts:** the map is split into districts. Clearing a district removes its zombie spawns and opens new building land.

## 14. Difficulty

- Settings: horde size, infection speed, resource scarcity.
- Days 1 to 3 are a tutorial pace. Hordes ramp up over time.

## 15. What this game is NOT

- Not a shooter. You don't aim.
- Not a pure tower defense. Economy and people matter as much as towers.
- Not a copy of any existing game. Names, art and systems are our own.

## 16. Open questions

- Fixed map or generated map? (Plan: hand-made first map, generated later.)
- Do citizens have relationships/families? (Nice to have, later.)
- Multiplayer? (No. Out of scope.)
