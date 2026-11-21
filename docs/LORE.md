# Lore and Story

The world, the story and the voice of the game.
Short sections. Read top to bottom once, then use it as a lookup.

Game rules live in [GDD.md](GDD.md) and [SYSTEMS.md](SYSTEMS.md). This doc only adds the "why" behind them.
Where lore and rules disagree, the rules win and this doc gets fixed.
Anything here that would need new code is listed in section 14, "Lore vs rules".

---

## 1. The story in five lines

1. A sickness called **the Ember** turned people into the dead. The dead are pulled towards light and noise.
2. The bright, loud cities fell first. People who went dark and quiet lived.
3. You lead a few survivors to an old fire station, **Station 4**, in the river town of **Halder Ford**.
4. You build walls, take in strangers and scavenge, while the nights get worse.
5. Each night a radio voice reads out the names of people who reached safety down the river. Fix the radio tower, call them, and get your town on that list.

## 2. Tone

- **Grim but warm.** The world is broken. The people in your town are not.
- **Small and human.** No world leaders, no secret labs, no chosen hero. A town and its people.
- **Quiet dread, not gore.** Fear comes from the dark, the sound outside the wall, the shaking hands at dinner.
- **Choices, not answers.** Text events give you a hard call. The game does not tell you which one was right.

## 3. The Ember (the sickness)

What everyone knows:

- It spreads by bite. Nobody has seen it spread any other way.
- "Spread inside the walls" means one sick person turns and bites others. That is why quarantine works.
- It starts as a fever. Shine a lamp at the eyes of the sick in the dark, and they reflect a dull orange, like the last glow of a fire. That is where the name comes from.
- The sick slowly lose sleep, then speech, then themselves.
- When it ends, the body gets up again. It feels no pain or cold. It only wants **light and sound**.

What nobody knows:

- Where it came from. Rumours say a mine, a ship, a lab. The game never says. Keep it that way.
- Whether there is a cure. Medicine slows it. Nothing has stopped it.

### The three stages

These match the infection stages in [SYSTEMS.md](SYSTEMS.md) section 11.

| Stage | Name | What you see | Game rule |
|---|---|---|---|
| 1 | **Warm** | Nothing. The person feels fine, or says so. | Hidden. Only a clinic with a medic can find it. |
| 2 | **Fever** | Sweating, shaking hands, no sleep. Eyes reflect orange under a lamp. | Visible. Works slower. |
| 3 | **Burn** | The person turns. | Dies and gets up as a zombie on the spot. |

People hide stage 1 because they are scared of being sent out. That is why the town needs a clinic, and why trust matters.

## 4. The dead

Survivors call them **the Drawn**, because they are drawn to light and noise like moths to a lamp.
Most people just say "the dead".

The lore behind the rules:

- **Slow by day, fast at night.** Only light that stands out in the dark pulls them. Daylight is everywhere, so it just dulls them. At night, every lamp is a target.
- **Light and noise pull them in.** Gunfire, hammering, generators and lamps all call them. Every useful thing you do has a cost.
- **They push where it is easiest.** They are not smart, but a crowd always finds the weak spot: an open gate, then a barricade, then a wall.
- **They come in herds.** The dead from the fallen cities drift through the valley. Every few nights a herd passes near the Ford, and the town's noise and light pull it in. It can come from any side. That is a horde night.
- **They nest in the dark.** By day, the dead gather inside dark buildings. Clear a district and board it up, and no more come out of it.

### The kinds of dead

The game names stay plain. The lore only explains them.

| Type | What survivors say |
|---|---|
| **Walker** | Most of the dead. Slow and steady. "One is easy. Fifty is a wall coming at you." |
| **Runner** | Turned while young and fit. Still fast. Finds every gap. |
| **Brute** | The Ember swells the body. Hits walls like a battering ram. |
| **Screamer** | The Ember burned its throat open. It shrieks, and every dead nearby turns to the sound. Kill it first. |
| **Crawler** | Legs gone. Low to the ground, slips under barricades. You hear it before you see it. |

## 5. How it happened

Years are not named on purpose, so the world feels near but not real.

| When | What happened |
|---|---|
| **Late autumn** | Fever cases in the cities. Bites were missed or blamed on dogs and fights. The news called it a bad flu season. |
| **First snow** | Hospitals fill up. The sick get up again. Cities lock down. |
| **The Bright Week** | Cities switch on every light and siren for the evacuation. The dead come from miles around. Most cities fall in days. |
| **Lights Out** | The power grid fails. Most radio goes quiet. Survivors learn one rule: **stay dark, stay quiet**. |
| **Winter** | Small groups hide in cellars, farms and churches. Many do not see spring. |
| **Spring** | Your group reaches Halder Ford and Station 4. Day 1 begins. |

The Bright Week is the key memory of this world. It is why people distrust lights, sirens and crowds. A town lit up at night feels like a dare.

