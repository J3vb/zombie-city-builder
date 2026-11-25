# Hold the Gates

A 3D city builder set in a zombie outbreak. Build a walled town, keep your survivors alive, scavenge the ruins, and hold the walls when the hordes come.

Made with **Godot 4.5** and **GDScript**.

## Status

The playable 3D prototype includes Station 4, timed construction, night hordes and a city-builder camera. Draw curved streets from Station 4 and reserve homes on either side. Tents grow into shacks and brick houses. Place small gardens and scrap workshops on individual sites. Farms grow from plots into fenced fields and greenhouses. Storage grows from tarp piles into sheds and warehouses. Click a building to check its health or see what its next upgrade needs. See [the roadmap](docs/ROADMAP.md).

### Construction

Station 4 starts with Ada, the town builder. Order a building or mark land for growth. The order pays once and reserves its footprint. Ada walks to the first reachable site and works there during daylight. Inspect the frame to see progress, route status and the unused materials returned if you cancel. At dusk Ada heads home and resumes the next day. A home grants its bed and a workplace opens for hiring on completion. Existing buildings continue serving their current level during upgrades. [See construction in game](docs/benchmarks/construction.webp).

### Residents and shifts

Grow a home on a connected street and place a garden or scrap workshop nearby. One named resident moves into each completed home. Inspect the site to see who works there and how far their shift has progressed. **Manage worker** lets you reassign a resident or pause hiring. A completed garden shift earns 4 food. A workshop shift earns 4 scrap. Farms earn 6, 9 or 12 food as they upgrade.

A well earns 12 water per shift and a lumber yard earns 16 wood. Goods arrive at dawn, then everyone, including Ada, uses one food and one water. The dawn report lists goods stored, rations used, shortages and deliveries that could not fit. Missed rations slow work until the resident receives both again. [See a garden shift](docs/benchmarks/resident-shift.webp).

Station 4 holds 100 of each resource. A finished tarp pile, shed or warehouse adds 40, 80 or 140 spaces respectively. Reserve enough starting wood for a home, a well and a lumber yard if you want to keep expanding.

To try the five-day supply town, open `scenes/tests/supply_town.tscn` in Godot and press **F6**. Ten residents share two fields, a well, a lumber yard and a scrap workshop. Hordes are disabled and automatic growth starts paused so you can observe the accounts. Let the town reach dawn on day 6, pause hiring at the well, and reopen it after the water runs out. [See the day-six town](docs/benchmarks/supply-town.webp).

### Civilian safety

When a Walker comes within four tiles, the worker leaves their post and an amber **!** appears above them. Inspect their home or workplace to see where they are going and how much health they have. Residents can shelter at home or Station 4. If their shelter falls, they are exposed again. Losing the builder passes construction to a survivor. Losing the last resident ends the game. [See Noor escaping from the well](docs/benchmarks/civilian-shelter.webp).

### Defending Station 4

Open **Defenses** and drag a barricade or palisade along a row or column. The preview shows the full price and flags blocked tiles. Use gates where your line crosses the street. Ada builds each paid segment. Click a finished gate with the build tool cleared to open or close it, or change its **Close at dusk** setting. A gate waits for anyone crossing to clear the tile.

Place a **Watchtower** within range of the buildings you want to protect. Its placement ring shows the 16-tile reach. Use **Manage worker** to post a resident. They walk to the tower and stand watch through the night. Each shot uses one ammo. Station 4 starts with 36 ammo. Click Station 4 to pack another 24 for 2 scrap. [See the gate and staffed tower in game](docs/benchmarks/first-defense.webp).

The fresh-start replay reached dawn six with three people and Station 4 at 500/500 health. Two defenders used 250 rounds across five nights, leaving 2 ammo, 35 food and 35 water. This opening uses starting rations and prioritizes defense construction. The separate ten-person supply town tests food and water production.

Run `godot --headless --path . --script res://tests/play_opening.gd` to replay the defended opening. Append `-- undefended` to run the original supply-first strategy with the same seed. It loses on night one. The replay returns 0 on survival through dawn six and 1 on defeat.

## Docs

