extends WorldEnvironment
## Lights the town from the simulation clock, including after a pause or time skip.

@onready var sun: DirectionalLight3D = $Sun


func _ready() -> void:
	_process(0.0)


func _process(_delta: float) -> void:
	var time := GameClock.time_of_day
	var dark := smoothstep(0.62, 0.72, time) * (1.0 - smoothstep(0.94, 1.0, time))
	var sky := Color("#9baab3").lerp(Color("#242f48"), dark)
	environment.background_color = sky
	environment.fog_light_color = sky
	environment.ambient_light_color = Color("#d0d2c7").lerp(Color("#a8b9df"), dark)
	environment.ambient_light_energy = lerpf(0.65, 0.42, dark)
	sun.light_color = Color("#ffe6bd").lerp(Color("#aec9ff"), dark)
	sun.light_energy = lerpf(1.05, 0.38, dark)
	sun.rotation_degrees = Vector3(-35 - 25 * sin(time * TAU), -45 + time * 180, 0)
