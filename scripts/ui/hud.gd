class_name Hud
extends CanvasLayer
## Top bar (resources, day, speed) and bottom build bar.

const WATCHTOWER := preload("res://data/buildings/watchtower.tres")
const RIFLE_TOWER := preload("res://data/buildings/rifle_tower.tres")
const BARRIERS: Array[BarrierDef] = [Perimeter.BARRICADE, Perimeter.WALL, Perimeter.GATE]
const CATALOG := preload("res://data/buildings/catalog.tres")

var _services: Array[ServiceDef] = []
var _land_buttons: Dictionary[int, Button] = {}
var _displayed_dawn := 0

var _growth := Button.new()
var _build_tool: BuildTool
var _defense_buttons: Array[Button] = []
var _build_buttons: Dictionary[BuildingDef, Button] = {}

@onready var _palette: BuildPalette = %Palette


func _ready() -> void:
	$StatusBar.resized.connect(_position_reports)
	_position_reports.call_deferred()
	for entry: Array in [
		[%ToggleBuild, UiSymbols.BUILD],
		[%Trips, UiSymbols.TRIPS],
		[%Services, UiSymbols.SERVICES],
		[%Places, UiSymbols.MAP],
		[%GuideButton, UiSymbols.GUIDE],
		[%Menu, UiSymbols.MENU]
	]:
		var button: Button = entry[0]
		button.icon = UiSymbols.icon(entry[1])
	%ToggleBuild.toggled.connect(_palette.set_visible)
	%Places.get_popup().id_pressed.connect(
		func(index: int) -> void: _palette.visit_place(index, _build_tool.world)
	)
	%GuideButton.pressed.connect($OpeningGuide.toggle)
	for id in ["clinic", "cold_room", "generator", "floodlight"]:
		_services.append(load("res://data/buildings/%s.tres" % id) as ServiceDef)
	%Services.get_popup().add_item("Town health and power", 0)
	%Services.get_popup().add_item("Research and radio", 100)
	for i in _services.size():
		%Services.get_popup().add_item("Build " + _services[i].display_name, i + 1)
	%Services.get_popup().add_item("Build checkpoint gate", _services.size() + 1)
	%Services.get_popup().id_pressed.connect(_service)
	%Trips.pressed.connect(_open_trips)
	for def in CATALOG.buildings:
		var button := Button.new()
		match def.placement:
			BuildingDef.Placement.HOME_PLOT:
				button.text = "Home plot"
			BuildingDef.Placement.ZONE:
				button.text = "%s zone" % def.display_name
			BuildingDef.Placement.DIRECT:
				button.text = def.display_name
				button.tooltip_text = (
					"%d × %d tiles · %s" % [def.size.x, def.size.y, def.cost_text()]
				)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_build_pressed.bind(def))
		var models := {"house": "house_1", "farm": "farm_1", "storage": "storage_1"}
		var category := "Housing" if def.id == &"house" else "Production"
		_palette.add_order(category, button, models.get(String(def.id), String(def.id)))
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
		_palette.add_order("Land", button)
		_land_buttons[action] = button
	for i in BARRIERS.size() + 2:
		var button := Button.new()
		var model := ""
		if i < BARRIERS.size():
			button.text = BARRIERS[i].title
		else:
			var tower := WATCHTOWER if i == BARRIERS.size() else RIFLE_TOWER
			button.text = tower.display_name
			model = String(tower.id)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select_defense.bind(i))
		_defense_buttons.append(button)
		_palette.add_order("Defenses", button, model)
	_growth.toggle_mode = true
	_growth.focus_mode = Control.FOCUS_NONE
	_growth.pressed.connect(_toggle_growth)
	_palette.add_order("Land", _growth)


func _position_reports() -> void:
	var top: float = $StatusBar.size.y + 16
	$Reports.offset_top = top
	$OpeningGuide.offset_top = top


func _service(index: int) -> void:
	if _build_tool == null:
		return
	if index == 100:
		$ServicePanel.hide()
		$ExpeditionPanel.hide()
		$ResearchPanel.open(_build_tool.world)
		return
	$ResearchPanel.hide()
	if index == 0:
		$ExpeditionPanel.hide()
		$ServicePanel.open(_build_tool.world)
	elif index <= _services.size():
		$ServicePanel.hide()
		_build_tool.select(_services[index - 1])
	else:
		$ServicePanel.hide()
		_build_tool.world.plot_tool.select_barrier(Perimeter.CHECKPOINT)


func _open_trips() -> void:
	$ResearchPanel.hide()
	if _build_tool != null:
		$ServicePanel.hide()
		$ExpeditionPanel.open(_build_tool.world.expeditions)


