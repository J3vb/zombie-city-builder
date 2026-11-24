class_name Hud
extends CanvasLayer
## Top bar (resources, day, speed) and bottom build bar.

const SHOWN_RESOURCES: Array[StringName] = [&"food", &"water", &"wood", &"scrap"]
const CATALOG := preload("res://data/buildings/catalog.tres")

var _land_buttons: Dictionary[int, Button] = {}
var _growth := Button.new()
var _road_button := Button.new()
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
	_road_button.text = "Street"
	_road_button.toggle_mode = true
	_road_button.focus_mode = Control.FOCUS_NONE
	_road_button.custom_minimum_size = Vector2(110, 64)
	_road_button.pressed.connect(_on_street_pressed)
	_build_box.add_child(_road_button)
	for def in CATALOG.buildings:
		var button := Button.new()
		button.text = "Home plot" if def.id == &"house" else "%s zone" % def.display_name
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(150, 64)
		button.pressed.connect(_on_build_pressed.bind(def))
		_build_box.add_child(button)
		_build_buttons[def] = button

	for action: PlotTool.Mode in [
		PlotTool.Mode.DEMOLISH,
		PlotTool.Mode.REMOVE_PLOT,
		PlotTool.Mode.REMOVE_ROAD,
		PlotTool.Mode.UNZONE
	]:
		var button := Button.new()
		button.text = {
			PlotTool.Mode.DEMOLISH: "Demolish",
			PlotTool.Mode.REMOVE_PLOT: "Remove plot",
			PlotTool.Mode.REMOVE_ROAD: "Remove street",
			PlotTool.Mode.UNZONE: "Unzone"
		}[action]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_land_pressed.bind(action))
		_build_box.add_child(button)
		_land_buttons[action] = button
	_growth.toggle_mode = true
	_growth.focus_mode = Control.FOCUS_NONE
	_growth.pressed.connect(_toggle_growth)
	_build_box.add_child(_growth)


func bind(build_tool: BuildTool) -> void:
	_build_tool = build_tool
	$BuildingInfo.hide()


func _process(_delta: float) -> void:
	var phase := "Night" if GameClock.is_night() else "Day"
	_clock_label.text = "Day %d  %s  %02d:00" % [GameClock.day, phase, _hour()]
	for speed in _speed_buttons.size():
		_speed_buttons[speed].set_pressed_no_signal(GameClock.speed == speed)
	if _build_tool == null:
		return
	var world := _build_tool.world
	var tool := world.plot_tool
	$BuildingInfo.refresh(tool.selected_building, world.grower)
	_road_button.set_pressed_no_signal(world.road_tool.active)
	_growth.text = "Resume growth" if world.grower.paused else "Pause growth"
	_growth.set_pressed_no_signal(world.grower.paused)
	var message := world.road_tool.hint if world.road_tool.active else tool.hint
	if message.is_empty():
		message = world.grower.status
	%ToolHint.text = message
	%ToolHint.visible = not message.is_empty()
	for def: BuildingDef in _build_buttons:
		var active := (
			tool.mode == PlotTool.Mode.HOME
			if def.id == &"house"
			else (tool.mode == PlotTool.Mode.ZONE and tool.zone == def)
		)
		_build_buttons[def].set_pressed_no_signal(active)
	for action in _land_buttons:
		_land_buttons[action].set_pressed_no_signal(action == tool.mode)


func _hour() -> int:
	return int(GameClock.time_of_day * 24.0 + 6.0) % 24


func _set_resource(id: StringName, value: int) -> void:
	if _resource_labels.has(id):
		_resource_labels[id].text = "%s %d" % [String(id).capitalize(), value]


func _on_build_pressed(def: BuildingDef) -> void:
	if _build_tool == null:
		return
	var tool := _build_tool.world.plot_tool
	var mode := PlotTool.Mode.HOME if def.id == &"house" else PlotTool.Mode.ZONE
	if tool.mode == mode and (mode == PlotTool.Mode.HOME or tool.zone == def):
		tool.clear()
	else:
		tool.select(mode, def)


func _land_pressed(mode: PlotTool.Mode) -> void:
	var tool := _build_tool.world.plot_tool
	if tool.mode == mode:
		tool.clear()
	else:
		tool.select(mode)


func _toggle_growth() -> void:
	var grower := _build_tool.world.grower
	grower.paused = not grower.paused


func _on_street_pressed() -> void:
	if _build_tool.world.road_tool.active:
		_build_tool.world.road_tool.clear()
	else:
		_build_tool.world.road_tool.select()
