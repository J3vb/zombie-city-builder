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
@export var camera_pan_speed: float = 1200.0
@export var camera_zoom_min: float = 0.25
@export var camera_zoom_max: float = 2.0
@export var camera_zoom_step: float = 0.1
@export var edge_scroll_margin: float = 12.0

@export_group("Buildings")
@export_range(0.0, 1.0) var demolish_refund: float = 0.5

@export_group("Debug")
@export var debug_spawn_count: int = 100

@export_group("Economy")
@export var start_resources: Dictionary[StringName, int] = {
	&"food": 50,
	&"water": 50,
	&"wood": 100,
	&"scrap": 40,
	&"fuel": 0,
	&"medicine": 5,
	&"ammo": 0,
}
