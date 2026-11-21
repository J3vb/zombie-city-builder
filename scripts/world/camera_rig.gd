class_name CameraRig
extends Camera2D
## Pan with WASD or screen edges, zoom with the mouse wheel, stay inside the map.

var bounds := Rect2()

var _balance: BalanceDef = preload("res://data/balance.tres")


func set_bounds(rect: Rect2) -> void:
	bounds = rect
	position = rect.get_center()
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)


func _process(delta: float) -> void:
	var dir := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if dir == Vector2.ZERO:
		dir = _edge_direction()
	if dir != Vector2.ZERO:
		position += dir * _balance.camera_pan_speed * delta / zoom.x
		_clamp_to_bounds()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		_set_zoom(zoom.x + _balance.camera_zoom_step)
	elif event.is_action_pressed("camera_zoom_out"):
		_set_zoom(zoom.x - _balance.camera_zoom_step)


func _set_zoom(value: float) -> void:
	var z := clampf(value, _balance.camera_zoom_min, _balance.camera_zoom_max)
	zoom = Vector2(z, z)
	_clamp_to_bounds()


func _edge_direction() -> Vector2:
	if not DisplayServer.window_is_focused():
		return Vector2.ZERO
	var view := get_viewport().get_visible_rect()
	var mouse := get_viewport().get_mouse_position()
	if not view.has_point(mouse):
		return Vector2.ZERO
	var m := _balance.edge_scroll_margin
	var dir := Vector2.ZERO
	if mouse.x < m:
		dir.x = -1
	elif mouse.x > view.size.x - m:
		dir.x = 1
	if mouse.y < m:
		dir.y = -1
	elif mouse.y > view.size.y - m:
		dir.y = 1
	return dir


func _clamp_to_bounds() -> void:
	if bounds.size == Vector2.ZERO:
		return
	var half := get_viewport_rect().size / (2.0 * zoom)
	var min_pos := bounds.position + half
	var max_pos := bounds.end - half
	position.x = (
		clampf(position.x, min_pos.x, max_pos.x) if min_pos.x < max_pos.x else bounds.get_center().x
	)
	position.y = (
		clampf(position.y, min_pos.y, max_pos.y) if min_pos.y < max_pos.y else bounds.get_center().y
	)
