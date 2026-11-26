extends PanelContainer
## Displays the settlement's stocks, population and simulation clock.

const STOCK_ICONS := {
	&"food": UiSymbols.FOOD,
	&"water": UiSymbols.WATER,
	&"wood": UiSymbols.WOOD,
	&"scrap": UiSymbols.SCRAP,
	&"ammo": UiSymbols.AMMO
}
const STOCK_COLORS := {
	&"food": Color("#d7bb78"),
	&"water": Color("#8dc4cf"),
	&"wood": Color("#caaa8b"),
	&"scrap": Color("#a8b8b1"),
	&"ammo": Color("#dfaf7e")
}

var _amounts: Dictionary[StringName, Label] = {}
var _people: Label
var _speeds: Array[Button] = []


func _ready() -> void:
	%StationIcon.texture = UiSymbols.icon(UiSymbols.GATE)
	for id: StringName in STOCK_ICONS:
		_amounts[id] = _stat(%Resources, String(id).capitalize(), STOCK_ICONS[id], STOCK_COLORS[id])
	_people = _stat(%Population, "Residents", UiSymbols.RESIDENTS, Color("#dfd4b8"))
	refresh_resources()
	EventBus.resource_changed.connect(_set_resource)
	Economy.capacity_changed.connect(refresh_resources)
	var names := ["Pause", "1×", "2×", "3×"]
	for speed in names.size():
		var button := Button.new()
		button.text = names[speed]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(GameClock.set_speed.bind(speed))
		button.add_theme_font_size_override("font_size", 20)
		%Speed.add_child(button)
		_speeds.append(button)


func _stat(parent: Container, title: String, symbol: int, tint: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	parent.add_child(row)
	var image := TextureRect.new()
	image.texture = UiSymbols.icon(symbol)
	image.modulate = tint
	image.custom_minimum_size = Vector2(26, 26)
	image.size_flags_vertical = SIZE_SHRINK_CENTER
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(image)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", -4)
	stack.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(stack)
	var caption := Label.new()
	caption.theme_type_variation = &"Caption"
	caption.text = title
	stack.add_child(caption)
	var amount := Label.new()
	amount.theme_type_variation = &"Heading"
	amount.add_theme_font_size_override("font_size", 27)
	stack.add_child(amount)
	return amount


func refresh_resources() -> void:
	for id in _amounts:
		_set_resource(id, Economy.get_amount(id))


func _set_resource(id: StringName, value: int) -> void:
	if _amounts.has(id):
		var amount := _amounts[id]
		amount.text = str(value)
		var cell := amount.get_parent().get_parent() as Control
		cell.tooltip_text = (
			"%s · %d / %d in storage" % [String(id).capitalize(), value, Economy.capacity]
		)


func update_watch(population: int) -> void:
	_people.text = str(population)
	var hour := int(GameClock.time_of_day * 24.0 + 6.0) % 24
	%Day.text = "Day %d" % GameClock.day
	%Clock.text = "%02d:00  ·  %s" % [hour, "Night" if GameClock.is_night() else "Daylight"]
	for speed in _speeds.size():
		_speeds[speed].set_pressed_no_signal(GameClock.speed == speed)
