class_name SettingsPanel
extends PanelContainer
## Settings opened from the title screen or paused settlement. Escape cancels key capture.

signal closed

const PAGES := ["Display", "Audio", "Controls", "Accessibility"]

var _list := VBoxContainer.new()
var _feedback := Label.new()
var _buttons: Dictionary[StringName, Button] = {}
var _capture: StringName

var _nav := VBoxContainer.new()
var _full := false
var _size := Vector2i.ZERO
var _scale := 1.0
var _sizes: Array[Vector2i] = []
var _resolution: OptionButton
var _apply := Button.new()


func _ready() -> void:
	hide()
	custom_minimum_size = Vector2(860, 565)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var heading := Label.new()
	heading.theme_type_variation = &"Heading"
	heading.text = "Settings"
	heading.add_theme_font_size_override("font_size", 48)
	box.add_child(heading)
	box.add_child(HSeparator.new())
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	box.add_child(body)
	body.add_child(_nav)
	for title: String in PAGES:
		var tab := Button.new()
		tab.text = title
		tab.custom_minimum_size.x = 175
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.toggle_mode = true
		tab.pressed.connect(_show_page.bind(title))
		_nav.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	box.add_child(_feedback)
	var foot := HBoxContainer.new()
	box.add_child(foot)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(finish)
	foot.add_child(back)
	var space := Control.new()
	space.size_flags_horizontal = SIZE_EXPAND_FILL
	foot.add_child(space)
	_apply.text = "Apply changes"
	_apply.pressed.connect(_apply_display)
	foot.add_child(_apply)


func open() -> void:
	_full = Settings.fullscreen
	_size = Settings.resolution
	_scale = Settings.ui_scale
	_sizes = Settings.window_sizes()
	_show_page("Display")
	show()
	(_nav.get_child(0) as Button).grab_focus()


func _show_page(page: String) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_capture = &""
	_feedback.text = ""
	for child: Button in _nav.get_children():
		child.set_pressed_no_signal(child.text == page)
	_apply.visible = page == "Display"
	match page:
		"Display":
			_display_page()
		"Audio":
			for bus: String in Settings.BUSES:
				var slider := HSlider.new()
				slider.custom_minimum_size.x = 255
				slider.max_value = 100
				slider.step = 1
				slider.value = roundi(Settings.volume(bus) * 100)
				slider.value_changed.connect(
					func(v: float) -> void: Settings.set_volume(bus, v / 100.0)
				)
				_row(bus + " volume", slider)
		"Accessibility":
			_toggle("OpenDyslexic font", "dyslexic_font")
			_toggle("Scroll at screen edges", "edge_scroll")
		"Controls":
			_toggle("Close new gates at dusk", "gate_close")
			for action in Settings.ACTIONS:
				var button := Button.new()
				button.pressed.connect(_listen.bind(action))
				_buttons[action] = button
				_row(String(action).replace("_", " ").capitalize(), button)
			var reset := Button.new()
			reset.text = "Restore default keys"
			reset.pressed.connect(_reset_keys)
			_list.add_child(reset)
			_refresh_keys()


func _display_page() -> void:
	var mode := OptionButton.new()
	mode.add_item("Windowed")
	mode.add_item("Fullscreen")
	mode.select(int(_full))
	mode.item_selected.connect(_mode_selected)
	_row("Window mode", mode)
	var scale := OptionButton.new()
	for value: float in Settings.SCALES:
		scale.add_item("%d%%" % roundi(value * 100))
	scale.select(Settings.SCALES.find(_scale))
	scale.item_selected.connect(func(i: int) -> void: _scale = Settings.SCALES[i])
	_row("Interface scale", scale)
	_resolution = OptionButton.new()
	_row("Resolution", _resolution)
	_resolution.item_selected.connect(func(i: int) -> void: _size = _sizes[i])
	_mode_selected(int(_full))


func _mode_selected(index: int) -> void:
	_full = index == 1
	_resolution.clear()
	if _full:
		_resolution.add_item("Desktop resolution")
	else:
		for preset in _sizes:
			_resolution.add_item(
				"Automatic" if preset == Vector2i.ZERO else "%d × %d" % [preset.x, preset.y]
			)
		_resolution.select(maxi(0, _sizes.find(_size)))
	_resolution.disabled = _full


func _apply_display() -> void:
	var reset_auto := Settings.resolution != _size and _size == Vector2i.ZERO
	Settings.fullscreen = _full
	Settings.resolution = _size
	Settings.ui_scale = _scale
	Settings.apply_display(reset_auto)
	_feedback.text = (
		"Display settings saved."
		if Settings.save_preferences() == OK
		else "Could not save display settings."
	)


func _row(title: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	_list.add_child(row)


func _toggle(title: String, key: String) -> void:
	var check := CheckButton.new()
	check.button_pressed = bool(Settings.get(key))
	check.toggled.connect(
		func(value: bool) -> void:
			Settings.set(key, value)
			Settings.apply_display()
	)
	_row(title, check)


func _refresh_keys() -> void:
	for action in _buttons:
		var key := DisplayServer.keyboard_get_keycode_from_physical(Settings.key_for(action) as Key)
		_buttons[action].text = OS.get_keycode_string(key)


func _listen(action: StringName) -> void:
	_capture = action
	_feedback.text = "Press a key. Escape cancels."


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if _capture == &"":
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			finish()
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE:
		_feedback.text = ""
	elif not Settings.bind_key(_capture, event.physical_keycode):
		_feedback.text = "That key is in use. Press another key or Escape."
		return
	else:
		_refresh_keys()
		_feedback.text = ""
	_capture = &""


func _reset_keys() -> void:
	Settings.reset_keys()
	_refresh_keys()
	_feedback.text = ""


func finish() -> void:
	if Settings.save_preferences() != OK:
		_feedback.text = "Could not save settings. Check available disk space."
		return
	hide()
	closed.emit()
