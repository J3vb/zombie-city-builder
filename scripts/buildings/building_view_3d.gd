extends Node3D
## Places a placeholder model and its damage label at the simulation footprint.

@onready var building := get_parent() as Building
@onready var label: Label3D = $Label


func _ready() -> void:
	if building.def == null:
		return
	var world := building.get_parent().get_parent() as World
	position = world.to_view(building.sim_center())
	var size := building.sim_bounds().size * world.map_def.view_scale
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x - 0.3, building.def.view_height, size.y - 0.3)
	var material := StandardMaterial3D.new()
	material.albedo_color = building.def.color
	mesh.material = material
	var body: MeshInstance3D = $Body
	body.mesh = mesh
	body.position.y = mesh.size.y / 2.0
	label.position.y = mesh.size.y + 0.9
	building.health_changed.connect(_show_health)
	_show_health()


func _show_health() -> void:
	label.text = building.def.display_name
	if building.health < building.def.max_health:
		label.text += "\n%d / %d" % [building.health, building.def.max_health]
