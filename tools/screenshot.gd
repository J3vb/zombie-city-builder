extends SceneTree
## Runs the main scene for a few frames and saves a screenshot.
## Needs a display (use xvfb-run on Linux):
##   godot --script res://tools/screenshot.gd -- <out.png> [frames]

const MAIN_PATH := "res://scenes/main/main.tscn"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://screenshot.png"
	var frames: int = int(args[1]) if args.size() > 1 else 30
	await process_frame
	root.add_child((load(MAIN_PATH) as PackedScene).instantiate())
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
