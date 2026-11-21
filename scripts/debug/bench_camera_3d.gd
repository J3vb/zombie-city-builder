class_name BenchCamera3D
extends Node3D
## City-builder camera for the 3D bench: WASD pan, Q/E or middle mouse to
## rotate, wheel to zoom, right mouse drag to tilt.

const PAN_SPEED := 40.0
const ROTATE_SPEED := 1.6
const ZOOM_STEP := 1.15
const MIN_DIST := 8.0
const MAX_DIST := 140.0
const MIN_PITCH := -80.0
const MAX_PITCH := -25.0

var distance: float = 60.0
var pitch_deg: float = -50.0
var bounds: float = 64.0

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_apply()


func _process(delta: float) -> void:
	var dir := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if dir != Vector2.ZERO:
		var move := Vector3(dir.x, 0.0, dir.y).rotated(Vector3.UP, rotation.y)
		position += move * PAN_SPEED * delta * (distance / 60.0)
		position.x = clampf(position.x, -bounds, bounds)
		position.z = clampf(position.z, -bounds, bounds)
	var turn := 0.0
	if Input.is_physical_key_pressed(KEY_Q):
		turn += 1.0
	if Input.is_physical_key_pressed(KEY_E):
		turn -= 1.0
	if turn != 0.0:
		rotation.y += turn * ROTATE_SPEED * delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		distance = maxf(MIN_DIST, distance / ZOOM_STEP)
		_apply()
	elif event.is_action_pressed("camera_zoom_out"):
		distance = minf(MAX_DIST, distance * ZOOM_STEP)
		_apply()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			rotation.y -= motion.relative.x * 0.01
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			pitch_deg = clampf(pitch_deg - motion.relative.y * 0.3, MIN_PITCH, MAX_PITCH)
			_apply()


func _apply() -> void:
	var pitch := deg_to_rad(pitch_deg)
	_camera.position = Vector3(0.0, -sin(pitch), cos(pitch)) * distance
	_camera.look_at(global_position, Vector3.UP)
