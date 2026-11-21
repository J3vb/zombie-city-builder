class_name CommandPost
extends Building
## The town hall. Losing it ends the game.


func _on_destroyed() -> void:
	EventBus.game_over.emit(GameClock.day)
