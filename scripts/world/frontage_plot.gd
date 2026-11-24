class_name FrontagePlot
extends RefCounted
## Geometry of one residential parcel, in simulation coordinates.

var id: int
var road_id: int
var attachment: Vector2
var front: Vector2
var center: Vector2
var door: Vector2i
var polygon := PackedVector2Array()
var house := PackedVector2Array()
var path_to_street := PackedVector2Array()
var yard := PackedVector2Array()
var cells: Array[Vector2i] = []
var house_cells: Array[Vector2i] = []
var home: Building
var error := ""


static func rectangle(
	start: Vector2, side: Vector2, back: Vector2, width: float, depth: float
) -> PackedVector2Array:
	var a := start - side * width * 0.5
	var b := start + side * width * 0.5
	return PackedVector2Array([a, b, b + back * depth, a + back * depth])
