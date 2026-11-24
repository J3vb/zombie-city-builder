class_name BuildTool
extends Node3D
## Projects the cursor to the grid and submits the previewed footprint to World.

const VALID := Color(0.35, 0.9, 0.45, 0.55)
const INVALID := Color(0.95, 0.26, 0.20, 0.65)
const NO_CELL := Vector2i(-1, -1)

var selected: BuildingDef
var world: World

var _ghost := MeshInstance3D.new()
var _box := BoxMesh.new()
var _material := StandardMaterial3D.new()
var _cross := Label3D.new()


func _ready() -> void:
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box.material = _material
	_ghost.mesh = _box
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)
	_cross.text = "×"
	_cross.font_size = 96
	_cross.pixel_size = 0.035
	_cross.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cross.no_depth_test = true
	_cross.position.y = 1.3
	_ghost.add_child(_cross)
	_ghost.hide()


func select(def: BuildingDef) -> void:
	world.road_tool.clear()
	selected = def
	var size := Vector2(def.size) * world.view_tile()
	_box.size = Vector3(size.x, 0.4, size.y)


func clear() -> void:
	selected = null
	_ghost.hide()


func can_place(def: BuildingDef, cell: Vector2i) -> bool:
	return world.can_place_building(def, cell)


func place(cell: Vector2i) -> bool:
	return selected != null and world.try_place_building(selected, cell) != null


func cell_at_screen(screen: Vector2) -> Vector2i:
	if not get_viewport().get_visible_rect().has_point(screen):
		return NO_CELL
	var hit: Variant = world.camera.ground_at(screen)
	if hit == null:
		return NO_CELL
	var cell := world.grid.world_to_cell(world.to_sim(hit))
	return cell if world.grid.in_bounds(cell) else NO_CELL


func _process(_delta: float) -> void:
	if selected == null:
		return
	var cell := cell_at_screen(get_viewport().get_mouse_position())
	_ghost.visible = cell != NO_CELL
	if not _ghost.visible:
		return
	var center := (Vector2(cell) + Vector2(selected.size) * 0.5) * world.grid.tile_size
	_ghost.position = world.to_view(center) + Vector3.UP * 0.24
	var valid := can_place(selected, cell)
	_material.albedo_color = VALID if valid else INVALID
	_cross.visible = not valid


func _unhandled_input(event: InputEvent) -> void:
	if selected == null:
		return
	if event.is_action_pressed("place") and event is InputEventMouseButton:
		var cell := cell_at_screen(event.position)
		if cell != NO_CELL:
			place(cell)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		clear()
		get_viewport().set_input_as_handled()
