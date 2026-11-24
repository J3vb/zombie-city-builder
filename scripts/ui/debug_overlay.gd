class_name DebugOverlay
extends Node3D
## F3: stats and flow-field arrows. F5/F6/F7 cheats in debug builds.

const ARROW := Color(1, 1, 1, 0.35)

var world: World
var _field: FlowField
var _center := Vector2i(-1, -1)
var _arrows := MeshInstance3D.new()
var _lines := ImmediateMesh.new()
var _line_material := StandardMaterial3D.new()

var _balance: BalanceDef = preload("res://data/balance.tres")

@onready var _layer: CanvasLayer = $Layer
@onready var _label: Label = $Layer/Stats


func _ready() -> void:
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = ARROW
	_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arrows.mesh = _lines
	_arrows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arrows)
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
	var center := world.grid.world_to_cell(world.to_sim(world.camera.position))
	if center != _center or world.flow_field != _field:
		_center = center
		_field = world.flow_field
		_draw_field()


func _draw_field() -> void:
	_lines.clear_surfaces()
	var area := Rect2i(_center - Vector2i(20, 20), Vector2i(41, 41))
	area = area.intersection(Rect2i(Vector2i.ZERO, world.grid.size))
	var started := false
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			var dir := _field.direction_at(cell)
			if dir == Vector2.ZERO:
				continue
			if not started:
				_lines.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)
				started = true
			var origin := world.to_view(world.grid.cell_to_world(cell)) + Vector3.UP * 0.09
			var step := world.to_view(dir * world.grid.tile_size)
			var tip := origin + step * 0.35
			_lines.surface_add_vertex(origin - step * 0.2)
			_lines.surface_add_vertex(tip)
			_lines.surface_add_vertex(tip)
			_lines.surface_add_vertex(tip - step.rotated(Vector3.UP, 0.5) * 0.2)
	if started:
		_lines.surface_end()
