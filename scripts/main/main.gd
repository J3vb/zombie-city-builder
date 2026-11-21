class_name Main
extends Node
## Owns the current World and the UI. Starts new games and handles game over.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var world: World

var _balance: BalanceDef = preload("res://data/balance.tres")

@onready var _hud: Hud = $Hud
@onready var _game_over: GameOverScreen = $GameOver


func _ready() -> void:
	EventBus.game_over.connect(_on_game_over)
	_game_over.new_game_pressed.connect(new_game)
	new_game()


func new_game() -> void:
	if world:
		remove_child(world)
		world.queue_free()
	_game_over.hide()
	GameClock.reset()
	Economy.reset(_balance.start_resources)
	world = WORLD_SCENE.instantiate() as World
	add_child(world)
	move_child(world, 0)
	_hud.bind(world.build_tool)


func _on_game_over(_day: int) -> void:
	GameClock.set_speed(0)
	_game_over.show_result(GameClock.day)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("speed_pause"):
		GameClock.set_speed(0 if GameClock.speed > 0 else 1)
	elif event.is_action_pressed("speed_1"):
		GameClock.set_speed(1)
	elif event.is_action_pressed("speed_2"):
		GameClock.set_speed(2)
	elif event.is_action_pressed("speed_3"):
		GameClock.set_speed(3)
