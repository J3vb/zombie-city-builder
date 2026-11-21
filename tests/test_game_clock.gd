extends TestCase

var _clock: Node


func _setup() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	_clock = tree.root.get_node("GameClock")
	_clock.reset()


func test_paused_clock_does_not_move() -> void:
	_setup()
	_clock.set_speed(0)
	_clock._process(10.0)
	assert_eq(_clock.time_of_day, 0.0, "time_of_day")


func test_night_comes_after_dusk() -> void:
	_setup()
	var nights: Array[int] = []
	var on_night := func(day: int) -> void: nights.append(day)
	EventBus.night_started.connect(on_night)
	_clock.time_of_day = 0.69
	_clock._advance(10.0)
	EventBus.night_started.disconnect(on_night)
	assert_true(_clock.is_night(), "should be night")
	assert_eq(nights, [1] as Array[int], "night_started days")


func test_day_rolls_over() -> void:
	_setup()
	_clock.time_of_day = 0.999
	_clock._advance(10.0)
	assert_eq(_clock.day, 2, "day")
