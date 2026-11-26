class_name PlotOverlay
extends Node3D
## Draws lot, footprint and entrance geometry from the plot the simulation uses.

const LAND := Color(0.77, 0.67, 0.43, 0.25)
const RESERVED_LAND := Color(0.55, 0.50, 0.36, 0.12)
const HOME := Color(0.78, 0.64, 0.41, 0.70)
const DOOR := Color(0.96, 0.75, 0.31, 0.82)
const BLOCKED := Color(0.8, 0.16, 0.12, 0.68)

var world: World
var _lots := Node3D.new()
var _parcels: Dictionary[int, Node3D] = {}
var _materials: Dictionary[Color, StandardMaterial3D] = {}
var _zones := Node3D.new()
var _preview := Node3D.new()
var _gravel: Material


func setup(owner_world: World) -> void:
	world = owner_world
	_gravel = load(StreetSurface.GRAVEL_PATH)
	add_child(_lots)
	add_child(_zones)
	add_child(_preview)
	world.plots.changed.connect(_draw_lots)
	world.grower.zones_changed.connect(_draw_zones)


func _clear(layer: Node3D) -> void:
	for child in layer.get_children():
		layer.remove_child(child)
		child.queue_free()


func _tint(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		_materials[color] = GroundShape.material(color)
	return _materials[color]


func _surface(
	layer: Node3D, shapes: Array[PackedVector2Array], material: Material, height: float
) -> void:
	if shapes.is_empty():
		return
	var mesh := MeshInstance3D.new()
	mesh.mesh = GroundShape.surface(shapes, world.map_def.view_scale)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position.y = height
	layer.add_child(mesh)


func _plot(layer: Node3D, plot: FrontagePlot, preview: bool) -> void:
	if plot.polygon.is_empty():
		return
	var height := 0.085 if preview else 0.025
	if preview:
		_surface(layer, [plot.polygon], _tint(LAND if plot.error.is_empty() else BLOCKED), height)
		_surface(layer, [plot.house], _tint(HOME), height + 0.02)
		_surface(layer, [plot.path_to_street], _tint(DOOR), height + 0.04)
	else:
		_surface(layer, [plot.polygon], _tint(RESERVED_LAND), height)
		_surface(layer, [plot.house, plot.path_to_street], _gravel, height + 0.02)


func show_plot(plot: FrontagePlot) -> void:
	clear_preview()
	_plot(_preview, plot, true)


func show_area(rect: Rect2i, blocked: bool = false) -> void:
	clear_preview()
	var p := Vector2(rect.position) * world.grid.tile_size
	var s := Vector2(rect.size) * world.grid.tile_size
	var poly := PackedVector2Array([p, p + Vector2.RIGHT * s.x, p + s, p + Vector2.DOWN * s.y])
	_surface(_preview, [poly], _tint(BLOCKED if blocked else LAND), 0.09)


func clear_preview() -> void:
	_clear(_preview)


func _draw_lots() -> void:
	for id: int in _parcels.keys():
		if not world.plots.plots.has(id):
			_lots.remove_child(_parcels[id])
			_parcels[id].queue_free()
			_parcels.erase(id)
	for plot: FrontagePlot in world.plots.plots.values():
		if _parcels.has(plot.id):
			continue
		var layer := Node3D.new()
		_lots.add_child(layer)
		_parcels[plot.id] = layer
		_plot(layer, plot, false)


func _draw_zones() -> void:
	_clear(_zones)
	var farms: Array[PackedVector2Array] = []
	var storage: Array[PackedVector2Array] = []
	for cell: Vector2i in world.grower.zones:
		var p := Vector2(cell) * world.grid.tile_size
		var shape := FrontagePlot.rectangle(
			p + Vector2.RIGHT * world.grid.tile_size * 0.5,
			Vector2.RIGHT,
			Vector2.DOWN,
			world.grid.tile_size,
			world.grid.tile_size
		)
		if world.grower.zones[cell].id == &"farm":
			farms.append(shape)
		else:
			storage.append(shape)
	_surface(_zones, farms, _tint(Color(0.4, 0.65, 0.28, 0.3)), 0.012)
	_surface(_zones, storage, _tint(Color(0.42, 0.54, 0.70, 0.3)), 0.012)
