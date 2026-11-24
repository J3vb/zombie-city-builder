class_name GameOverScreen
extends CanvasLayer
## Shown when the Command Post falls.

signal new_game_pressed

@onready var _label: Label = %Message


func _ready() -> void:
	hide()
	%NewGame.pressed.connect(func() -> void: new_game_pressed.emit())


func show_result(day: int, no_survivors: bool = false) -> void:
	var reason := "The last resident has died." if no_survivors else "The Command Post has fallen."
	_label.text = "%s\nYou held out until day %d." % [reason, day]
	show()
