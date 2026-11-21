class_name Hud
extends CanvasLayer
## Top bar (resources, day, speed) and bottom build bar.

const SHOWN_RESOURCES: Array[StringName] = [&"food", &"water", &"wood", &"scrap"]
const CATALOG := preload("res://data/buildings/catalog.tres")

var _build_tool: BuildTool
var _resource_labels: Dictionary[StringName, Label] = {}
var _speed_buttons: Array[Button] = []
var _build_buttons: Dictionary[BuildingDef, Button] = {}

@onready var _resources_box: HBoxContainer = %Resources
@onready var _clock_label: Label = %Clock
@onready var _speed_box: HBoxContainer = %Speed
@onready var _build_box: HBoxContainer = %Build


func _ready() -> void:
	for id in SHOWN_RESOURCES:
		var label := Label.new()
		_resources_box.add_child(label)
		_resource_labels[id] = label
		_set_resource(id, Economy.get_amount(id))
	EventBus.resource_changed.connect(_set_resource)
	var names: Array[String] = ["Pause", "1x", "2x", "3x"]
	for speed in names.size():
		var button := Button.new()
		button.text = names[speed]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(GameClock.set_speed.bind(speed))
		_speed_box.add_child(button)
		_speed_buttons.append(button)
	for def in CATALOG.buildings:
		var button := Button.new()
		button.text = "%s\n%s" % [def.display_name, def.cost_text()]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(150, 64)
		button.pressed.connect(_on_build_pressed.bind(def))
		_build_box.add_child(button)
		_build_buttons[def] = button


func bind(build_tool: BuildTool) -> void:
	_build_tool = build_tool


func _process(_delta: float) -> void:
	var phase := "Night" if GameClock.is_night() else "Day"
	_clock_label.text = "Day %d  %s  %02d:00" % [GameClock.day, phase, _hour()]
	for speed in _speed_buttons.size():
		_speed_buttons[speed].set_pressed_no_signal(GameClock.speed == speed)
	var selected: BuildingDef = _build_tool.selected if _build_tool else null
	for def: BuildingDef in _build_buttons:
		_build_buttons[def].set_pressed_no_signal(def == selected)
		_build_buttons[def].disabled = not Economy.can_afford(def.cost)


func _hour() -> int:
	return int(GameClock.time_of_day * 24.0 + 6.0) % 24


func _set_resource(id: StringName, value: int) -> void:
	if _resource_labels.has(id):
		_resource_labels[id].text = "%s %d" % [String(id).capitalize(), value]


func _on_build_pressed(def: BuildingDef) -> void:
	if _build_tool == null:
		return
	if _build_tool.selected == def:
		_build_tool.clear()
	else:
		_build_tool.select(def)
