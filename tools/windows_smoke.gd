extends SceneTree
## Launch the packaged entry point and quit through the same audio shutdown used by the menu.


func _initialize() -> void:
	call_deferred("_play")


func _play() -> void:
	var scene := str(ProjectSettings.get_setting("application/run/main_scene"))
	if OS.get_cmdline_user_args().has("settlement"):
		scene = "res://scenes/main/main.tscn"
	if change_scene_to_file(scene) != OK:
		push_error("Could not launch the packaged scene: " + scene)
		quit(1)
		return
	for frame in 150:
		await process_frame
	root.get_node("AudioManager").quit_game()