| File | What's in it |
|---|---|
| [docs/GDD.md](docs/GDD.md) | The game: rules, content, feel |
| [docs/DESIGN.md](docs/DESIGN.md) | Technical design and M0/M1 file plan |
| [docs/SYSTEMS.md](docs/SYSTEMS.md) | Every system, one section each |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Milestones M0 to M6 |
| [docs/reviews/](docs/reviews/) | Design review reports |

## Windows download

Open a completed CI run under **Actions** on GitHub. Download the **HoldTheGates-Windows-x64** artifact for that commit, extract the archive and run **HoldTheGates.exe**. GitHub requires a signed-in account to download workflow artifacts. Each build starts the packaged application and settlement on Windows before it is offered for download.

To reproduce the package on Windows with Python 3.12, run `python tools/windows_toolchain.py ../htg-tools`, then `./tools/package_windows.ps1 -ToolCache ../htg-tools -Render` from PowerShell. The script uses Godot 4.5.1 and writes the game under `build/windows/local/`.

## Run it

1. Install [Godot 4.5](https://godotengine.org/download) (standard build, not .NET).
2. Open Godot, click **Import**, pick `project.godot` in this folder.
3. Press **F5**, choose **Halder Ford** or **Mill Crossing**, then **Start settlement**. Open **Menu** to pause. **Settings** includes interface size, OpenDyslexic, audio and key bindings.

Controls:

| Key | Action |
|---|---|
| WASD / screen edge | Move the camera |
| Q / E or middle-mouse drag | Orbit |
| R / F | Tilt up / down |
| Mouse wheel | Zoom |
| Home plot, then left click beside a connected street | Reserve the house and its street entrance |
| Left click a building with no tool active | Inspect its level, health, next upgrade and current blocker |
| Garden / Well / Scrap workshop / Lumber yard, then left click | Order a one-tile garden or well, or a 2 × 2 workshop or yard, on clear land. Click again to place another. |
| Farm zone / Storage zone, then drag | Paint land for automatic construction |
| Land tools | Demolish a building, release an empty plot, remove a street or erase zoning |
| Pause growth / Resume growth | Control automatic building and upgrades |
| Street, then left clicks | Set street points, starting at the gold Station 4 marker or open ground |
| Enter / Backspace | Finish a street / undo its last point |
| Right click / Esc | Cancel construction |
| Space | Pause |
| 1 / 2 / 3 | Game speed |
| F3 | Debug overlay (FPS, zombie count, flow arrows) |
| F5 | Spawn 100 zombies (debug) |
| F6 | +100 of every resource (debug) |
| F7 | Skip to night (debug) |

Open `scenes/tests/frontage_town.tscn` and press F6 in the Godot editor to try a prebuilt bend, T-junction and two occupied roadside plots. [See a shack awaiting its brick upgrade](docs/benchmarks/building-inspection.webp). [See gardens, a farm and a workshop on separate sites](docs/benchmarks/independent-sites.webp). [View the town with 500 Walkers](docs/benchmarks/frontage-town.webp).

A horde comes every night. In M1 you can't fight back yet (towers come in M3), so the game is about where you build before the Command Post falls.

## Build a Windows .exe

Needs the Godot 4.5.1 export templates (Editor > Manage Export Templates > Download).

```sh
godot --headless --export-release "Windows Desktop" build/windows/HoldTheGates.exe
```

The reference PC is a Windows x64 desktop with a Ryzen 9 7950X3D and RTX 4080 Super. The playable target is 60 FPS with 500 Walkers at 1080p.

The game files are packed inside the .exe, so you only share that one file.

## Tests and lint

```sh
# Unit tests (headless)
godot --headless --script res://tests/run_tests.gd

# Lint and format (needs Python)
pip install "gdtoolkit==4.*"
gdlint scripts tests
gdformat --check scripts tests   # drop --check to fix
```

CI runs all of these on every push and pull request.

## Folders

```text
scenes/   .tscn scenes
scripts/  .gd scripts (autoload, world, buildings, units, systems, ui)
data/     .tres balance data, edit in the Godot inspector
assets/   sprites, tiles, audio, fonts
tests/    headless tests (tests/test_*.gd)
tools/    helper scripts (terrain generator, screenshots)
docs/     design docs
```
