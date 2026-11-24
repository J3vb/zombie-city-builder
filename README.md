# Hold the Gates

A 3D city builder set in a zombie outbreak. Build a walled town, keep your survivors alive, scavenge the ruins, and hold the walls when the hordes come.

Made with **Godot 4.5** and **GDScript**.

## Status

The playable 3D prototype includes Station 4, instant building placement, night hordes and a city-builder camera. Draw curved streets from Station 4 and reserve homes on either side. Tents grow into shacks and brick houses. Farms grow from plots into fenced fields and greenhouses. Storage grows from tarp piles into sheds and warehouses. Click a building to check its health or see what its next upgrade needs. See [the roadmap](docs/ROADMAP.md).

## Docs

| File | What's in it |
|---|---|
| [docs/GDD.md](docs/GDD.md) | The game: rules, content, feel |
| [docs/DESIGN.md](docs/DESIGN.md) | Technical design and M0/M1 file plan |
| [docs/SYSTEMS.md](docs/SYSTEMS.md) | Every system, one section each |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Milestones M0 to M6 |
| [docs/reviews/](docs/reviews/) | Design review reports |

## Run it

1. Install [Godot 4.5](https://godotengine.org/download) (standard build, not .NET).
2. Open Godot, click **Import**, pick `project.godot` in this folder.
3. Press **F5**.

Controls:

| Key | Action |
|---|---|
| WASD / screen edge | Move the camera |
| Q / E or middle-mouse drag | Orbit |
| R / F | Tilt up / down |
| Mouse wheel | Zoom |
| Home plot, then left click beside a connected street | Reserve the shown house footprint and backyard |
| Left click a building with no tool active | Inspect its level, health, next upgrade and current blocker |
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

Open `scenes/tests/frontage_town.tscn` and press F6 in the Godot editor to try a prebuilt bend, T-junction and two occupied roadside plots. [See a shack awaiting its brick upgrade](docs/benchmarks/building-inspection.webp). [View the town with 500 Walkers](docs/benchmarks/frontage-town.webp).

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
