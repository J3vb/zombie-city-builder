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
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = gradient
	var centre := world.command_post.position
	for i in LIGHTS:
		var light := PointLight2D.new()
		light.texture = tex
		light.energy = 1.2
		light.color = Color(1.0, 0.85, 0.6)
		light.position = centre + Vector2.RIGHT.rotated(TAU * i / LIGHTS) * (200 + 40 * (i % 5))
		world.add_child(light)
