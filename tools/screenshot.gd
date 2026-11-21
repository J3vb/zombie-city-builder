extends SceneTree
## Runs the main scene for a few frames and saves a screenshot.
## Needs a display (use xvfb-run on Linux):
##   godot --script res://tools/screenshot.gd -- <out.png> [frames] [scene] [night]
## With "night", skips to night first so a horde spawns.

const MAIN_PATH := "res://scenes/main/main.tscn"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://screenshot.png"
	var frames: int = int(args[1]) if args.size() > 1 else 30
	var scene_path: String = args[2] if args.size() > 2 else MAIN_PATH
	await process_frame
	root.add_child((load(scene_path) as PackedScene).instantiate())
	if args.size() > 3 and args[3] == "night":
		await process_frame
		root.get_node("GameClock").call("skip_to_night")
		root.get_node("GameClock").call("set_speed", 3)
	for i in frames:
		await process_frame
	var stats := root.find_children("ZombieManager", "", true, false)
	if not stats.is_empty():
		print("zombies: ", stats[0].call("count"), "  update ms: ", stats[0].get("last_update_ms"))
	print("fps: ", Engine.get_frames_per_second())
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
