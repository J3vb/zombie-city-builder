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
	Settings.ui_scale = 1.15
	assert_eq(Settings.save_preferences(TEMP), OK)
	Settings.reset_keys()
	Settings.load_preferences(TEMP)
	assert_eq(Settings.key_for(&"camera_up"), KEY_J)
	assert_true(is_equal_approx(Settings.volume("Music"), 0.35))
	assert_true(not Settings.gate_close and not Settings.edge_scroll)
	var theme := load("res://data/settlement_theme.tres") as Theme
	assert_true(theme.default_font != null)
	assert_true(is_equal_approx(Settings.get_window().content_scale_factor, 1.15))
	Settings.load_preferences(BACKUP)
	DirAccess.remove_absolute(TEMP)
	DirAccess.remove_absolute(BACKUP)
