class_name SaveSlots
extends PanelContainer
## Manual saves occupy three named slots. Dawn autosave is read-only from the menu.

signal closed
signal load_requested(slot: int)

var _game: Main
var _rows := VBoxContainer.new()
var _feedback := Label.new()
var _overwrite := -1


func _ready() -> void:
	custom_minimum_size.x = 480
	add_child(_rows)
	_rows.add_child(_feedback)
	hide()


func open(game: Main) -> void:
	_game = game
	_overwrite = -1
	_feedback.text = ""
	_draw()
	show()


func _draw() -> void:
	if _feedback.get_parent() != null:
		_rows.remove_child(_feedback)
	for node in _rows.get_children():
		_rows.remove_child(node)
		node.queue_free()
	var heading := Label.new()
	heading.text = "Saved settlements"
	heading.add_theme_font_size_override("font_size", 32)
	_rows.add_child(heading)
	for slot in range(4):
		var row := HBoxContainer.new()
		_rows.add_child(row)
		var available := SaveManager.occupied(slot)
		var label := Label.new()
		label.text = "Dawn autosave" if slot == 0 else "Settlement %d" % slot
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(label)
		if _game != null and slot != 0 and not GameClock.ended:
			var save := Button.new()
			save.text = "Replace?" if _overwrite == slot else "Save"
			save.pressed.connect(_save.bind(slot))
			row.add_child(save)
		var read := Button.new()
		read.text = "Load" if available else "Empty"
		read.disabled = not available
		read.pressed.connect(_load.bind(slot))
		row.add_child(read)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(_feedback)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	_rows.add_child(back)
	back.grab_focus()


func _save(slot: int) -> void:
	if SaveManager.occupied(slot) and _overwrite != slot:
		_overwrite = slot
		_feedback.text = "Press Replace to overwrite this settlement."
	else:
		SaveManager.write_slot(_game, slot)
		_feedback.text = SaveManager.message
		_overwrite = -1
	_draw()


func _load(slot: int) -> void:
	if _game != null and _overwrite != -slot - 2:
		_overwrite = -slot - 2
		_feedback.text = "Press Load again to replace the current settlement."
		return
	_overwrite = -1
	load_requested.emit(slot)


func report(text: String) -> void:
	_feedback.text = text


func close() -> void:
	hide()
	closed.emit()
