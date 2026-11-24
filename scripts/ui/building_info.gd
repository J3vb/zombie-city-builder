extends PanelContainer
## Live details for the building under inspection.


func refresh(building: Building, grower: TownGrower) -> void:
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
