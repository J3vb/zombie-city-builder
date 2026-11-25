class_name ZombieDef
extends Resource
## One zombie type. Edit the .tres files in data/zombies/.

@export var id: StringName
@export var speed: float = 40.0
@export var health: int = 30
@export var building_damage: int = 5
@export var civilian_damage: int = 8
@export var attack_cooldown: float = 1.0
@export var radius: float = 10.0
@export var color: Color = Color(0.55, 0.7, 0.45)

@export_range(0.0, 1.0) var ember_chance := 0.12

@export var wall_multiplier := 1.0
@export var crawl_under := false
@export var ranged_resistance := 0.0
@export var scream_radius_tiles := 0.0
@export var scream_interval := 0.0
@export var height_scale := 1.0
@export var first_night := 1
@export var appearance_weight := 1
