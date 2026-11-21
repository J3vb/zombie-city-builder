class_name FlowField
extends RefCounted
## Shared path map for all zombies. Every tile points one step closer to a goal.
## Dijkstra with a bucket queue (Dial's algorithm): costs are small integers.

const UNREACHED := 2147483647
const NONE := 255
const BLOCKED := -1
const STRAIGHT := 10
const DIAGONAL := 14
## Direction index -> offset: N, NE, E, SE, S, SW, W, NW.
const OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
]

var size: Vector2i
var integration: PackedInt32Array
var direction: PackedByteArray

var _unit_dirs: Array[Vector2] = []


func _init() -> void:
	for offset in OFFSETS:
		_unit_dirs.append(Vector2(offset).normalized())


func build(cost: PackedInt32Array, grid_size: Vector2i, goals: PackedInt32Array) -> void:
	size = grid_size
	var count := size.x * size.y
	integration.resize(count)
	integration.fill(UNREACHED)
	direction.resize(count)
	direction.fill(NONE)
	if goals.is_empty():
		return
	_integrate(cost, goals)


func direction_at(cell: Vector2i) -> Vector2:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return Vector2.ZERO
	var d := direction[cell.y * size.x + cell.x]
	return Vector2.ZERO if d == NONE else _unit_dirs[d]


## Each tile records the direction back to the tile that gave it its best value,
## so no second pass is needed.
func _integrate(cost: PackedInt32Array, goals: PackedInt32Array) -> void:
	var w := size.x
	var h := size.y
	var max_step := 1
	for c in cost:
		if c > max_step:
			max_step = c
	var bucket_count := max_step * DIAGONAL + 1
	var buckets: Array[PackedInt32Array] = []
	buckets.resize(bucket_count)
	for i in bucket_count:
		buckets[i] = PackedInt32Array()
	for g in goals:
		integration[g] = 0
		buckets[0].append(g)
	var deltas := PackedInt32Array([-w, -w + 1, 1, w + 1, w, w - 1, -1, -w - 1])
	var step_mult := PackedInt32Array([10, 14, 10, 14, 10, 14, 10, 14])
	# Neighbour indices for the two sides of each diagonal step.
	var side_a := PackedInt32Array([0, -w, 0, w, 0, w, 0, -w])
	var side_b := PackedInt32Array([0, 1, 0, 1, 0, -1, 0, -1])

	var current := 0
	var pending := goals.size()
	while pending > 0:
		var slot := current % bucket_count
		var bucket: PackedInt32Array = buckets[slot]
		if bucket.is_empty():
			current += 1
			continue
		buckets[slot] = PackedInt32Array()
		pending -= bucket.size()
		for i in bucket:
			if integration[i] != current:
				continue
			var x := i % w
			var y := i / w
			var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1
			for d in 8:
				if edge and not _in_bounds(x + OFFSETS[d].x, y + OFFSETS[d].y):
					continue
				var n := i + deltas[d]
				var step_cost := cost[n]
				if step_cost <= 0:
					continue
				if d & 1 and (cost[i + side_a[d]] <= 0 or cost[i + side_b[d]] <= 0):
					continue
				var nd := current + step_cost * step_mult[d]
				if nd < integration[n]:
					integration[n] = nd
					direction[n] = (d + 4) & 7
					buckets[nd % bucket_count].append(n)
					pending += 1
		current += 1


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size.x and y < size.y
