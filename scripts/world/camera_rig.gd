class_name CameraRig
extends Node3D
## Pans, orbits and tilts a camera around a point on the playable ground.

var bounds := Rect2()
var overview_distance := 0.0
var distance: float
var pitch_deg: float

var _balance: BalanceDef = preload("res://data/balance.tres")

@onready var lens: Camera3D = $Camera3D


func _ready() -> void:
	distance = _balance.camera_start_distance
	pitch_deg = _balance.camera_start_pitch
	_apply()


func set_bounds(rect: Rect2) -> void:
	bounds = rect
	_clamp_position()


func _process(delta: float) -> void:
	var dir := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if dir == Vector2.ZERO and Settings.edge_scroll:
		dir = _edge_direction()
	var move := Vector3(dir.x, 0, dir.y).rotated(Vector3.UP, rotation.y)
	position += (
		move * _balance.camera_pan_speed * delta * (distance / _balance.camera_start_distance)
	)
	_clamp_position()
	var turn := Input.get_axis("camera_rotate_right", "camera_rotate_left")
	var tilt := Input.get_axis("camera_tilt_down", "camera_tilt_up")
	rotation.y += turn * _balance.camera_turn_speed * delta
	if tilt != 0:
		pitch_deg = clampf(pitch_deg + tilt * _balance.camera_tilt_speed * delta, 30, 75)
		_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		distance = maxf(_balance.camera_zoom_min, distance / _balance.camera_zoom_step)
		_apply()
	elif event.is_action_pressed("camera_zoom_out"):
		distance = minf(
			maxf(overview_distance, _balance.camera_zoom_max), distance * _balance.camera_zoom_step
		)
		_apply()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		rotation.y -= event.relative.x * _balance.camera_drag_speed


func _clamp_position() -> void:
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.y, bounds.end.y)


func _edge_direction() -> Vector2:
	if not DisplayServer.window_is_focused():
		return Vector2.ZERO
	var rect := get_viewport().get_visible_rect()
	var mouse := get_viewport().get_mouse_position()
	if not rect.has_point(mouse):
		return Vector2.ZERO
	var m := _balance.edge_scroll_margin
	return (
		Vector2(
			int(mouse.x > rect.end.x - m) - int(mouse.x < m),
			int(mouse.y > rect.end.y - m) - int(mouse.y < m)
		)
		. normalized()
	)


func _apply() -> void:
	var pitch := deg_to_rad(pitch_deg)
	lens.position = Vector3(0, sin(pitch), cos(pitch)) * distance
	lens.rotation.x = -pitch


func ground_at(screen: Vector2) -> Variant:
	return ray_to_ground(lens.project_ray_origin(screen), lens.project_ray_normal(screen))


static func ray_to_ground(origin: Vector3, direction: Vector3) -> Variant:
	if direction.y >= -0.000001:
		return null
	return Plane(Vector3.UP, 0).intersects_ray(origin, direction)
