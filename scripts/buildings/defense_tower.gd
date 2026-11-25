class_name DefenseTower
extends Building
## Fires only from a completed, attended post. Targets exist for one crowd update.

var shots := 0
var _cooldown := 0.0
var _flash := 0.0
var _trace := MeshInstance3D.new()
var _near := PackedInt32Array()


func _ready() -> void:
	var beam := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.81, 0.36)
	beam.material = mat
	_trace.mesh = beam
	add_child(_trace)
	_trace.hide()


func fire_tick(world: World, dt: float) -> void:
	_cooldown = maxf(0, _cooldown - dt)
	_flash -= dt
	if _flash <= 0:
		_trace.hide()
	var guard := world.jobs.worker_at(self)
	var rules := def as TowerDef
	if (
		_cooldown > 0
		or guard == null
		or not guard.on_watch()
		or Economy.get_amount(&"ammo") < rules.ammo_per_shot
	):
		return
	var origin := sim_center()
	var reach := world.grid.tile_size * rules.range_tiles
	var count := world.zombies.query(origin, reach, _near)
	var nearest := -1
	var distance := INF
	for n in count:
		var i := _near[n]
		var d := origin.distance_squared_to(world.zombies.position_of(i))
		if world.zombies.is_alive(i) and d < distance:
			nearest = i
			distance = d
	if nearest < 0:
		return
	var end := world.to_view(world.zombies.position_of(nearest)) + Vector3.UP
	Economy.add(&"ammo", -rules.ammo_per_shot)
	world.zombies.weapon_hit(nearest, rules.damage, rules.ammo_per_shot > 0)
	if rules.noise_tiles > 0.0:
		world.horde.gunshot()
		AudioManager.effect("shot")
	world.zombies.alert(origin, rules.noise_tiles * world.grid.tile_size)
	shots += 1
	_cooldown = rules.shot_interval
	_flash = 0.1
	var start := world.to_view(origin) + Vector3.UP * def.view_height * 0.8
	var direction := end - start
	_trace.transform = Transform3D(
		(
			Basis.looking_at(
				direction, Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.RIGHT
			)
			* Basis.from_scale(Vector3(0.07, 0.07, direction.length()))
		),
		(start + end) * 0.5
	)
	_trace.show()


func duty_status(worker: Resident) -> String:
	if worker == null:
		return "Needs a defender"
	if not worker.on_watch():
		return "Waiting for defender to arrive"
	if Economy.get_amount(&"ammo") < (def as TowerDef).ammo_per_shot:
		return "Out of ammo · restock at Station 4"
	return "On watch"
