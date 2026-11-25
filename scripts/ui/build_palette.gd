class_name BuildPalette
extends PanelContainer
## Category buttons reveal a grid of existing construction orders.

const GROUPS := ["Streets", "Housing", "Production", "Defenses", "Land"]
var current: String = "Streets"
var _buttons: Dictionary[String, Button] = {}


func _ready() -> void:
	for title: String in GROUPS:
		var button := Button.new()
		button.text = title
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(select.bind(title))
		%Categories.add_child(button)
		_buttons[title] = button
	select(current)


func add_order(title: String, button: Button, model: String = "") -> void:
	button.set_meta("section", title)
	button.custom_minimum_size = Vector2(134, 48)
	button.add_theme_font_size_override("font_size", 19)
	if not model.is_empty():
		button.icon = load("res://assets/ui/orders/%s.png" % model)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_constant_override("icon_max_width", 66)
		button.custom_minimum_size.y = 84
	%Build.add_child(button)
	button.visible = title == current


func select(title: String) -> void:
	current = title
	for key in _buttons:
		_buttons[key].set_pressed_no_signal(key == title)
	for order in %Build.get_children():
		order.visible = order.get_meta("section") == title
	reset_size()


func bind_region(menu: MenuButton, world: World) -> void:
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