## 6. Halder Ford (the map)

A small river town. Old stone centre, a rail line, a few mills, gardens at the edge.
Ideally a river runs along one side of the map. The dead cannot cross deep water, so it works as a natural wall.
The town is named after its one weak spot: the ford, a shallow crossing where the dead can wade across at low water.

### Districts

These are the **zones** from GDD section 13. Clearing one removes its spawns and opens new land to build on.
Rare loot (blueprints, radio parts) is never found here. It only comes from expeditions.

| District | Look and feel |
|---|---|
| **Old Town** | Where you start. Narrow streets, Station 4, the market square. |
| **Mill Quarter** | Old brick mills by the river. Dark, full of hiding places. |
| **Rail Yards** | Freight trains stuck where the power died. Many dead. |
| **Church Hill** | A church and graveyard on the high ground. Where the town fell first. |
| **Garden Row** | Small garden plots and sheds at the town edge. |

### Station 4 (the Command Post)

Station 4 is the old volunteer fire station in Old Town. In the game rules it is the **Command Post**: your main building. If it is destroyed, you lose.

- Thick brick walls, a big garage, a watch tower and a hand-crank siren on the roof.
- The watch tower is how the town sees a horde coming at dusk, and from which side.
- The siren still works. Nobody dares use it.

## 7. Your town and its rules

The player is never named or shown. You are **the Keeper**, the person the others trust to decide.

People living there just call the town "the Ford".

### The Gate Law

Every group that lived through winter has rules for strangers. In Act 2, the Ford writes its own and calls it the Gate Law. It is what the town believes, and it explains the checkpoint.

1. **Gates close at dusk.** Nobody comes in at night. (This is the "auto-close gates at dusk" setting.)
2. **Everyone waits in the pen.** The pen is a dark shed by the checkpoint.
3. **A guard checks them with a lamp.** A Fever eye reflects orange. A Warm person shows nothing. Only the clinic can catch Warm.
4. **The Keeper decides.** Let them in, send them to the Cold Room, or turn them away.
5. **The law is for everyone.** Your own scavengers come back through the pen too.

The **Cold Room** is the town's name for the quarantine building.

The game never says which choice is right. Turning people away is safe. It also means fewer hands.

### Why people leave

When morale drops, some people slip out at night to follow the river and look for safety on their own.

## 8. Places to scavenge

These are the expedition locations from GDD section 12. They are off the map, a walk away from town.
Each has a story idea for its text events.

| Location | Story idea |
|---|---|
| **Halbo Supermarket** | Already looted, but the stockroom door is locked from the inside. |
| **St. Agna Hospital** | Full of medicine and full of the dead. The worst and best trip. |
| **Police Post** | Ammo and weapons. The last officers locked themselves in the cells. Nobody knows why. |
| **Ringway Fuel Stop** | Fuel in tanks under the ground. Getting it out is slow and loud. |
| **Verbeek Farm** | A family still lives there. They ask for help with the dead in their barn. |
| **Relay Station** | A dead phone and radio relay on the ridge. Where radio parts are found. |

The **radio tower** itself stands in town. You repair it with parts found at the Relay Station and other places outside.

## 9. Other people

Two small groups appear only in text events. Neither is good or evil.
What they give you (blueprints, resources) comes through those events. There is no trade screen.

### The Lamplighters

- Believe the dead can be led. They light fires and ring bells far from towns to pull the dead away.
- Their saying: "Give them a door you choose." It is the idea behind a kill zone.
- In events, they may offer a blueprint for noise lures or fire trenches.
- Their lures sometimes lead a horde right past your walls.

### The Hushed

- Live in total dark and silence in cellars far from any town.
- Know the roads better than anyone. In events, they may share where good loot is.
- They hate lights and noise. A loud, bright town makes them stay away.

## 10. The Tally

The only radio voice left is a slow, calm one at the same hour every night. People call it **the Tally**.

It reads a list of names: towns and people who reached **Haven Point**, a camp at the river mouth. Then one line:

> "Haven Point is holding. Follow the river. Come in daylight. Come quiet."

Nobody in town has ever talked back to it. Nobody knows how many people Haven Point can take.
Why not just walk there? It is many days on foot through the valley, past the herds, with children and the sick. Most groups who tried are not on the Tally.

## 11. Story arc

The story follows the four tech tiers from GDD section 13. Each act starts when you reach that tier, not on a fixed day.
Acts set the mood and which text events can appear. They are not scripted missions.

| Act (tier) | Story | Big moment |
|---|---|---|
| **1. First Night** (Survive) | Your group reaches Station 4. Food, beds, first barricades. | Night 1: a few dead probe the barricade. Night 3: the first horde. |
| **2. The Wall** (Fortify) | Strangers come to the gate. The Gate Law is written. The workshop is built. | The first refugee waits in the pen. |
| **3. The Clinic** (Rebuild) | Power and the clinic. You can finally find the Warm. | The clinic finds a hidden case inside the walls. |
| **4. Reclaim** (Reclaim) | Clear districts. Repair the radio tower. | You call Haven Point. |

