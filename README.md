# Zombie City Builder

A 2D top-down city builder set in a zombie outbreak. Build a walled town, keep your survivors alive, scavenge the ruins, and hold the walls when the hordes come.

Working title. Made with **Godot 4.5** and **GDScript**.

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

Keys: `Space` pause, `1` `2` `3` game speed.

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
docs/     design docs
```
