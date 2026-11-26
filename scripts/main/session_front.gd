class_name SessionFront
extends Node
## Starts the selected settlement, pauses all simulation and returns to the title.

const GAME := preload("res://scenes/main/main.tscn")
const STATION_PREVIEW := "res://scenes/main/station_preview.tscn"
const MAPS: Array[MapDef] = [
	preload("res://data/maps/starter_map.tres"),
	preload("res://data/maps/mill_crossing.tres"),
	preload("res://data/maps/veydam_basin.tres")
]

var game: Main
var _settings := SettingsPanel.new()
var _slots := SaveSlots.new()
var _confirming := false
var _preview: Node3D
@onready var _panel: PanelContainer = %Panel
@onready var _choice: OptionButton = %Map


func _ready() -> void:
	var map_icon := UiSymbols.icon(UiSymbols.MAP)
	_choice.add_theme_constant_override("icon_max_width", 22)
	for map in MAPS:
		_choice.add_icon_item(map_icon, map.display_name)
	_choice.item_selected.connect(_describe)
	%SettingsCenter.add_child(_slots)
	%Continue.pressed.connect(_continue_game)
	%Saves.pressed.connect(_open_slots)
	_slots.closed.connect(_close_slots)
	_slots.load_requested.connect(_load_slot)
	%SettingsCenter.add_child(_settings)
	%Options.pressed.connect(_open_settings)
	_settings.closed.connect(_close_settings)
	%Start.pressed.connect(start_game)
	%Resume.pressed.connect(resume_game)
	%Return.pressed.connect(_ask_return)
	%Quit.pressed.connect(AudioManager.quit_game)
	%Confirm.pressed.connect(return_to_title)
	%Back.pressed.connect(pause_game)
	%Emblem.texture = UiSymbols.icon(UiSymbols.GATE)
	for action: Button in [%Start, %Continue, %Resume]:
		action.icon = UiSymbols.icon(UiSymbols.ARROW)
		action.add_theme_constant_override("icon_max_width", 22)
	show_title()


func show_title() -> void:
	AudioManager.play_title_music()
	get_tree().paused = true
	%KeyArt.show()
	_display(true)
	_describe(_choice.selected)
	if %Continue.visible:
		%Continue.grab_focus()
	else:
		%Start.grab_focus()


func _continue_game() -> void:
	_open_slots()
	var slot := SaveManager.latest_slot()
	if slot >= 0:
		_load_slot(slot)


func start_game() -> void:
	if game != null:
		return
	get_tree().paused = false
	%KeyArt.hide()
	game = GAME.instantiate() as Main
	game.selected_map = MAPS[_choice.selected]
	game.guided = true
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	SaveManager.bind(game)
	game.world.camera.lens.make_current()
	var menu: Button = game.get_node("Hud").get_node("%Menu")
	menu.show()
	menu.pressed.connect(pause_game)
	var home: Button = game.get_node("GameOver/Center/Panel/Box/Title")
	home.show()
	home.pressed.connect(return_to_title)
	_panel.hide()
	%Shade.hide()


func pause_game() -> void:
	if game == null or GameClock.ended:
		return
	get_tree().paused = true
	_display(false)
	%Resume.grab_focus()


func resume_game() -> void:
	if game == null or GameClock.ended:
		return
	_panel.hide()
	%Shade.hide()
	get_tree().paused = false


func return_to_title() -> void:
	if game != null:
		remove_child(game)
		game.queue_free()
		game = null
	show_title()


func _display(title: bool) -> void:
	_confirming = false
	_panel.show()
	%Shade.show()
	%Shade.color = Color(0.03, 0.05, 0.045, 0.0 if title else 0.66)
	%Wordmark.visible = title
	%MapLabel.visible = title
	%Heading.visible = not title
	%Heading.text = "Settlement paused"
	%Continue.visible = title and SaveManager.latest_slot() >= 0
	%Start.theme_type_variation = &"Quiet" if %Continue.visible else &"Primary"
	%Footer.show()
	%Map.visible = title
	%Description.visible = title
	%Start.visible = title
	%Quit.visible = title
	%Return.visible = not title
	%Resume.visible = not title
	%Confirm.hide()
	%Back.hide()
	%Options.show()
	%Saves.show()


func _describe(index: int) -> void:
	%Description.text = MAPS[index].description


func _open_slots() -> void:
	_panel.hide()
	_slots.open(game)


func _close_slots() -> void:
	_panel.show()
	%Saves.grab_focus()


func _load_slot(slot: int) -> void:
	var data := SaveManager.read_slot(slot)
	if data.is_empty():
		_slots.report(SaveManager.message)
		return
	var from_title := game == null
	if from_title:
		start_game()
	if not game.restore_game(data):
		if from_title:
			return_to_title()
		_panel.hide()
		_slots.show()
		_slots.report("This settlement contains invalid data.")
		return
	_slots.hide()
	resume_game()


func _open_settings() -> void:
	if game == null:
		_preview = (load(STATION_PREVIEW) as PackedScene).instantiate()
		add_child(_preview)
		(_preview.get_node("Camera") as Camera3D).look_at(Vector3(-1.4, 2.6, 2.4))
		%KeyArt.hide()
	_panel.hide()
	_settings.open()


func _close_settings() -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null
		%KeyArt.show()
	_panel.show()
	%Options.grab_focus()


func _ask_return() -> void:
	_confirming = true
	%Heading.text = "Leave this settlement?"
	%Description.text = "Leaving ends this session."
	%Description.show()
	%Return.hide()
	%Resume.hide()
	%Confirm.show()
	%Back.show()
	%Footer.hide()
	%Saves.hide()
	%Back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _slots.visible and event.is_action_pressed("ui_cancel"):
		_slots.close()
		get_viewport().set_input_as_handled()
		return
	if (
		_settings.visible
		or not event.is_action_pressed("ui_cancel")
		or game == null
		or GameClock.ended
	):
		return
	if _confirming:
		pause_game()
	elif _panel.visible:
		resume_game()
	else:
		pause_game()
	get_viewport().set_input_as_handled()
