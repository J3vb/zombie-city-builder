class_name GameOverScreen
extends CanvasLayer
## Shown when the Command Post falls.

signal new_game_pressed

@onready var _label: Label = %Message


func _ready() -> void:
	hide()
	%NewGame.pressed.connect(func() -> void: new_game_pressed.emit())


func show_result(day: int) -> void:
	_label.text = "The Command Post has fallen.\nYou held out until day %d." % day
	show()
