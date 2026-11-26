class_name Street
extends RefCounted
## A street keeps its ID and original control points when a branch joins it.

var id: int
var controls: PackedVector2Array
var quadratic := false
var line := PackedVector2Array()
var bounds := Rect2()
var spans: Array[Rect2] = []
var crossings: Dictionary[int, PackedVector2Array] = {}
var strips: Array[PackedVector2Array] = []
var cells: Array[Vector2i] = []
var error := ""


func bake(width: float, spacing: float) -> void:
	var curve := Curve2D.new()
	curve.bake_interval = spacing * 0.5
	if quadratic:
		curve.add_point(controls[0], Vector2.ZERO, (controls[1] - controls[0]) * 2.0 / 3.0)
		curve.add_point(controls[2], (controls[1] - controls[2]) * 2.0 / 3.0)
	else:
		_add_spline_controls(curve)
	var length := curve.get_baked_length()
	var count := maxi(1, ceili(length / spacing))
	for i in count + 1:
		line.append(curve.sample_baked(length * i / count))
	line[0] = controls[0]
	line[-1] = controls[-1]
	bounds = Rect2(line[0], Vector2.ZERO)
	for i in count:
		var span := Rect2(line[i], line[i + 1] - line[i]).abs()
		spans.append(span)
		bounds = bounds.merge(span)
	_bake_strips(width)


func _add_spline_controls(curve: Curve2D) -> void:
	for i in controls.size():
		var previous := controls[maxi(0, i - 1)]
		var following := controls[mini(i + 1, controls.size() - 1)]
		var tangent := previous.direction_to(following)
		curve.add_point(
			controls[i],
			-tangent * previous.distance_to(controls[i]) / 3.0,
			tangent * controls[i].distance_to(following) / 3.0
		)


func _bake_strips(width: float) -> void:
	var count := line.size() - 1
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in line.size():
		var before := line[maxi(0, i - 1)].direction_to(line[i])
		var after := line[i].direction_to(line[mini(i + 1, count)])
		var normal := (before + after).normalized().orthogonal()
		var side := after if i < count else before
		var offset := normal * (width * 0.5 / maxf(0.2, normal.dot(side.orthogonal())))
		left.append(line[i] + offset)
		right.append(line[i] - offset)
		if i > 0:
			strips.append(PackedVector2Array([left[i - 1], left[i], right[i], right[i - 1]]))


func length_m(view_scale: float) -> float:
	var length := 0.0
	for i in spans.size():
		length += line[i].distance_to(line[i + 1])
	return length * view_scale


func nearest(point: Vector2) -> Dictionary:
	var best := INF
	var hit := {}
	for i in line.size() - 1:
		var p := Geometry2D.get_closest_point_to_segment(point, line[i], line[i + 1])
		var distance := p.distance_squared_to(point)
		if distance < best:
			best = distance
			hit = {
				"road": self,
				"point": p,
				"tangent": line[i].direction_to(line[i + 1]),
				"segment": i,
				"distance": sqrt(distance)
			}
	return hit


func crosses_itself(width: float) -> bool:
	if controls.size() == 2:
		return false
	for i in line.size() - 1:
		var nearby := spans[i].grow(width)
		for j in range(i + 2, line.size() - 1):
			if not nearby.intersects(spans[j], true):
				continue
			if (
				Geometry2D.segment_intersects_segment(line[i], line[i + 1], line[j], line[j + 1])
				!= null
			):
				return true
			if j - i <= 8:
				continue
			var near := Geometry2D.get_closest_points_between_segments(
				line[i], line[i + 1], line[j], line[j + 1]
			)
			if near[0].distance_to(near[1]) < width * 0.95:
				return true
	return false
