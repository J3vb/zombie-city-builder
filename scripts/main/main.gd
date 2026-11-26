class_name Main
extends Node
## Owns the current World and the UI. Starts new games and handles game over.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var guided := false
var selected_map: MapDef
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
	world.map_def = selected_map
	add_child(world)
	_place_starter_defenses()
	move_child(world, 0)
	AudioManager.bind(world)
	_hud.bind(world.build_tool, guided)
	_hud.show()


func _place_starter_defenses() -> void:
	var origin := world.command_post.cell
	var yard := world.map_def.starter_yard
	var left := origin + yard.position
	var right := Vector2i(origin.x + yard.end.x - 1, left.y)
	var side := Vector2i.DOWN * (yard.size.y - 1)
	var perimeter := world.perimeter
	perimeter.spawn_line(Perimeter.BARRICADE, left, right)
	perimeter.spawn_line(Perimeter.BARRICADE, left + Vector2i.DOWN, left + side)
	perimeter.spawn_line(Perimeter.BARRICADE, right + Vector2i.DOWN, right + side)
	var tower := world.spawn_building(
		load("res://data/buildings/watchtower.tres") as TowerDef,
		origin + world.map_def.starter_tower
	)
	if tower == null or not world.jobs.assign(world.jobs.arrive(world.command_post), tower):
		push_error(
			"Could not staff Station 4's starter watchtower on " + world.map_def.display_name
		)


func restore_game(data: Dictionary) -> bool:
	if not SaveLayout.MAPS.has(data.get("map")) or not data.get("guide") is Dictionary:
		return false
	var candidate := WORLD_SCENE.instantiate() as World
	var previous_camera := get_viewport().get_camera_3d()
	var previous_capacity := Economy.capacity
	candidate.map_def = SaveLayout.MAPS[data.map]
	candidate.restoring = true
	add_child(candidate)
	var loader := RestoreTown.new()
	if not loader.restore(candidate, data):
		remove_child(candidate)
		candidate.free()
		Economy.set_capacity(previous_capacity)
		if is_instance_valid(previous_camera):
			previous_camera.make_current()
		return false
	remove_child(world)
	world.free()
	world = candidate
	move_child(world, 0)
	selected_map = world.map_def
	for key: String in loader.clock_values:
		GameClock.set(key, loader.clock_values[key])
	Economy.reset(loader.stocks)
	world._refresh_storage()
	world.camera.lens.make_current()
	_game_over.hide()
	_hud.bind(world.build_tool, guided)
	var guide := _hud.get_node("OpeningGuide") as OpeningGuide
	guide.step = clampi(int(data.guide.get("step", 0)), 0, OpeningGuide.STEPS.size() - 1)
	guide.dismissed = bool(data.guide.get("hidden", false))
	guide.visible = guided and not guide.dismissed
	guide._refresh()
	_hud.show()
	AudioManager.bind(world)
	return true


func _on_game_over(day: int) -> void:
	if GameClock.ended:
		return
	GameClock.stop()
	world.plot_tool.clear()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.hide()
	_game_over.show_result(day, world.safety.people.is_empty())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("speed_pause"):
		GameClock.set_speed(0 if GameClock.speed > 0 else 1)
	elif event.is_action_pressed("speed_1"):
		GameClock.set_speed(1)
	elif event.is_action_pressed("speed_2"):
		GameClock.set_speed(2)
	elif event.is_action_pressed("speed_3"):
		GameClock.set_speed(3)
