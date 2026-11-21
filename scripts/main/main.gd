class_name Main
extends Node
## Owns the current World and the UI. Starts new games.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var world: World

var _balance: BalanceDef = preload("res://data/balance.tres")

@onready var _info: Label = $UI/Info


func _ready() -> void:
	new_game()


func new_game() -> void:
	if world:
		world.queue_free()
		remove_child(world)
	GameClock.reset()
	Economy.reset(_balance.start_resources)
	world = WORLD_SCENE.instantiate() as World
	add_child(world)
	move_child(world, 0)


func _process(_delta: float) -> void:
	var phase := "Night" if GameClock.is_night() else "Day"
	_info.text = (
		"Day %d   %s   %d%%   Speed %dx"
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