func bind(build_tool: BuildTool, guided: bool = false) -> void:
	%MapName.text = build_tool.world.map_def.display_name
	$StatusBar.refresh_resources()
	%GuideButton.visible = guided
	$OpeningGuide.visible = guided
	if guided:
		$OpeningGuide.bind(build_tool.world)
	$ResearchPanel.hide()
	_build_tool = build_tool
	_palette.bind_region(%Places, build_tool.world)
	_palette.select("Streets")
	%ToggleBuild.set_pressed_no_signal(false)
	_palette.hide()
	$ServicePanel.hide()
	$BuildingInfo.reset()
	$ExpeditionPanel.hide()
	%DawnReport.hide()
	_displayed_dawn = 0


func _process(_delta: float) -> void:
	if _build_tool == null:
		return
	var world := _build_tool.world
	var tool := world.plot_tool
	$ResearchPanel.refresh()
	$ServicePanel.refresh()
	$ExpeditionPanel.refresh()
	%Trips.text = (
		"Expedition decision"
		if world.expeditions.phase == Expeditions.Phase.CHOICE
		else "Expeditions"
	)
	$StatusBar.update_watch(world.safety.people.size())
	var alarm := PackedStringArray()
	if not world.horde.warning().is_empty():
		alarm.append(world.horde.warning())
	if not world.admissions.report.is_empty():
		alarm.append(world.admissions.report)
	if world.safety.threatened > 0:
		alarm.append("Shelter alert · Walkers near %d" % world.safety.threatened)
	if not world.safety.last_loss.is_empty():
		alarm.append("Last casualty: %s" % world.safety.last_loss)
	%CivilianAlert.text = "   ·   ".join(alarm)
	%CivilianAlert.visible = not alarm.is_empty()
	if world.jobs.last_dawn != _displayed_dawn:
		_displayed_dawn = world.jobs.last_dawn
		%DawnReport.visible = not world.jobs.last_consumed.is_empty()
		var report := (
			"Dawn %d   ·   Stored %s   ·   Used %s"
			% [
				_displayed_dawn,
				_amounts(world.jobs.last_output),
				_amounts(world.jobs.last_consumed)
			]
		)
		if not world.jobs.last_overflow.is_empty():
			report += "   ·   No room for %s" % _amounts(world.jobs.last_overflow)
		if not world.jobs.last_shortage.is_empty():
			report += "   ·   Short %s" % _amounts(world.jobs.last_shortage)
		%DawnReport.text = report
	$BuildingInfo.refresh(tool.selected_building, world.grower)
	$PerimeterInfo.refresh(world, tool.selected_segment)
	_palette.refresh_streets()
	_growth.text = "Resume growth" if world.grower.paused else "Pause growth"
	_growth.set_pressed_no_signal(world.grower.paused)
	var message := world.road_tool.hint if world.road_tool.active else tool.hint
	if _build_tool.selected != null:
		message = _build_tool.hint
	if message.is_empty():
		message = world.grower.status
	%ToolHint.text = message
	for def: BuildingDef in _build_buttons:
		var active := _build_tool.selected == def
		if def.placement == BuildingDef.Placement.HOME_PLOT:
			active = tool.mode == PlotTool.Mode.HOME
		elif def.placement == BuildingDef.Placement.ZONE:
			active = tool.mode == PlotTool.Mode.ZONE and tool.zone == def
		_build_buttons[def].set_pressed_no_signal(active)
	for i in BARRIERS.size():
		var active := tool.mode == PlotTool.Mode.PERIMETER and tool.barrier == BARRIERS[i]
		_defense_buttons[i].set_pressed_no_signal(active)
	_defense_buttons[BARRIERS.size()].set_pressed_no_signal(_build_tool.selected == WATCHTOWER)
	_defense_buttons[BARRIERS.size() + 1].set_pressed_no_signal(_build_tool.selected == RIFLE_TOWER)
	for action in _land_buttons:
		_land_buttons[action].set_pressed_no_signal(action == tool.mode)


func _amounts(amounts: Dictionary[StringName, int]) -> String:
	return "0" if amounts.is_empty() else BuildingDef.format_cost(amounts)


func _on_build_pressed(def: BuildingDef) -> void:
	if _build_tool == null:
		return
	var tool := _build_tool.world.plot_tool
	if def.placement == BuildingDef.Placement.DIRECT:
		if _build_tool.selected == def:
			_build_tool.clear()
		else:
			_build_tool.select(def)
		return
	var mode := (
		PlotTool.Mode.HOME
		if def.placement == BuildingDef.Placement.HOME_PLOT
		else PlotTool.Mode.ZONE
	)
	if tool.mode == mode and (mode == PlotTool.Mode.HOME or tool.zone == def):
		tool.clear()
	else:
		tool.select(mode, def)


func _select_defense(index: int) -> void:
	if index < BARRIERS.size():
		_build_tool.world.plot_tool.select_barrier(BARRIERS[index])
	else:
		_build_tool.select(WATCHTOWER if index == BARRIERS.size() else RIFLE_TOWER)


func _land_pressed(mode: PlotTool.Mode) -> void:
	var tool := _build_tool.world.plot_tool
	if tool.mode == mode:
		tool.clear()
	else:
		tool.select(mode)


func _toggle_growth() -> void:
	var grower := _build_tool.world.grower
	grower.paused = not grower.paused
