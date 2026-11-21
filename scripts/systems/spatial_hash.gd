class_name SpatialHash
extends RefCounted
## Buckets points by position for fast "who is near here" queries.
## Rebuilt every frame with a counting sort into flat, reused arrays.

var bucket_size: float = 64.0
var columns: int = 1
var rows: int = 1
var cell_start: PackedInt32Array
var items: PackedInt32Array

var _positions: PackedVector2Array
var _cell_of: PackedInt32Array


func setup(world_size: Vector2, new_bucket_size: float) -> void:
	bucket_size = new_bucket_size
	columns = maxi(1, ceili(world_size.x / bucket_size))
	rows = maxi(1, ceili(world_size.y / bucket_size))
	cell_start.resize(columns * rows + 1)


func rebuild(positions: PackedVector2Array, count: int) -> void:
	_positions = positions
	cell_start.fill(0)
	_cell_of.resize(count)
	items.resize(count)
	for i in count:
		var c := _bucket(positions[i])
		_cell_of[i] = c
		cell_start[c + 1] += 1
	for c in columns * rows:
		cell_start[c + 1] += cell_start[c]
	var fill := cell_start.duplicate()
	for i in count:
		var c := _cell_of[i]
		items[fill[c]] = i
		fill[c] += 1


func query(pos: Vector2, radius: float, out: PackedInt32Array) -> int:
	var found := 0
	var r2 := radius * radius
	var x0 := clampi(floori((pos.x - radius) / bucket_size), 0, columns - 1)
	var x1 := clampi(floori((pos.x + radius) / bucket_size), 0, columns - 1)
	var y0 := clampi(floori((pos.y - radius) / bucket_size), 0, rows - 1)
	var y1 := clampi(floori((pos.y + radius) / bucket_size), 0, rows - 1)
	for by in range(y0, y1 + 1):
		for bx in range(x0, x1 + 1):
			var c := by * columns + bx
			for k in range(cell_start[c], cell_start[c + 1]):
				var i := items[k]
				if _positions[i].distance_squared_to(pos) <= r2:
					if found >= out.size():
						out.resize(maxi(16, out.size() * 2))
					out[found] = i
					found += 1
	return found


func _bucket(p: Vector2) -> int:
	var bx := clampi(floori(p.x / bucket_size), 0, columns - 1)
	var by := clampi(floori(p.y / bucket_size), 0, rows - 1)
	return by * columns + bx
