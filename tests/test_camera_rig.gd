extends TestCase
## Checks middle-mouse orbit and tilt on the settlement camera.


func test_diagonal_middle_drag_turns_and_tilts_around_the_same_point() -> void:
	var fx := WorldFixture.new()
	var camera := fx.create().camera
	var yaw := camera.rotation.y
	var pitch := camera.pitch_deg
	var focus := camera.global_position
	var radius := camera.lens.global_position.distance_to(focus)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(8, -8)
	camera._unhandled_input(motion)
	assert_eq(camera.rotation.y, yaw, "moving without middle mouse preserves heading")
	assert_eq(camera.pitch_deg, pitch, "moving without middle mouse preserves tilt")

	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	camera._unhandled_input(motion)
	assert_true(camera.rotation.y < yaw, "dragging right turns the camera")
	assert_true(camera.pitch_deg > pitch, "dragging up gives a more overhead view")
	var offset := camera.lens.global_position - focus
	assert_true(is_equal_approx(offset.length(), radius), "drag preserves zoom distance")
	assert_true(offset.normalized().is_equal_approx(camera.lens.global_basis.z), "same focus")
	assert_true(is_equal_approx(-camera.lens.rotation_degrees.x, camera.pitch_deg), "lens tilts")
	fx.destroy()


func test_vertical_middle_drag_stops_at_both_pitch_limits() -> void:
	var fx := WorldFixture.new()
	var camera := fx.create().camera
	var yaw := camera.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	motion.relative = Vector2(0, 1000)
	camera._unhandled_input(motion)
	assert_eq(camera.pitch_deg, 30.0, "drag down stops at the low angle")
	motion.relative.y = -1000
	camera._unhandled_input(motion)
	assert_eq(camera.pitch_deg, 75.0, "drag up stops at the overhead angle")
	assert_eq(camera.rotation.y, yaw, "vertical drag preserves heading")
	fx.destroy()
