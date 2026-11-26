class_name StreetSurface
extends MeshInstance3D
## Lays a narrower asphalt surface over a gravel bed, including across junctions.

const PAVED_FRACTION := 0.86
const ARC_STEPS := 32
const ASPHALT_PATH := "res://assets/materials/basin_asphalt.tres"
const GRAVEL_PATH := "res://assets/materials/basin_gravel.tres"

var _paving := MeshInstance3D.new()


func _init() -> void:
	position.y = 0.035
	material_override = load(GRAVEL_PATH)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_paving.position.y = 0.025
	_paving.material_override = load(ASPHALT_PATH)
	_paving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_paving)


func draw_street(road: Street, scale_factor: float) -> void:
	var paving: Array[PackedVector2Array] = []
	for i in road.strips.size():
		var strip := road.strips[i]
		paving.append(
			PackedVector2Array(
				[
					road.line[i].lerp(strip[0], PAVED_FRACTION),
					road.line[i + 1].lerp(strip[1], PAVED_FRACTION),
					road.line[i + 1].lerp(strip[2], PAVED_FRACTION),
					road.line[i].lerp(strip[3], PAVED_FRACTION)
				]
			)
		)
	mesh = GroundShape.surface(road.strips, scale_factor)
	_paving.mesh = GroundShape.surface(paving, scale_factor)


func draw_junctions(network: RoadNetwork, scale_factor: float) -> void:
	var beds: Array[PackedVector2Array] = []
	var paving: Array[PackedVector2Array] = []
	for point: Vector2 in network.graph:
		if network.graph[point].size() < 2 and point != network.entrance:
			continue
		var bed := PackedVector2Array()
		var core := PackedVector2Array()
		for i in ARC_STEPS:
			var offset := Vector2.from_angle(TAU * i / ARC_STEPS) * network.width * 0.5
			bed.append(point + offset)
			core.append(point + offset * PAVED_FRACTION)
		beds.append(bed)
		paving.append(core)
	mesh = GroundShape.surface(beds, scale_factor) if not beds.is_empty() else null
	_paving.mesh = GroundShape.surface(paving, scale_factor) if not paving.is_empty() else null
