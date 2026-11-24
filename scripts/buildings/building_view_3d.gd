extends Node3D
## Orients a home toward its road and updates the model and health label on upgrades.

const FRAME := preload("res://scenes/models/construction_frame.tscn")

var _frame: Node3D
var _model: Node3D
var _door: MeshInstance3D

@onready var building := get_parent() as Building
@onready var label: Label3D = $Label
@onready var body: MeshInstance3D = $Body


func _ready() -> void:
	if building.def == null:
		return
	building.construction_changed.connect(_show_level)
	building.health_changed.connect(_show_health)
	_show_level()


func _show_level() -> void:
	var world := building.get_parent().get_parent() as World
	position = world.to_view(building.sim_center())
	var size := Vector2(building.def.size) * world.view_tile()
	var height := building.def.view_height
	var color := building.def.color
	var stage: BuildingLevelDef
	if building.plot != null:
		rotation.y = atan2(building.plot.front.x, building.plot.front.y)
	if not building.def.levels.is_empty():
		stage = building.def.levels[building.level - 1]
		height = stage.height
		color = stage.color
	if _frame != null:
		_frame.hide()
		_frame.queue_free()
		_frame = null
	if building.target_level != 0:
		_frame = FRAME.instantiate() as Node3D
		add_child(_frame)
		_frame.scale = Vector3(size.x, building.pick_height(), size.y)
	if _model != null:
		_model.hide()
		_model.queue_free()
		_model = null
	var model_scene := building.def.model
	if (
		stage != null
		and not stage.model_path.is_empty()
		and ResourceLoader.exists(stage.model_path, "PackedScene")
	):
		model_scene = load(stage.model_path) as PackedScene
	if model_scene != null and building.target_level != 1:
		_model = model_scene.instantiate() as Node3D
		add_child(_model)
	body.visible = _model == null and building.target_level != 1
	if body.visible:
		var form: PrimitiveMesh
		var dimensions := Vector3(size.x - 0.3, height, size.y - 0.3)
		if building.def.id == &"house" and building.level == 1:
			var tent := PrismMesh.new()
			tent.size = dimensions
			form = tent
		else:
			var box := BoxMesh.new()
			box.size = dimensions
			form = box
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		form.material = material
		body.mesh = form
		body.position.y = height * 0.5
		if building.plot != null and _door == null:
			_door = MeshInstance3D.new()
			var panel := BoxMesh.new()
			panel.size = Vector3(1.2, 1.45, 0.16)
			var paint := StandardMaterial3D.new()
			paint.albedo_color = Color("#2f514c")
			panel.material = paint
			_door.mesh = panel
			add_child(_door)
			_door.position = Vector3(0, 0.725, dimensions.z * 0.5)
	if _door != null:
		_door.visible = body.visible
	label.position.y = building.pick_height() + 0.9
	_show_health()


func _show_health() -> void:
	label.text = (
		building.def.display_name
		if building.def.levels.is_empty()
		else building.def.levels[building.level - 1].title
	)
	if building.target_level != 0:
		label.text = "%s · construction" % building.project_name()
	if building.health < building.max_health():
		label.text += "\n%d / %d" % [building.health, building.max_health()]
