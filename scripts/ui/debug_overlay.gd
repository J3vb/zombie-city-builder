class_name DebugOverlay
extends Node2D
## F3: stats and flow-field arrows. F5/F6/F7 cheats in debug builds.

const ARROW := Color(1, 1, 1, 0.35)

var world: World

var _balance: BalanceDef = preload("res://data/balance.tres")

@onready var _layer: CanvasLayer = $Layer
@onready var _label: Label = $Layer/Stats


func _ready() -> void:
	_set_visible(false)


func _set_visible(on: bool) -> void:
	visible = on
	_layer.visible = on


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		_set_visible(not visible)
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("debug_spawn"):
		world.horde.queue_spawn(_balance.debug_spawn_count)
	elif event.is_action_pressed("debug_resources"):
		for id: StringName in _balance.start_resources:
			Economy.add(id, 100)
	elif event.is_action_pressed("debug_skip_night"):
		GameClock.skip_to_night()


func _process(_delta: float) -> void:
	if not visible:
		return
	_label.text = (
		"FPS %d\nZombies %d\nFlow field build %.1f ms%s\nZombie update %.2f ms"
		% [
			Engine.get_frames_per_second(),
			world.zombies.count(),
			world.last_build_ms,
			" (rebuilding)" if world.is_rebuilding() else "",
			world.zombies.last_update_ms,
		]
	)
	queue_redraw()


func _draw() -> void:
	var cam := world.camera
	var view := get_viewport_rect().size / cam.zoom
	var rect := Rect2(cam.get_screen_center_position() - view / 2.0, view)
	var tile := world.tile_size()
	var x0 := maxi(0, floori(rect.position.x / tile.x))
	var y0 := maxi(0, floori(rect.position.y / tile.y))
	var x1 := mini(world.grid.size.x - 1, ceili(rect.end.x / tile.x))
	var y1 := mini(world.grid.size.y - 1, ceili(rect.end.y / tile.y))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dir := world.flow_field.direction_at(Vector2i(x, y))
			if dir == Vector2.ZERO:
				continue
			var centre := (Vector2(x, y) + Vector2(0.5, 0.5)) * tile
			var tip := centre + dir * tile.x * 0.35
			draw_line(centre - dir * tile.x * 0.2, tip, ARROW, 2.0)
			draw_line(tip, tip - dir.rotated(0.5) * 6.0, ARROW, 2.0)
			draw_line(tip, tip - dir.rotated(-0.5) * 6.0, ARROW, 2.0)
