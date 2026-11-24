class_name PlotTool
extends Node3D
## Places residential parcels, paints work zones and handles explicit removal tools.

enum Mode { NONE, HOME, ZONE, UNZONE, DEMOLISH, REMOVE_PLOT, REMOVE_ROAD }

var selected_building: Building
var mode := Mode.NONE
var hint := ""
var zone: BuildingDef
var world: World

var _view := PlotOverlay.new()
var _drag := BuildTool.NO_CELL
var _last := Vector2.INF


func setup(owner_world: World) -> void:
	world = owner_world
	add_child(_view)
	_view.setup(world)
	world.plots.changed.connect(_invalidate)
	world.roads.changed.connect(_invalidate)
	world.grid.changed.connect(_invalidate)
	EventBus.building_destroyed.connect(_building_destroyed)


func _invalidate() -> void:
	_last = Vector2.INF


func select(next: Mode, zone_def: BuildingDef = null) -> void:
	clear()
	world.road_tool.clear()
	world.build_tool.clear()
	mode = next
	zone = zone_def
	match mode:
		Mode.HOME:
			hint = "Click beside a connected street to reserve a home and backyard."
		Mode.ZONE:
			hint = "Drag over land to paint a %s zone." % zone.display_name
		Mode.UNZONE:
			hint = "Drag to erase zoning. Existing buildings stay."
		Mode.DEMOLISH:
			hint = "Click a building to demolish it for a partial refund."
		Mode.REMOVE_PLOT:
			hint = "Click an empty plot to release the land."
		Mode.REMOVE_ROAD:
			hint = "Click a street to remove it."


func _building_destroyed(building: Building) -> void:
	if building == selected_building:
		_select_building(null)


func _select_building(building: Building) -> void:
	if (
		is_instance_valid(selected_building)
		and selected_building.tree_exiting.is_connected(_selection_exiting)
	):
		selected_building.tree_exiting.disconnect(_selection_exiting)
	selected_building = building
	if building != null:
		building.tree_exiting.connect(_selection_exiting, CONNECT_ONE_SHOT)


func _selection_exiting() -> void:
	selected_building = null


func clear() -> void:
	_select_building(null)
	mode = Mode.NONE
	_drag = BuildTool.NO_CELL
	_last = Vector2.INF
	hint = ""
	_view.clear_preview()


func _area(end: Vector2i) -> Rect2i:
	var start := _drag.min(end)
	return Rect2i(start, _drag.max(end) - start + Vector2i.ONE)


func _process(_delta: float) -> void:
	if mode != Mode.HOME and _drag == BuildTool.NO_CELL:
		return
	var screen := world.get_viewport().get_mouse_position()
	var hit: Variant = world.camera.ground_at(screen)
	if hit == null or not world.get_viewport().get_visible_rect().has_point(screen):
		_view.clear_preview()
		_last = Vector2.INF
		return
	var point := world.to_sim(hit)
	if _last.is_equal_approx(point):
		return
	_last = point
	if mode == Mode.HOME:
		var plot := world.plots.preview(
			point, world.plots.rules.plot_frontage, world.plots.rules.plot_depth
		)
		_view.show_plot(plot)
		hint = (
			"Click to reserve. Gold marks the door, green marks the backyard."
			if plot.error.is_empty()
			else plot.error
		)
	elif _drag != BuildTool.NO_CELL:
		_view.show_area(_area(world.grid.world_to_cell(point)))


func _input(event: InputEvent) -> void:
	if (
		_drag == BuildTool.NO_CELL
		or not event.is_action_released("place")
		or not event is InputEventMouseButton
	):
		return
	var end := world.build_tool.cell_at_screen(event.position)
	if end != BuildTool.NO_CELL:
		world.grower.paint(_area(end), zone)
	_drag = BuildTool.NO_CELL
	_view.clear_preview()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if world.road_tool.active or world.build_tool.selected != null:
		return
	if mode == Mode.NONE:
		if event.is_action_pressed("place") and event is InputEventMouseButton:
			_select_building(_building_at_screen(event.position))
		elif selected_building != null and event.is_action_pressed("cancel"):
			_select_building(null)
		else:
			return
	elif event.is_action_pressed("cancel"):
		clear()
	elif event.is_action_pressed("place") and event is InputEventMouseButton:
		var hit: Variant = world.camera.ground_at(event.position)
		if hit != null:
			_click(world.to_sim(hit), event.position)
	else:
		return
	get_viewport().set_input_as_handled()


func _click(point: Vector2, screen: Vector2) -> void:
	match mode:
		Mode.HOME:
			var rules := world.plots.rules
			var plot := world.plots.reserve(point, rules.plot_frontage, rules.plot_depth)
			hint = (
				"Plot reserved. A tent can grow in daylight."
				if plot != null
				else world.plots.preview(point, rules.plot_frontage, rules.plot_depth).error
			)
		Mode.ZONE, Mode.UNZONE:
			var cell := world.grid.world_to_cell(point)
			if world.grid.in_bounds(cell):
				_drag = cell
				_invalidate()
		Mode.REMOVE_PLOT:
			var plot := world.plots.plot_at(point)
			hint = "Choose an empty plot."
			if plot != null:
				hint = (
					"Plot released."
					if world.plots.remove_plot(plot.id)
					else "Demolish the home before removing its plot."
				)
		Mode.REMOVE_ROAD:
			var hit := world.roads.nearest(point, world.roads.width * 0.6)
			hint = "Choose a street."
			if not hit.is_empty():
				hint = world.roads.removal_error(hit.road.id)
				if hint.is_empty() and world.roads.remove_road(hit.road.id):
					hint = "Street removed."
		Mode.DEMOLISH:
			var building := _building_at_screen(screen)
			if building == null or building == world.command_post:
				hint = "Choose a building other than Station 4."
			else:
				building.demolish()
				hint = "Building demolished. Its empty plot can be removed."


func _building_at_screen(screen: Vector2) -> Building:
	var camera := world.camera.lens
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var nearest: Building
	var distance := INF
	for building: Building in world.buildings.get_children():
		if building.is_queued_for_deletion():
			continue
		var view := building.get_node("View") as Node3D
		var base := Vector2(building.def.size) * world.view_tile()
		var height := (
			building.def.view_height
			if building.def.levels.is_empty()
			else building.def.levels[building.level - 1].height
		)
		var box := AABB(Vector3(-base.x * 0.5, 0, -base.y * 0.5), Vector3(base.x, height, base.y))
		var hit: Variant = box.intersects_ray(
			view.to_local(origin), view.global_basis.inverse() * dir
		)
		if hit != null:
			var d := origin.distance_squared_to(view.to_global(hit))
			if d < distance:
				distance = d
				nearest = building
	return nearest
