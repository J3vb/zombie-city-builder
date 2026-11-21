# Lore Review Report (Elephant-Goldfish)

How `docs/LORE.md` was reviewed, what the reviewers found, and what changed.

Method: [Elephant-Goldfish Model](https://github.com/google/elephant-goldfish-model) (Google, Apache-2.0).
The **Elephant** (the drafting session, with full context) wrote the lore. **Goldfish** reviewers are fresh agents with no chat history. Each read the docs and one reviewer persona from the EGM repo, adapted from software design to game lore. The author (you) makes the final calls.

- **Target:** `docs/LORE.md` (checked against `GDD.md`, `SYSTEMS.md`, `ROADMAP.md`)
- **Date:** 2026-11-21
- **Mode:** consolidated, two rounds

## Stages run

| Stage | Reviewer | Result |
|---|---|---|
| Round 1 | Zoom Out (scope and YAGNI) | 0 blockers, 7 major, 3 nits |
| Round 1 | Comprehension (fresh reader, LORE.md only) | 0 blockers, 8 major, 7 nits |
| Round 1 | Design Critic (rules match, logic, originality) | 0 blockers, 9 major, 5 nits, 7 missed chances |
| Round 1 | Style and Structural (dyslexia-friendly, naming) | 0 blockers, 6 major, 10 nits |
| *Fix round 1* | Elephant | LORE.md rewritten |
| Round 2 | Design Critic (fresh) | 0 blockers, 8 major, 6 nits |
| *Fix round 2* | Elephant | Fixes below, GDD expedition list aligned |

## Consolidated actions

Priority: 🔴 Blocker, 🟡 Major, 🟢 Nit. Status: ✅ fixed, ⚖️ kept with reason, ❓ left for you.

### Lore vs game rules

| # | Finding | Raised by | Status |
|---|---|---|---|
| R1 | 🟡 Lore quietly promised new systems (faction trading, faction tech, scripted act events, turned-away refugees returning) | Zoom Out, Critic | ✅ Factions are text events only. New section 14 "Lore vs rules" marks each idea as rule, flavour or proposed |
| R2 | 🟡 Lamp check at the gate did the clinic's job (caught hidden stage 1) | Comprehension, Critic | ✅ Lamp catches Fever only, in a dark shed. Only the clinic finds Warm |
| R3 | 🟡 Clinic used in Act 2, but it is a Rebuild (Act 3) building; workshop was in the wrong act | Comprehension, Critic | ✅ Events and acts moved to the right tiers |
| R4 | 🟡 Same places were both map zones and off-map expeditions; districts gave blueprints | Zoom Out, Critic | ✅ Districts give land only. Expeditions are off the map. Radio tower in town, parts from a Relay Station |
| R5 | 🟡 Ending added a 3-night hold and boat choice not in the GDD | Zoom Out | ✅ Kept, marked Proposed. Boat choice dropped (see O2) |
| R6 | 🟡 Scavengers checked at the pen is a new rule | Critic (round 2) | ✅ Marked Proposed |
| R7 | 🟡 Family split at the gate needs multi-person refugees (GDD open question) | Critic (round 2) | ✅ Example changed to one refugee |
| R8 | 🟢 First horde on night 1 breaks the tutorial pace | Critic | ✅ Roamers night 1, first horde night 3 |
| R9 | 🟢 Hordes as a fixed loop vs changing direction | Critic (round 2) | ✅ Noise and light pull herds in from any side |

### Story logic

| # | Finding | Raised by | Status |
|---|---|---|---|
| L1 | 🟡 Daylight is light, so why does it slow the dead? | Comprehension | ✅ Only light that stands out in the dark pulls them |
| L2 | 🟡 Radio waves make no sound, so the signal can't draw a horde | Comprehension, Critic | ✅ Tower needs generators and a beacon light each night |
| L3 | 🟡 Bite-only spread vs early fever cases and "quarantine stops spread" | Comprehension, Critic | ✅ Early bites blamed on dogs and fights. Spread inside = someone turns and bites |
| L4 | 🟡 Cough used as a sign but not a symptom | Comprehension, Critic | ✅ Cough removed |
| L5 | 🟡 Boats from the river mouth go up, not down | Style, Critic | ✅ Upriver |
| L6 | 🟡 Why not just walk to safety? Why a night beacon if boats arrive at dawn? | Critic (round 2) | ✅ Long walk past herds. Boats travel by night and steer by the beacon |
| L7 | 🟡 A "ford" is a shallow crossing, so the river isn't a full wall | Critic (round 2) | ✅ The ford is the town's one known weak spot |
| L8 | 🟢 Siren works with no power | Critic | ✅ Hand-crank siren |
| L9 | 🟢 Eyes "shine" but need a lamp | Critic (round 2) | ✅ Eyes reflect a lamp |
| L10 | 🟢 Infection event used a visible sign, so no real doubt | Critic (round 2) | ✅ Now a bandaged hand and a story about glass |

### Originality

| # | Finding | Raised by | Status |
|---|---|---|---|
| O1 | 🟡 Looping "safe zone, food and doctors, maybe a trap" broadcast is a well-known film and TV plot | Critic | ✅ Replaced by the Tally: a nightly list of names who reached safety. No trap twist |
| O2 | 🟡 Written law + people leaving + final siege + "was it worth it" choice is close to a known city builder | Critic (round 2) | ✅ Closing choice dropped. Ending names the survivors instead |
| O3 | 🟡 "Screamer" with a calling scream exists in several zombie games | Critic | ⚖️ Kept by the author: plain, common word |
| O4 | 🟢 "Kessel" brings a famous sci-fi film to mind | Critic | ✅ Town renamed Halder Ford |
| O5 | 🟢 "Lights Out" is a horror film title | Critic (round 2) | ✅ Removed from game name ideas (kept as an in-world event) |
| O6 | 🟢 Slow by day, fast at night is a known genre rule | Critic (round 2) | ⚖️ Kept: it is already a game rule (GDD section 4) and common in the genre |

### Readability and style

| # | Finding | Raised by | Status |
|---|---|---|---|
| S1 | 🟡 Example name "Lies" reads as an English word | Style | ✅ Changed to Noor. Rule added: no names that are English words |
| S2 | 🟡 Example choices broke the doc's own rules (too long, no cost) | Style | ✅ All choices under 8 words with a cost in brackets |
| S3 | 🟡 Two names for one thing (radio tower/mast, Command Post/fire station) | Comprehension, Style | ✅ One name each, in the glossary |
| S4 | 🟢 Act 1 "Embers" too close to "the Ember" | Style | ✅ Now "First Night" |
| S5 | 🟢 Story arc table too wide | Style | ✅ Tier column merged, cells shortened |
| S6 | 🟢 Jargon ("hook", "key beat") | Style | ✅ "Story idea", "Big moment" |
| S7 | 🟢 Design note inside lore text (siren) | All | ✅ Moved to section 15 |
| S8 | 🟢 Glossary missing terms | Style | ✅ Pen, Cold Room, radio tower, Relay Station, Tally added |
| S9 | 🟢 Mixed American and Dutch place names | Critic (round 2) | ✅ Route 9 and County removed |

### Missed chances (lore added for existing rules)

| # | Mechanic | Lore now |
|---|---|---|
| M1 | Horde every few nights, with a direction | Herds drift through the valley; Station 4's watch tower spots them at dusk |
| M2 | Clearing zones stops spawns | The dead nest in dark buildings |
| M3 | Quarantine building | The Cold Room |
| M4 | Auto-close gates at dusk | Gate Law rule 1 |
| M5 | Low morale, citizens leave | They slip out to follow the river |
| M6 | Kill zone | Lamplighter saying: "Give them a door you choose." |

## Other doc changes

- `GDD.md`: links to LORE.md; expedition list says "relay station" instead of "radio tower" (the tower is in town now).
- `CLAUDE.md`: points to LORE.md for story and names.

## Left for the author

- **Screamer's name** (O3): decided, keep "Screamer".
- **Game name:** decided: *Hold the Gates*.
- **Proposed items** in LORE.md section 14 (town events, 3-night ending, scavenger checks) need GDD entries before they are built.