### The ending (campaign win)

When the radio tower works, you call Haven Point. They answer. Your town's name is read on the Tally for the first time.
They will send boats upriver. Boats travel at night, when the river is dark and quiet, and they reach you at dawn on the fourth day.

You must hold for three nights. The boats steer by your beacon, so the tower's generators and light must run every night. That noise and light brings the biggest hordes of the game.

If the town holds, the boats come. The closing text names every citizen who made it.

### Endless mode

The Tally keeps playing. When you call, nobody answers.
The story is just: how long can the Ford last?

## 12. Writing guide

Rules for anyone (or any Claude) writing text events, names or tooltips.

- **Short.** Text events under 60 words. Choices under 8 words each.
- **Plain words.** Made-up words only for names of people and places, plus the glossary.
- **Every choice shows its cost.** Put the cost in brackets after the choice.
- **Short, easy names.** Two syllables at most. Dutch, French and English-sounding names fit, for example Bram, Ines, Tobi, Noor, Remi, Jules, Mika, Saar.
- **No names that are also English words** (like "Lies" or "Will"). They are hard to read in a sentence.
- **No gore for its own sake.** Say what happened. Don't linger on it.
- **Never explain where the Ember came from.**
- **Original only.** No names, places or lines from other zombie games, films or books.

### Example text events

**The locked stockroom** (Halbo Supermarket)
> The stockroom door is locked from inside. You knock. Someone knocks back, three times, slow.
> - Break it open (noise draws the dead)
> - Leave it (someone may die in there)

**The bandaged hand** (inside the town, Act 3)
> Noor came back from the hospital trip with a bandaged hand. She says she cut it on glass. She is your best builder.
> - Clinic test (lose a builder for a day)
> - Trust her (risk the town)

**The medic at the gate** (checkpoint, Act 2)
> A man waits in the pen. He says he is a medic. The lamp shows nothing. He keeps his left sleeve down.
> - Let him in (risk infection)
> - Cold Room first (lower morale)
> - Turn him away (lose a medic)

## 13. Glossary

| Word | Meaning |
|---|---|
| **The Ember** | The sickness. Spread by bite. |
| **Warm / Fever / Burn** | The three stages of the Ember. |
| **The Drawn** | Survivor slang for the dead. |
| **The Bright Week** | When the cities lit up and fell. |
| **Lights Out** | When the power grid died. |
| **Halder Ford / the Ford** | The town and the map. |
| **Station 4** | The fire station. In game rules: the Command Post. |
| **The Keeper** | The player. |
| **The Gate Law** | The town's rules for strangers. |
| **The pen** | The dark shed where newcomers wait to be checked. |
| **The Cold Room** | The quarantine building. |
| **Radio tower** | The tower in town you repair to call for rescue. |
| **Relay Station** | The expedition place where radio parts are found. |
| **The Tally** | The nightly radio list of people who reached safety. |
| **Haven Point** | The camp at the river mouth. |
| **Lamplighters / Hushed** | The two other survivor groups. |

## 14. Lore vs rules

What in this doc is already a game rule, what is only flavour, and what would need new work.

| Idea | Status |
|---|---|
| Ember stages, bite, quarantine, clinic finds Warm | In the rules |
| Light and noise draw the dead, faster at night | In the rules |
| Horde every few nights, warning with direction | In the rules |
| Districts as zones, expeditions off the map | In the rules |
| Win: repair the radio tower and call for rescue | In the rules |
| Gate Law, Cold Room, pen, the Tally | Flavour (names and text only) |
| Lamplighters and Hushed | Flavour (text events only) |
| Acts follow tech tiers | Flavour (picks which events appear) |
| Text events inside the town, not only on expeditions | **Proposed.** SYSTEMS section 12 only has expedition events. |
| Final 3-night hold with beacon, boats on the fourth morning | **Proposed.** Needs a GDD entry for the win condition. |
| Gate Law rule 5: returning scavengers are checked in the pen | **Proposed.** SYSTEMS sections 6 and 12 don't check returning teams. |
| Closing text that names every surviving citizen | **Proposed.** Text only. |

## 15. Open for the author

- **Game name.** Ideas that fit: *Halder Ford*, *Keep the Ford*, *The Gate Law*.
- **The Screamer's name.** Other zombie games use "Screamer" for this exact type. Keep it, or rename it (for example *Caller*) in the GDD and here.
- **The siren.** Use the Station 4 siren as a one-time "pull the dead here" lure? It overlaps the noise lure trap in GDD section 10, so it may be the same feature.
- **GDD wording.** GDD section 5 calls the Command Post a "town hall". Change it to "Station 4 (Command Post)"?
