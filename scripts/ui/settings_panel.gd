class_name SettingsPanel
extends PanelContainer
## Settings opened from the title screen or paused settlement. Escape cancels key capture.

signal closed

var _list := VBoxContainer.new()
var _feedback := Label.new()
var _buttons: Dictionary[StringName, Button] = {}
var _capture: StringName


func _ready() -> void:
	hide()
	custom_minimum_size = Vector2(630, 610)
	var box := VBoxContainer.new()
	add_child(box)
	var heading := Label.new()
	heading.text = "Settings"
	heading.add_theme_font_size_override("font_size", 34)
	box.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	box.add_child(_feedback)
	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(finish)
	box.add_child(done)


func open() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_capture = &""
	_feedback.text = ""
	for bus: String in Settings.BUSES:
		var slider := HSlider.new()
		slider.custom_minimum_size.x = 255
		slider.max_value = 100
		slider.step = 1
		slider.value = roundi(Settings.volume(bus) * 100)
		slider.value_changed.connect(func(v: float) -> void: Settings.set_volume(bus, v / 100.0))
		_row(bus + " volume", slider)
	var scale := OptionButton.new()
	for value: float in Settings.SCALES:
		scale.add_item("%d%%" % roundi(value * 100))
	scale.select(Settings.SCALES.find(Settings.ui_scale))
	scale.item_selected.connect(_scale_changed)
	_row("Interface size", scale)
	_toggle("OpenDyslexic font", "dyslexic_font")
	_toggle("Fullscreen", "fullscreen")
	_toggle("Scroll at screen edges", "edge_scroll")
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
	show()
	scale.grab_focus()


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


func _scale_changed(index: int) -> void:
	Settings.ui_scale = Settings.SCALES[index]
	Settings.apply_display()


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
