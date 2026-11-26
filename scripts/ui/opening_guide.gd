class_name OpeningGuide
extends PanelContainer
## Guides the first three days using milestones reached in the live settlement.

const STEPS := [
	[
		"Day 1 · Connect Station 4",
		"Open Build and choose Straight under Streets. Click the gold marker, then the endpoint."
	],
	[
		"Day 1 · House the first workers",
		(
			"Choose Home plot beside the connected street. Reserve two plots so the "
			+ "first workers can move in."
		)
	],
	[
		"Day 1 · Take the first watch",
		(
			"Build a watchtower near Station 4 if you need one. Inspect it and use "
			+ "Manage worker to post a guard. Pack more ammo at Station 4."
		)
	],
	[
		"Day 2 · Grow food",
		(
			"Choose Garden and place it on its own patch of clear ground. Assign a "
			+ "daytime worker or leave hiring open."
		)
	],
	[
		"Day 2 · Supply water",
		(
			"Place a Well and staff it. Workers deliver finished shifts at dawn. "
			+ "Inspect a site to see what's blocking production."
		)
	],
	[
		"Day 2 · Build a gate",
		(
			"Open Defenses and place a gate on a street. Let the builder finish it, "
			+ "then inspect it to choose whether to close at dusk."
		)
	],
	[
		"Day 3 · Read the warning",
		(
			"Check the incoming edge at dusk. Move defenders back to their towers and "
			+ "pack enough rounds before nightfall."
		)
	],
	[
		"Day 3 · Hold until dawn",
		"Keep Station 4 and at least one resident alive through the third night."
	],
	[
		"Opening complete",
		"You held the first major horde. Open Expeditions to plan your first trip " + "out of town."
	]
]

var step := 0
var dismissed := false
var world: World
var _section := Label.new()
var _heading := Label.new()
var _steps: Array[ColorRect] = []
var _body := Label.new()
var _timer := 0.0


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	grow_horizontal = GROW_DIRECTION_BEGIN
	offset_left = -436
	offset_right = -18
	offset_top = 99
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 9)
	box.add_child(top)
	var flag := TextureRect.new()
	flag.texture = UiSymbols.icon(UiSymbols.FLAG)
	flag.custom_minimum_size = Vector2(21, 21)
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.size_flags_vertical = SIZE_SHRINK_CENTER
	flag.modulate = Color("#edb269")
	top.add_child(flag)
	_section.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_section.theme_type_variation = &"Caption"
	_section.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(_section)
	var close := Button.new()
	close.text = "Hide"
	close.flat = true
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(toggle)
	top.add_child(close)
	_heading.theme_type_variation = &"Heading"
	_heading.add_theme_font_size_override("font_size", 29)
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_heading)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(_body)
	var progress := HBoxContainer.new()
	box.add_child(progress)
	for i in STEPS.size() - 1:
		var mark := ColorRect.new()
		mark.custom_minimum_size.y = 4
		mark.size_flags_horizontal = SIZE_EXPAND_FILL
		mark.mouse_filter = MOUSE_FILTER_IGNORE
		progress.add_child(mark)
		_steps.append(mark)
	_refresh()


func bind(town: World) -> void:
	world = town
	step = 0
	dismissed = false
	show()
	_refresh()


func toggle() -> void:
	dismissed = not dismissed
	visible = not dismissed


func _process(dt: float) -> void:
	_timer -= dt
	if _timer <= 0.0 and is_instance_valid(world) and not GameClock.ended:
		_timer = 0.5
		advance()


func advance() -> void:
	while step < STEPS.size() - 1 and _achieved():
		step += 1
	_refresh()


func _achieved() -> bool:
	var done := false
	match step:
		0:
			for road: Street in world.roads.roads.values():
				if world.roads.reachable.has(road.line[0]):
					done = true
					break
		1:
			done = world.plots.plots.size() >= 2
		2:
			for member in world.safety.people:
				if member.on_watch():
					done = true
					break
		3, 4:
			var item: StringName = &"food" if step == 3 else &"water"
			for site in world.jobs.sites:
				if site.def.output_resource == item and world.jobs.worker_at(site) != null:
					done = true
					break
		5:
			for segment: BarrierSegment in world.grid.barriers.values():
				if segment.complete and segment.def.gate:
					done = true
					break
		6:
			done = world.horde.warning_day >= 3 and (world.horde.approach >= 0 or GameClock.day > 3)
		7:
			done = GameClock.day >= 4 and world.command_post.health > 0
	return done


func _refresh() -> void:
	var title: String = STEPS[step][0]
	var parts := title.split(" · ")
	_heading.text = parts[-1]
	_section.text = "OPENING GUIDE   %d / %d" % [mini(step + 1, _steps.size()), _steps.size()]
	if parts.size() > 1:
		_section.text = "%s   /   GOAL %d OF %d" % [parts[0].to_upper(), step + 1, _steps.size()]
	for i in _steps.size():
		_steps[i].color = Color("#edb269") if i <= step else Color("#49554e")
	_body.text = STEPS[step][1]
	if step == 0 and is_instance_valid(world) and not world.perimeter.towers.is_empty():
		_body.text = "Station 4 has a watchtower and barricades. " + _body.text
