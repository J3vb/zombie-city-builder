extends Node3D
## Manual test: is 3D fast enough? A walled town, street lights and a horde
## drawn with one MultiMesh. Keys: 1/2/3 = 500/1000/2000 zombies,
## F = shadows, L = street lights, N = day/night.

const MAP := 128
const WALL_HALF := 30
const ZOMBIE_SPEED := 2.2
const COUNTS: Array[int] = [500, 1000, 2000]

var _rng := RandomNumberGenerator.new()
var _count: int = 500
var _pos := PackedVector2Array()
var _buffer := PackedFloat32Array()
var _multimesh: MultiMesh
var _sun: DirectionalLight3D
var _env: Environment
var _lights: Array[OmniLight3D] = []
var _night := false
var _label: Label
var _update_ms: float = 0.0
var _mats: Dictionary[String, StandardMaterial3D] = {}


func _ready() -> void:
	_rng.seed = 1234
	_build_environment()
	_build_ground()
	_build_town()
	_build_zombies()
	_build_overlay()
	var rig := (load("res://scenes/tests/bench_camera_3d.tscn") as PackedScene).instantiate()
	add_child(rig)
	_set_count(500)


func _mat(hex: String) -> StandardMaterial3D:
	if not _mats.has(hex):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = 0.9
		_mats[hex] = m
	return _mats[hex]


func _add_mesh(mesh: Mesh, pos: Vector3, hex: String, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(hex)
	mi.position = pos
	mi.rotation.y = rot_y
	add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, hex: String) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add_mesh(m, pos + Vector3(0, size.y / 2.0, 0), hex)


func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.fog_enabled = true
	_env.fog_density = 0.0015
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50, -35, 0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 120.0
	add_child(_sun)
	_apply_time()


func _apply_time() -> void:
	var sky := Color("#2a3150") if _night else Color("#a9b4bc")
	_env.background_color = sky
	_env.fog_light_color = sky
	_env.ambient_light_color = Color("#5a6a9a") if _night else Color("#b8c0c8")
	_env.ambient_light_energy = 0.35 if _night else 0.4
	_sun.light_color = Color("#8fa0d8") if _night else Color("#fff0dc")
	_sun.light_energy = 0.25 if _night else 0.9
	for l in _lights:
		l.visible = _night


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP, MAP)
	_add_mesh(plane, Vector3.ZERO, "#4a5434")
	for axis in 2:
		var size := Vector3(MAP, 0.04, 4) if axis == 0 else Vector3(4, 0.04, MAP)
		_box(size, Vector3.ZERO, "#3d3d40")
	for i in 60:
		var p := Vector3(_rng.randf_range(-60, 60), 0, _rng.randf_range(-60, 60))
		if absf(p.x) < WALL_HALF + 3 and absf(p.z) < WALL_HALF + 3:
			continue
		_add_tree(p)


func _add_tree(p: Vector3) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.15
	trunk.bottom_radius = 0.2
	trunk.height = 1.6
	trunk.radial_segments = 6
	_add_mesh(trunk, p + Vector3(0, 0.8, 0), "#4a3626")
	var crown := SphereMesh.new()
	crown.radius = 1.1
	crown.height = 1.8
	crown.radial_segments = 8
	crown.rings = 4
	_add_mesh(crown, p + Vector3(0, 2.2, 0), "#4b5a32")


func _build_town() -> void:
	for x in range(-WALL_HALF + 4, WALL_HALF - 3, 6):
		for z in range(-WALL_HALF + 4, WALL_HALF - 3, 6):
			if absi(x) < 4 or absi(z) < 4:
				continue
			if absi(x) < 9 and absi(z) < 9:
				continue
			_add_house(Vector3(x, 0, z), _rng.randi_range(1, 3))
	_box(Vector3(8, 4, 8), Vector3(6.5, 0, 6.5), "#6f746c")
	_box(Vector3(4, 2.5, 4), Vector3(6.5, 4, 6.5), "#7c8278")
	_build_walls()
	for i in 30:
		var a := TAU * i / 30.0
		var p := Vector3(cos(a), 0, sin(a)) * (12.0 + 10.0 * (i % 2))
		_box(Vector3(0.15, 3, 0.15), p, "#2a2a2a")
		var light := OmniLight3D.new()
		light.position = p + Vector3(0, 3.2, 0)
		light.light_color = Color("#ffc070")
		light.omni_range = 9.0
		light.light_energy = 1.6
		light.visible = false
		add_child(light)
		_lights.append(light)


