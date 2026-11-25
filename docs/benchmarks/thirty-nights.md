# Thirty nights at Station 4

Run the same settlement on Halder Ford from the repository root with a Godot 4.5.1 editor.

```sh
godot --headless --path . --script res://tests/play_opening.gd -- month
```

The replay starts with the normal supplies and a fixed horde seed of 4. It uses the same paid orders and resident assignments as the player. It builds a road, reserves housing, orders a gate, places workplaces on their own sites and moves workers from day shifts to staffed towers. From the second week it orders rifle towers, buys workshop upgrades and develops farms and housing. Residents make three trips to Halbo Supermarket, Verbeek Farm and the Police Post.

| Point in the run | Observed result on Windows |
| --- | --- |
| Initial balance trial | The settlement fell on night 18 after running short of ammunition against 212 Drawn. |
| Dawn 16 | Seven residents. Saved to disk, restored into a new world and continued. |
| Night 24 | Ten residents. Saved and restored during the attack with 50 Drawn on the map. |
| Night 30 | 238 Drawn approached from the west. |
| Dawn 31 | Ten residents, 10 food, 62 water, 16 rounds and 100 scrap. Station 4 retained 500 of 500 HP. |

Ten major hordes arrived over thirty nights. Four watchtowers and two rifle towers fired 2,248 shots. Food stocks reached zero in the middle of the month and recovered in the last two days. Save/resume preserved the active population, active crowd and horde random state at both checkpoints.

CI runs the ten-night defense, fifteen-night expedition and thirty-night save/resume scenarios separately. The month scenario fails on a lost town, missed checkpoints or waves, unresolved attackers, or depleted food or water at the finish. A first-time player's assessment of the tutorial and long-run pacing remains open.

[View the saved town at dawn 16](month-settlement.webp).
