class_name BalanceDef
extends Resource
## All global gameplay numbers. Edit data/balance.tres, not code.

@export_group("Time")
@export var day_length_seconds: float = 360.0
@export_range(0.0, 1.0) var dusk_at: float = 0.65
@export_range(0.0, 1.0) var night_at: float = 0.7
@export var sim_ticks_per_second: int = 10
@export var max_catch_up_ticks: int = 10

@export_group("Zombies")
@export var max_zombies: int = 2000
@export var horde_base: int = 20
@export var horde_growth: int = 10
@export var spawns_per_frame: int = 50
@export var separation_radius: float = 12.0
@export var separation_strength: float = 60.0
@export var chase_radius_tiles: int = 4

@export_group("Camera")
@export var camera_pan_speed: float = 48.0
@export var camera_zoom_min: float = 12.0
@export var camera_zoom_max: float = 180.0
@export var camera_zoom_step: float = 1.15
@export var camera_start_distance: float = 60.0
@export var camera_start_pitch: float = 50.0
@export var camera_turn_speed: float = 1.6
@export var camera_drag_speed: float = 0.01
@export var camera_tilt_speed: float = 45.0
@export var edge_scroll_margin: float = 12.0

@export_group("Streets")
@export var road_width: float = 32.0
@export var road_min_length: float = 48.0
@export var road_snap_radius: float = 16.0

@export_group("Plots and growth")
@export var plot_frontage: float = 64.0
@export var plot_verge: float = 20.0
@export var plot_setback: float = 40.0
@export var plot_max_size: float = 256.0
@export var plot_pick_distance: float = 150.0
@export var growth_clearance_tiles: float = 3.0
@export var growth_hours: float = 1.0
@export var growth_per_day: int = 4
@export var upgrades_per_day: int = 2

@export_group("Buildings")
@export_range(0.0, 1.0) var demolish_refund: float = 0.5

@export_group("Debug")
@export var debug_spawn_count: int = 100

@export_group("Economy")
@export var ammo_batch_cost: Dictionary[StringName, int] = {&"scrap": 2}
@export var ammo_batch := 24
@export var station_capacity: int = 100
@export var start_resources: Dictionary[StringName, int] = {
	&"food": 50,
	&"water": 50,
	&"wood": 100,
	&"scrap": 40,
	&"fuel": 0,
	&"medicine": 5,
	&"ammo": 36,
}

@export_group("Residents")
@export var builder_name: String = "Ada"
@export var resident_limit: int = 100
@export var resident_speed: float = 40.0
@export var resident_health: int = 40
@export var resident_radius: float = 6.0
@export_range(0.0, 1.0) var shortage_pace_loss: float = 0.1
@export_range(0.01, 1.0) var minimum_work_pace: float = 0.5
@export var shift_seconds: float = 60.0
@export var resident_names := PackedStringArray(
	["Mara", "Elias", "Noor", "Bram", "Lena", "Raf", "Fien", "Ivo", "Nina", "Otis"]
)
@export var daily_ration: Dictionary[StringName, int] = {&"food": 1, &"water": 1}
