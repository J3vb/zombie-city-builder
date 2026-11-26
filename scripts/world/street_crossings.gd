class_name StreetCrossings
extends RefCounted
## Finds junctions between baked centerlines and rejects overlapping corridors.

const EPSILON := 0.05


static func collect(road: Street, other: Street, width: float) -> bool:
	if not road.bounds.grow(width).intersects(other.bounds, true):
		return true
	var joints := PackedVector2Array()
	var close := PackedVector2Array()
	for p: Vector2 in [road.line[0], road.line[-1]]:
		if other.nearest(p).distance < EPSILON:
			append_joint(joints, p)
	for p: Vector2 in [other.line[0], other.line[-1]]:
		if road.nearest(p).distance < EPSILON:
			append_joint(joints, p)
	for i in road.spans.size():
		var nearby := road.spans[i].grow(width)
		if not nearby.intersects(other.bounds, true):
			continue
		var a := road.line[i]
		var b := road.line[i + 1]
		var direction := a.direction_to(b)
		for j in other.spans.size():
			if not nearby.intersects(other.spans[j], true):
				continue
			var c := other.line[j]
			var d := other.line[j + 1]
			var pair := Geometry2D.get_closest_points_between_segments(a, b, c, d)
			var gap := pair[0].distance_to(pair[1])
			if gap >= width:
				continue
			close.append_array(pair)
			if gap > EPSILON:
				continue
			if absf(direction.cross(c.direction_to(d))) > 0.01:
				append_joint(joints, pair[0])
			else:
				var c_offset := (c - a).dot(direction)
				var d_offset := (d - a).dot(direction)
				var overlap := (
					minf(a.distance_to(b), maxf(c_offset, d_offset))
					- maxf(0, minf(c_offset, d_offset))
				)
				if overlap > EPSILON:
					return false
	for i in range(0, close.size(), 2):
		var at_joint := false
		for point in joints:
			if maxf(point.distance_to(close[i]), point.distance_to(close[i + 1])) <= width * 1.8:
				at_joint = true
				break
		if not at_joint:
			return false
	if not joints.is_empty():
		road.crossings[other.id] = joints
	return true


static func append_joint(joints: PackedVector2Array, point: Vector2) -> void:
	for existing in joints:
		if existing.distance_to(point) < EPSILON:
			return
	joints.append(point)
