extends Node2D
## M0 placeholder: draws a test map and shows the clock.
## M1 replaces this with the World scene and HUD.

const MAP_PATH := "res://data/maps/starter_map.tres"
const GROUND_A := Color(0.22, 0.26, 0.2)
const GROUND_B := Color(0.25, 0.29, 0.22)

var _map: MapDef

@onready var _info: Label = $UI/Info
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_map = load(MAP_PATH) as MapDef
	var size_px := Vector2(_map.size * _map.tile_size)
	_camera.position = size_px / 2.0
	queue_redraw()


func _draw() -> void:
	var t: int = _map.tile_size
	for y in _map.size.y:
		for x in _map.size.x:
			var color := GROUND_A if (x + y) % 2 == 0 else GROUND_B
			draw_rect(Rect2(x * t, y * t, t, t), color)


func _process(_delta: float) -> void:
	var phase := "Night" if GameClock.is_night() else "Day"
	_info.text = (
		"Zombie City Builder (M0)   Day %d   %s   %d%%   Speed %dx"
		% [GameClock.day, phase, int(GameClock.time_of_day * 100.0), GameClock.speed]
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("speed_pause"):
		GameClock.set_speed(0 if GameClock.speed > 0 else 1)
	elif event.is_action_pressed("speed_1"):
		GameClock.set_speed(1)
	elif event.is_action_pressed("speed_2"):
		GameClock.set_speed(2)
	elif event.is_action_pressed("speed_3"):
		GameClock.set_speed(3)
