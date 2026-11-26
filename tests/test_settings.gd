extends TestCase
## Preferences round-trip and keep reserved or duplicate physical keys usable.

const TEMP := "user://settings-test.cfg"
const BACKUP := "user://settings-before-test.cfg"


func test_preferences_restore_keys_volume_font_and_scale() -> void:
	assert_eq(Settings.save_preferences(BACKUP), OK)
	Settings.reset_keys()
	assert_true(not Settings.bind_key(&"camera_up", KEY_ESCAPE))
	assert_true(not Settings.bind_key(&"camera_up", KEY_S))
	assert_true(Settings.bind_key(&"camera_up", KEY_J))
	Settings.set_volume("Music", 0.35)
	Settings.gate_close = false
	Settings.edge_scroll = false
	Settings.dyslexic_font = true
	Settings.resolution = Vector2i(1280, 720)
	Settings.fullscreen_height = 720
	Settings.ui_scale = 1.15
	assert_eq(Settings.save_preferences(TEMP), OK)
	Settings.reset_keys()
	Settings.fullscreen_height = 0
	Settings.load_preferences(TEMP)
	assert_eq(Settings.resolution, Vector2i(1280, 720))
	assert_eq(Settings.fullscreen_height, 720)
	assert_eq(Settings.key_for(&"camera_up"), KEY_J)
	assert_true(is_equal_approx(Settings.volume("Music"), 0.35))
	assert_true(not Settings.gate_close and not Settings.edge_scroll)
	var theme := load("res://data/settlement_theme.tres") as Theme
	assert_true(theme.default_font != null)
	assert_true(is_equal_approx(Settings.get_window().content_scale_factor, 1.15))
	Settings.load_preferences(BACKUP)
	DirAccess.remove_absolute(TEMP)
	DirAccess.remove_absolute(BACKUP)


func test_resolution_choices_fit_standard_and_wide_displays() -> void:
	for screen: Vector2i in [Vector2i(1920, 1200), Vector2i(3440, 1440), Vector2i(5120, 1440)]:
		var sizes := Settings.window_sizes(screen)
		assert_eq(sizes[0], Vector2i.ZERO)
		assert_eq(sizes.count(screen), 1)
		for size in sizes:
			assert_true(size.x <= screen.x and size.y <= screen.y)
		var renders := Settings.fullscreen_sizes(screen)
		assert_eq(renders[0], screen)
		assert_eq(renders.count(screen), 1)
		for render in renders:
			assert_true(render.x <= screen.x and render.y <= screen.y)
			assert_true(absf(float(screen.x) * render.y / screen.y - render.x) < 1.0)
	assert_true(Vector2i(2560, 1080) in Settings.window_sizes(Vector2i(3440, 1440)))
	assert_true(Vector2i(3840, 1080) in Settings.fullscreen_sizes(Vector2i(5120, 1440)))
	assert_true(Vector2i(1600, 1000) in Settings.window_sizes(Vector2i(1600, 1000)))


func test_legacy_and_unsupported_fullscreen_preferences_use_native() -> void:
	assert_eq(Settings.save_preferences(BACKUP), OK)
	var config := ConfigFile.new()
	config.set_value("display", "resolution", Vector2i(1280, 720))
	for height: Variant in [null, 8000, "720"]:
		if height != null:
			config.set_value("display", "fullscreen_height", height)
		assert_eq(config.save(TEMP), OK)
		Settings.load_preferences(TEMP)
		assert_eq(Settings.fullscreen_height, 0)
		assert_eq(Settings.resolution, Vector2i(1280, 720))
	Settings.load_preferences(BACKUP)
	DirAccess.remove_absolute(TEMP)
	DirAccess.remove_absolute(BACKUP)
