class_name BuildPalette
extends PanelContainer
## Category buttons reveal a grid of existing construction orders.

const GROUPS := ["Streets", "Housing", "Production", "Defenses", "Land"]
var current: String = "Streets"
var _buttons: Dictionary[String, Button] = {}
var _modes: Array[Button] = []
var _angle := CheckButton.new()
var _street_tool: RoadTool


func _ready() -> void:
	for title: String in GROUPS:
		var button := Button.new()
		button.text = title
		button.add_theme_font_size_override("font_size", 21)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(select.bind(title))
		%Categories.add_child(button)
		_buttons[title] = button
	var road_icons := [UiSymbols.STREET, UiSymbols.CURVE, UiSymbols.FREEFORM]
	for title: String in ["Straight", "Curved", "Freeform"]:
		var button := Button.new()
		button.text = title
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.icon = UiSymbols.icon(road_icons[_modes.size()])
		button.pressed.connect(_select_mode.bind(_modes.size()))
		add_order("Streets", button)
		_modes.append(button)
	_angle.text = "Angle snap"
	_angle.tooltip_text = "Align near 45° steps relative to the starting street."
	_angle.focus_mode = Control.FOCUS_NONE
	_angle.toggled.connect(_toggle_angles)
	_angle.add_theme_font_size_override("font_size", 19)
	%PaletteHeader.add_child(_angle)
	select(current)


func _select_mode(mode: RoadTool.Mode) -> void:
	if _street_tool.active and _street_tool.mode == mode:
		_street_tool.clear()
	else:
		_street_tool.select(mode)


func _toggle_angles(enabled: bool) -> void:
	_street_tool.angle_snap = enabled


func refresh_streets() -> void:
	for i in _modes.size():
		_modes[i].set_pressed_no_signal(_street_tool.active and _street_tool.mode == i)
	_angle.set_pressed_no_signal(_street_tool.angle_snap)


func add_order(title: String, button: Button, model: String = "") -> void:
	button.set_meta("section", title)
	button.custom_minimum_size = Vector2(154, 54)
	button.add_theme_font_size_override("font_size", 21)
	if not model.is_empty():
		button.icon = load("res://assets/ui/orders/%s.png" % model)
	if button.icon != null:
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_constant_override("icon_max_width", 32 if model.is_empty() else 66)
		button.custom_minimum_size.y = 88
	%Build.add_child(button)
	button.visible = title == current


func select(title: String) -> void:
	current = title
	_angle.visible = title == "Streets"
	for key in _buttons:
		_buttons[key].set_pressed_no_signal(key == title)
	for order in %Build.get_children():
		order.visible = order.get_meta("section") == title
	reset_size()


func bind_region(menu: MenuButton, world: World) -> void:
	_street_tool = world.road_tool
	menu.visible = not world.map_def.places.is_empty()
	var places: PopupMenu = menu.get_popup()
	places.clear()
	places.add_item("Station 4", 0)
	for place in world.map_def.places:
		places.add_item(place.title)


func visit_place(index: int, w: World) -> void:
	var point := w.command_post.sim_center()
	if index > 0:
		point = w.grid.cell_to_world(w.map_def.places[index - 1].extent().get_center())
	w.camera.position = w.to_view(point)
