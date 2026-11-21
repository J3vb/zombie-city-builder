# Hold the Gates

A 2D top-down city builder set in a zombie outbreak. Build a walled town, keep your survivors alive, scavenge the ruins, and hold the walls when the hordes come.

Made with **Godot 4.5** and **GDScript**.

## Status

M0 (project setup). See [docs/ROADMAP.md](docs/ROADMAP.md).

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
| Mouse wheel | Zoom |
| Build bar button, then left click | Place a building |
| Right click / Esc | Cancel building |
| Space | Pause |
| 1 / 2 / 3 | Game speed |
| F3 | Debug overlay (FPS, zombie count, flow arrows) |
| F5 | Spawn 100 zombies (debug) |
| F6 | +100 of every resource (debug) |
| F7 | Skip to night (debug) |

A horde comes every night. In M1 you can't fight back yet (towers come in M3), so the game is about where you build before the Command Post falls.

## Build a Windows .exe

Needs the Godot 4.5.1 export templates (Editor > Manage Export Templates > Download).

```sh
godot --headless --export-release "Windows Desktop" build/windows/HoldTheGates.exe
```

For ARM laptops (Snapdragon), use the "Windows ARM64" preset instead.

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
