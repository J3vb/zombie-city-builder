extends Node
## Manual test: 30 lights + 500 zombies at night. Watch the FPS (F3).

const MAIN := "res://scenes/main/main.tscn"
const LIGHTS := 30
const ZOMBIES := 500

var _main: Main


func _ready() -> void:
	_main = (load(MAIN) as PackedScene).instantiate() as Main
	add_child(_main)
	await get_tree().process_frame
	var world := _main.world
	GameClock.skip_to_night()
	world.debug_overlay.visible = true
	world.debug_overlay.get_node("Layer").visible = true
	world.horde.queue_spawn(ZOMBIES)
	var centre := world.to_view(world.command_post.sim_center())
	for i in LIGHTS:
		var light := OmniLight3D.new()
		light.light_energy = 1.2
		light.light_color = Color(1.0, 0.85, 0.6)
		light.omni_range = 12.0
		var offset := Vector3.RIGHT.rotated(Vector3.UP, TAU * i / LIGHTS) * (25 + 5 * (i % 5))
		light.position = centre + offset + Vector3.UP * 4
		world.add_child(light)
