extends Node
## Stores display, audio, controls and settlement preferences across sessions.

const PATH := "user://settings.cfg"
const BUSES := ["Master", "Music", "SFX", "UI"]
const ACTIONS: Array[StringName] = [
	&"camera_up",
	&"camera_down",
	&"camera_left",
	&"camera_right",
	&"camera_rotate_left",
	&"camera_rotate_right",
	&"camera_tilt_up",
	&"camera_tilt_down",
	&"speed_pause",
	&"speed_1",
	&"speed_2",
	&"speed_3"
]
const SCALES := [0.85, 1.0, 1.15, 1.3]
const FONT_PATH := "res://assets/fonts/OpenDyslexic-Regular.otf"

var edge_scroll := true
var gate_close := true
var dyslexic_font := false
var fullscreen := false
var ui_scale := 1.0
var _theme: Theme = preload("res://data/settlement_theme.tres")
var _config := ConfigFile.new()
var _default_keys: Dictionary[StringName, int] = {}


func _ready() -> void:
	for action in ACTIONS:
		_default_keys[action] = key_for(action)
	load_preferences(PATH)


func load_preferences(path: String) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		config.clear()
	_config = config
	edge_scroll = _flag("edge_scroll", true)
	gate_close = _flag("gate_close", true)
	fullscreen = _flag("fullscreen", false)
	dyslexic_font = _flag("dyslexic_font", false)
	var scale: Variant = config.get_value("display", "ui_scale", 1.0)
	ui_scale = float(scale) if scale in SCALES else 1.0
	apply_display()
	for bus: String in BUSES:
		var level: Variant = config.get_value("audio", bus, 1.0)
		set_volume(bus, float(level) if typeof(level) in [TYPE_INT, TYPE_FLOAT] else 1.0)
	var loaded: Dictionary[StringName, int] = {}
	var used: Array[int] = []
	for action in ACTIONS:
		var key: Variant = config.get_value("keys", action, _default_keys[action])
		if typeof(key) != TYPE_INT or not _available(key) or key in used:
			loaded.clear()
			break
		loaded[action] = key
		used.append(key)
	for action in ACTIONS:
		_apply_key(action, loaded.get(action, _default_keys[action]))


func _flag(key: String, fallback: bool) -> bool:
	var value: Variant = _config.get_value("display", key, fallback)
	return value if typeof(value) == TYPE_BOOL else fallback


func apply_display() -> void:
	get_window().content_scale_factor = ui_scale
	_theme.default_font = load(FONT_PATH) as Font if dyslexic_font else null
	if DisplayServer.get_name() != "headless":
		var mode := Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		if get_window().mode != mode:
			get_window().mode = mode


func volume(bus: String) -> float:
	var index := AudioServer.get_bus_index(bus)
	if index < 0 or AudioServer.is_bus_mute(index):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


func set_volume(bus: String, level: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		var value := clampf(level, 0.0, 1.0)
		AudioServer.set_bus_mute(index, value <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))


func key_for(action: StringName) -> int:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.physical_keycode
	return KEY_NONE


func _available(key: int) -> bool:
	if key <= KEY_NONE or key in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_BACKSPACE]:
		return false
	for action in InputMap.get_actions():
		if action in ACTIONS or action.begins_with("ui_"):
			continue
		if key_for(action) == key:
			return false
	return true


func bind_key(action: StringName, key: int) -> bool:
	if action not in ACTIONS or not _available(key):
		return false
	for other in ACTIONS:
		if other != action and key_for(other) == key:
			return false
	_apply_key(action, key)
	return true


func _apply_key(action: StringName, key: int) -> void:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var event := InputEventKey.new()
	event.physical_keycode = key as Key
	InputMap.action_add_event(action, event)


func reset_keys() -> void:
	for action in ACTIONS:
		_apply_key(action, _default_keys[action])


func save_preferences(path: String = PATH) -> Error:
	for bus: String in BUSES:
		_config.set_value("audio", bus, volume(bus))
	for key: String in ["edge_scroll", "gate_close", "fullscreen", "dyslexic_font", "ui_scale"]:
		_config.set_value("display", key, get(key))
	for action in ACTIONS:
		_config.set_value("keys", action, key_for(action))
	return _config.save(path)
