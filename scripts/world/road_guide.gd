class_name RoadGuide
extends Node3D
## Shows the footprint, curve handles and measurements for the next click.

const VALID := Color(0.28, 0.82, 0.63, 0.65)
const INVALID := Color(0.95, 0.30, 0.21, 0.64)

var _ghost := MeshInstance3D.new()
var _lines := MeshInstance3D.new()
var _line_mesh := ImmediateMesh.new()
var _point := MeshInstance3D.new()
var _fill := GroundShape.material(VALID)
var _ink := GroundShape.material(Color("#e4d9ab"))
var _label := Label.new()


func setup(tile: float) -> void:
	for item: MeshInstance3D in [_ghost, _point, _lines]:
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(item)
	_ghost.position.y = 0.09
	_ghost.material_override = _fill
	_lines.mesh = _line_mesh
	_lines.position.y = 0.16
	var disc := CylinderMesh.new()
	disc.top_radius = tile * 0.21
	disc.bottom_radius = disc.top_radius
	disc.height = 0.05
	_point.mesh = disc
	_point.material_override = GroundShape.material(Color("#94e8c4"))
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(_label)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_constant_override("outline_size", 5)
	reset()


func reset() -> void:
	_ghost.mesh = null
	_point.hide()
	_line_mesh.clear_surfaces()
	_label.hide()


func draw(
	world: World,
	road: Street,
	handles: PackedVector2Array,
	target: Vector2,
	caption: String,
	screen: Vector2
) -> void:
	reset()
	if road != null and not road.strips.is_empty():
		_ghost.mesh = GroundShape.surface(road.strips, world.map_def.view_scale)
		_fill.albedo_color = VALID if road.error.is_empty() else INVALID
	if handles.size() >= 2:
		_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _ink)
		for p in handles:
			_line_mesh.surface_add_vertex(world.to_view(p))
		_line_mesh.surface_end()
	if target.is_finite():
		_point.position = world.to_view(target) + Vector3.UP * 0.18
		_point.show()
	if not caption.is_empty():
		_label.text = caption
		_label.reset_size()
		var limit := get_viewport().get_visible_rect().size - _label.size
		_label.position = (screen + Vector2(18, 17)).clamp(Vector2.ZERO, limit.max(Vector2.ZERO))
		_label.show()
