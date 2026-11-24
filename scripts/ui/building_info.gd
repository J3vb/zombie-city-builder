extends PanelContainer
## Live details for the building under inspection.

var _site: Building
var _jobs: JobBoard
var _feedback := ""


func _ready() -> void:
	%CancelProject.pressed.connect(_cancel_project)
	%Assignment.about_to_popup.connect(_populate_workers)
	%Assignment.get_popup().id_pressed.connect(_choose_worker)


func reset() -> void:
	%Assignment.get_popup().hide()
	_site = null
	_jobs = null
	_feedback = ""
	hide()


func refresh(building: Building, grower: TownGrower) -> void:
	if building != _site:
		%Assignment.get_popup().hide()
		_feedback = ""
	_site = building
	_jobs = grower.world.jobs
	visible = is_instance_valid(building) and not building.is_queued_for_deletion()
	if not visible:
		return
	var building_work := building.target_level != 0
	%CancelProject.visible = building_work
	%Project.visible = building_work
	if building_work:
		var refund := building.unused_materials()
		var recovered := "none" if refund.is_empty() else BuildingDef.format_cost(refund)
		%Project.text = (
			"%s · %d%%\n%s"
			% [
				building.project_name(),
				floori(building.work_done * 100 / building.required_work()),
				grower.world.construction.status(building)
			]
		)
		%CancelProject.text = "Cancel build" if building.target_level == 1 else "Cancel upgrade"
		%CancelProject.tooltip_text = "Returns unused materials: %s" % recovered
	var levels := building.def.levels
	var title := building.def.display_name
	var level_text := "Level %d of %d" % [building.level, maxi(1, levels.size())]
	if not levels.is_empty():
		title = levels[building.level - 1].title
		level_text = "%s   ·   %s" % [building.def.display_name, level_text]
	elif building == grower.world.command_post:
		level_text = "Station 4   ·   " + level_text
	%Category.text = "Construction site" if building.target_level == 1 else level_text
	%Title.text = title
	%Health.text = "Health   %d / %d" % [building.health, building.max_health()]
	%HealthBar.max_value = building.max_health()
	%HealthBar.value = building.health
	var next := building.next_level()
	%Next.visible = next != null and not building_work
	%Cost.visible = next != null and not building_work
	%Status.visible = not levels.is_empty() and not building_work
	if next != null:
		%Next.text = "Next upgrade   %s" % next.title
		%Cost.text = "From day %d   ·   %s" % [next.min_day, BuildingDef.format_cost(next.cost)]
	%Status.text = "Fully upgraded" if next == null else grower.upgrade_status(building)
	if building.target_level == 1:
		%Staff.hide()
		%Assignment.hide()
	elif building.storage_capacity() > 0:
		%Assignment.hide()
		%Staff.show()
		%Staff.text = (
			"Storage   +%d per resource\nTown limit   %d per resource"
			% [building.storage_capacity(), Economy.capacity]
		)
	elif building == grower.world.command_post:
		var crew := grower.world.construction
		%Assignment.hide()
		%Staff.show()
		var task := crew.target.project_name() if crew.target != null else "Station 4"
		%Staff.text = (
			"Builder   %s\n%s · %s" % [crew.builder.display_name, crew.builder.activity(), task]
		)
		if crew.builder.work_pace() < 1.0:
			%Staff.text += (
				"\nRation shortage · work pace %d%%" % roundi(crew.builder.work_pace() * 100)
			)
	else:
		_refresh_staff(building)


func _cancel_project() -> void:
	if is_instance_valid(_site):
		_site.cancel_construction()


func _refresh_staff(building: Building) -> void:
	var productive := building.shift_output() > 0
	%Assignment.visible = productive
	%Staff.visible = productive or building.plot != null
	if not %Staff.visible:
		return
	var resident := _jobs.worker_at(building) if productive else _jobs.tenant(building)
	var lines := PackedStringArray()
	if productive:
		lines.append("Per shift   %d %s" % [building.shift_output(), building.def.output_resource])
	if resident == null:
		if productive:
			lines.append(
				(
					"Hiring paused"
					if _jobs.hiring_closed(building)
					else "Waiting for a reachable worker"
				)
			)
		else:
			lines.append("Vacant home")
	else:
		lines.append("%s   ·   %s" % [resident.display_name, resident.activity()])
		if resident.worked_day == GameClock.day:
			lines.append("Shift complete · pays at dawn")
		elif resident.state == Resident.State.WORKING:
			lines.append(
				"Shift   %d%%" % int(100.0 * resident.shift_seconds / _jobs.rules.shift_seconds)
			)
		if resident.work_pace() < 1.0:
			lines.append("Work pace   %d%%" % roundi(resident.work_pace() * 100))
		if resident.hungry:
			lines.append("Missed food at dawn")
		if resident.thirsty:
			lines.append("Missed water at dawn")
	if not _feedback.is_empty():
		lines.append(_feedback)
	%Staff.text = "\n".join(lines)


func _populate_workers() -> void:
	var menu := %Assignment.get_popup() as PopupMenu
	menu.clear()
	if not is_instance_valid(_site) or not _jobs.sites.has(_site):
		return
	menu.add_item("Resume hiring" if _jobs.hiring_closed(_site) else "Pause hiring", 0)
	menu.add_separator()
	for resident in _jobs.residents:
		var job := resident.job.def.display_name if resident.job != null else "Available"
		menu.add_item("%s · %s" % [resident.display_name, job], resident.resident_id)


func _choose_worker(id: int) -> void:
	if not is_instance_valid(_site) or not _jobs.sites.has(_site):
		return
	_feedback = ""
	if id == 0:
		_jobs.toggle_hiring(_site)
		return
	for resident in _jobs.residents:
		if resident.resident_id == id:
			if not _jobs.assign(resident, _site):
				_feedback = "%s needs a home and a clear route." % resident.display_name
			return
