class_name CrowdMotion
extends RefCounted
## Local separation and passability for the shared flow-field crowd.

var _near := PackedInt32Array()


func separation(
	i: int, p: Vector2, radius: float, hash_grid: SpatialHash, positions: PackedVector2Array
) -> Vector2:
	var push := Vector2.ZERO
	var n := hash_grid.query(p, radius, _near)
	for k in n:
		var j := _near[k]
		if j == i:
			continue
		var away := p - positions[j]
		var d := away.length()
		if d > 0.001:
			push += away / d * (1.0 - d / radius)
		else:
			push += Vector2.RIGHT.rotated(i)
	return push


## Moves in steps of at most half a tile and never ends inside a blocked tile.
func move(p: Vector2, motion: Vector2, grid: Grid, def: ZombieDef) -> Vector2:
	var steps := maxi(1, ceili(motion.length() / (grid.tile_size * 0.5)))
	var step := motion / steps
	for s in steps:
		var next := p + step
		if _walkable(next, grid, def) and grid.can_cross_corner(p, next):
			p = next
		elif _walkable(Vector2(next.x, p.y), grid, def):
			p.x = next.x
		elif _walkable(Vector2(p.x, next.y), grid, def):
			p.y = next.y
		else:
			break
	return p


func _walkable(p: Vector2, grid: Grid, def: ZombieDef) -> bool:
	var cell := grid.world_to_cell(p)
	if grid.get_cost(cell) > 0:
		return true
	var barrier: BarrierSegment = grid.barriers.get(cell)
	return def.crawl_under and barrier != null and barrier.def == Perimeter.BARRICADE