func _add_house(p: Vector3, level: int) -> void:
	var colors: Array[String] = ["#a89474", "#8a7058", "#b0a08c"]
	var heights: Array[float] = [1.4, 2.4, 4.4]
	var h := heights[level - 1]
	_box(Vector3(4, h, 3.4), p, colors[level - 1])
	var roof := PrismMesh.new()
	roof.size = Vector3(4.2, 1.4, 3.6)
	var mi := _add_mesh(roof, p + Vector3(0, h + 0.7, 0), "#8e3e30" if level == 3 else "#5d6168")
	mi.rotation.y = PI / 2.0 if _rng.randf() < 0.5 else 0.0


func _build_walls() -> void:
	var w := WALL_HALF
	for side in 4:
		for i in range(-w, w + 1, 2):
			if absi(i) <= 2:
				continue
			var p := Vector3(i, 0, w) if side == 0 else Vector3(i, 0, -w)
			if side >= 2:
				p = Vector3(w if side == 2 else -w, 0, i)
			_box(Vector3(2.0, 2.4, 0.5) if side < 2 else Vector3(0.5, 2.4, 2.0), p, "#7a6450")


func _build_zombies() -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.6
	capsule.radial_segments = 6
	capsule.rings = 2
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	capsule.material = mat
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = capsule
	_multimesh.instance_count = COUNTS[-1]
	_multimesh.custom_aabb = AABB(Vector3(-MAP, -1, -MAP), Vector3(MAP * 2, 4, MAP * 2))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _multimesh
	add_child(mmi)
	_pos.resize(COUNTS[-1])
	_buffer.resize(COUNTS[-1] * 16)
	for i in COUNTS[-1]:
		_pos[i] = _edge_spawn()


func _edge_spawn() -> Vector2:
	var a := _rng.randf() * TAU
	return Vector2(cos(a), sin(a)) * _rng.randf_range(45.0, 62.0)


func _set_count(n: int) -> void:
	_count = n
	_multimesh.visible_instance_count = n


func _process(delta: float) -> void:
	var start := Time.get_ticks_usec()
	for i in _count:
		var p := _pos[i]
		var to_centre := -p
		var d := to_centre.length()
		var stop := WALL_HALF + 1.0
		if d > stop:
			p += to_centre / d * ZOMBIE_SPEED * delta
			p += Vector2(sin(i * 1.7 + p.x), cos(i * 2.3 + p.y)) * 0.6 * delta
		else:
			p = _edge_spawn()
		_pos[i] = p
		var o := i * 16
		var c := 0.25 * sin(i * 0.37)
		_buffer[o] = 1.0
		_buffer[o + 1] = 0.0
		_buffer[o + 2] = 0.0
		_buffer[o + 3] = p.x
		_buffer[o + 4] = 0.0
		_buffer[o + 5] = 1.0
		_buffer[o + 6] = 0.0
		_buffer[o + 7] = 0.8
		_buffer[o + 8] = 0.0
		_buffer[o + 9] = 0.0
		_buffer[o + 10] = 1.0
		_buffer[o + 11] = p.y
		_buffer[o + 12] = 0.3 + c * 0.15
		_buffer[o + 13] = 0.36 + c * 0.15
		_buffer[o + 14] = 0.26
		_buffer[o + 15] = 1.0
	RenderingServer.multimesh_set_buffer(_multimesh.get_rid(), _buffer)
	_update_ms = (Time.get_ticks_usec() - start) / 1000.0
	_label.text = (
		(
			"FPS %d   zombies %d   zombie update %.2f ms\n%s\n"
			% [Engine.get_frames_per_second(), _count, _update_ms, _status()]
		)
		+ "1/2/3 zombies  F shadows  L lights  N night  WASD pan  Q/E rotate  wheel zoom"
	)


func _status() -> String:
	return (
		"shadows %s   night %s   renderer %s"
		% [
			"on" if _sun.shadow_enabled else "off",
			"on" if _night else "off",
			RenderingServer.get_current_rendering_method(),
		]
	)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_1:
			_set_count(COUNTS[0])
		KEY_2:
			_set_count(COUNTS[1])
		KEY_3:
			_set_count(COUNTS[2])
		KEY_F:
			_sun.shadow_enabled = not _sun.shadow_enabled
		KEY_L, KEY_N:
			_night = not _night
			_apply_time()


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	_label = Label.new()
	panel.add_child(_label)
