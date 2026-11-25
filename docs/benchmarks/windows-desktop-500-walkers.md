# Windows desktop benchmark with 500 Walkers

Measured on 24 November 2026 at commit `963821b8c3ddd4ebeef12659b0ebca95467d12f2`. The Windows desktop ran the 3D crowd scene at 607 FPS at night and the playable 2D town at 258 FPS. The full 128 × 128 flow-field rebuild took 16.91–17.40 ms across three runs, above the 8 ms budget tracked in [#11](https://github.com/J3vb/zombie-city-builder/issues/11).

## Machine and settings

- Ryzen 9 7950X3D and GeForce RTX 4080 SUPER, Windows x86_64.
- Godot 4.7.2 stable, running the project directly with the Compatibility renderer on ANGLE/D3D11. The project CI version is Godot 4.5.1.
- 1920 × 1080 render resolution, VSync disabled, uncapped frame rate, default camera pose.
- Each case had three seconds of warm-up followed by one 15-second sample. Average FPS is rendered frames divided by wall-clock time. Frame p95 is the 95th percentile of intervals between successive frame-post-draw signals. Walker update times come from the existing in-game timers and include submitting the instance buffer.

| Scene | Average FPS | Frame p95 | Walker update median | Walker update p95 |
| --- | ---: | ---: | ---: | ---: |
| 3D benchmark, day, sun shadows on | 637 | 1.78 ms | 0.212 ms | 0.224 ms |
| 3D benchmark, night, shadows on and 30 lights enabled | 607 | 1.86 ms | 0.213 ms | 0.226 ms |
| Playable 2D town, daytime, 500 active Walkers | 258 | 4.09 ms | 1.225 ms | 1.292 ms |

The 3D test uses the benchmark's scripted crowd movement. The playable town also runs horde movement, spatial queries and building interaction. These are distinct workloads. These readings predate the playable 3D port. The owner subsequently selected this Windows x64 desktop as the sole target.

## Repeating the checks

1. Import the project with `godot --headless --import`.
2. Start `godot --path . --resolution 1920x1080 --disable-vsync res://scenes/tests/bench_3d.tscn`. Select 500 with **1**. Use a fresh scene for each sample. Leave the camera still and press **N** once for the night case.
3. For the playable case launch `godot --path . --resolution 1920x1080 --disable-vsync`. Use a fresh town, leave the clock at 1×, and queue 500 Walkers. The measured run set the horde RNG seed to 1 and queued 500 in one call. For a manual spot check, use the debug spawn control five times and confirm 500 on the F3 overlay. Use the overlay for live readings or sample the timings above for a timed comparison.
4. Run `godot --headless --script res://tests/bench_flow_field.gd` three times. Each invocation reports the mean of ten rebuilds after one warm-up on a synthetic 128 × 128 cost grid. The three means here were 17.40, 16.95 and 16.91 ms.

The playable world already rebuilds a dirty flow field on a worker after startup. The rebuild result measures work duration. To assess its effect on play, capture frame times while placing buildings or changing a gate once gates are implemented.


## Playable 3D town

The first playable 3D port runs the ordinary main scene on the same Windows x64 desktop. The benchmark fixes the camera, places 500 Walkers in five rings around Station 4 and lets them use normal movement and routing. Each day or night run starts a fresh town. After a two-second warm-up, the script measures eight seconds of rendered frames.

| 1920 × 1080, uncapped, Godot 4.7.2 | Average FPS | 95th-percentile frame |
|---|---:|---:|
| Day | 603.6 | 1.73 ms |
| Night | 581.8 | 1.86 ms |

Run from an imported project on the reference PC with a display. The scene uses placeholder buildings and Walker meshes. Repeat after the art pass.

```sh
godot --path . --resolution 1920x1080 --disable-vsync --script res://tests/bench_playable_3d.gd
godot --path . --resolution 1920x1080 --disable-vsync --script res://tests/bench_playable_3d.gd -- night
```


## Street and housing playtest

The frontage test scene places two homes on opposite sides of a curved street with a T-junction. On the same desktop at 1920 × 1080 uncapped, both homes reached the brick stage before the crowd was introduced. A short rendered check with 500 active Walkers averaged 514 FPS during the day and 508 FPS at night. Frame p95 was 2.32 ms and 2.30 ms respectively. Each sample ran for two seconds after a 0.3-second warm-up. This snapshot used the prototype meshes.

[Daytime screenshot with 500 Walkers](frontage-town.webp)


## Civilian pursuit and shelter

On the reference Windows desktop (Ryzen 9 7950X3D, RTX 4080 Super), the staffed town averaged **153.8 FPS**, with a **7.05 ms** 95th-percentile frame in Godot 4.7.2 at 1920 × 1080 uncapped. The trial used 50 housed workers, the Station 4 builder and 500 active Walkers. After a two-second warm-up, it sampled six seconds of rendered frames. The benchmark’s Walkers use zero civilian damage to keep the population fixed. Pursuit, collision and flight run normally.

In a separate rendered encounter with normal damage, Noor left the well and reached home with 40/40 health. The inspector showed her departure and the HUD displayed the shelter alert. [Windows capture](civilian-shelter.webp).


## First defense

On the same Windows desktop at 1920 × 1080, the existing fixed-population crowd benchmark averaged **153.1 FPS** with a **7.18 ms** 95th-percentile frame. That benchmark measures 50 housed workers, a builder and 500 Walkers. A separate rendered check ordered ten perimeter tiles through the build menu, operated the finished gate in its inspector, posted Mara and observed one shot consume one round. [In-game capture](first-defense.webp).

The seed-4 opening replay uses ordinary paid construction, starting resources, reachable defender jobs and normal Walker damage. The undefended supply-first opening loses on the first night. The defended opening uses two watchtowers, three barricade tiles and two gate tiles. It packs ammo before dusk and uses its starting rations. CI runs the defended opening through dawn six.

| Night | Walkers | Ammo before attack | Ammo at dawn | Station 4 health |
|---|---:|---:|---:|---:|
| 1 | 30 | 36 | 6 | 500 |
| 2 | 40 | 54 | 14 | 500 |
| 3 | 50 | 62 | 12 | 500 |
| 4 | 60 | 60 | 0 | 500 |
| 5 | 70 | 72 | 2 | 500 |

## Gate changes with 500 active Walkers

On 25 November 2026 the 1080p night scene averaged 469 FPS while repeatedly opening and closing a completed gate. Walker update p95 was 1.65 ms, rendered frame p95 was 2.31 ms, and the slowest measured frame was 9.72 ms. Across 22 observed worker results the 95th-percentile delay from scheduling to adoption was 23.31 ms. The standalone full-grid build averaged 17.34 ms, above its original 8 ms target. The worker keeps the last complete field available during rebuilding. The scene sustained the 60 FPS target during these edits.

Run `godot --path . --resolution 1920x1080 --disable-vsync --script res://tests/bench_playable_3d.gd -- night rebuild` after import. The script requests a gate change every quarter second, samples eight seconds after warm-up, and fails if the crowd or worker rebuilds are missing. Use `tests/bench_flow_field.gd` for the separate full-grid CPU timing.
