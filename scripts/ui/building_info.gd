extends PanelContainer
## Live details for the building under inspection.

var _site: Building
var _jobs: JobBoard
var _feedback := ""


func _ready() -> void:
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
	var levels := building.def.levels
	var title := building.def.display_name
	var level_text := "Level %d of %d" % [building.level, maxi(1, levels.size())]
	if not levels.is_empty():
		title = levels[building.level - 1].title
		level_text = "%s   ·   %s" % [building.def.display_name, level_text]
	elif building == grower.world.command_post:
		level_text = "Station 4   ·   " + level_text
	%Category.text = level_text
	%Title.text = title
	%Health.text = "Health   %d / %d" % [building.health, building.max_health()]
	%HealthBar.max_value = building.max_health()
	%HealthBar.value = building.health
	var next := building.next_level()
	%Next.visible = next != null
	%Cost.visible = next != null
	%Status.visible = not levels.is_empty()
	if next != null:
		%Next.text = "Next upgrade   %s" % next.title
		%Cost.text = "From day %d   ·   %s" % [next.min_day, BuildingDef.format_cost(next.cost)]
	%Status.text = "Fully upgraded" if next == null else grower.upgrade_status(building)
	_refresh_staff(building)


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
