extends TestCase
## Verify that objectives respond to the player's town, and alerts keep a reserved audio voice.


func test_connected_street_advances_and_guide_can_be_reopened() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var guide := OpeningGuide.new()
	w.add_child(guide)
	guide.bind(w)
	guide.advance()
	assert_eq(guide.step, 0)
	var start := w.roads.entrance
	var tiles := float(w.grid.tile_size)
	var path := PackedVector2Array([start, start + Vector2(0, 4) * tiles])
	assert_true(w.roads.add_road(path) != null)
	guide.advance()
	assert_eq(guide.step, 1)
	guide.toggle()
	assert_true(not guide.visible)
	guide.toggle()
	assert_true(guide.visible)
	assert_eq(guide.step, 1)
	fx.destroy()


func test_sound_mixer_uses_bounded_voices_and_distinct_watch_music() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	AudioManager.bind(w)
	assert_eq(AudioManager.track, "day_watch")
	for id: String in AudioManager.TRACKS + AudioManager.EFFECTS:
		assert_true(AudioManager._clips.has(id), "Missing audio " + id)
	assert_eq(AudioManager._voices.size(), AudioManager.POOL_SIZE)
	AudioManager.effect("warning")
	assert_true(AudioManager._alert.stream == AudioManager._clips["warning"])
	GameClock.time_of_day = 0.85
	GameClock._dusk_sent = true
	w.horde.warning_day = GameClock.day
	w.horde.approach = 1
	AudioManager._phase_timer = 0
	AudioManager._process(0.3)
	assert_eq(AudioManager.track, "horde_watch")
	fx.destroy()
