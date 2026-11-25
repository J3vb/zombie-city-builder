extends PanelContainer
## Unlock technologies, repair the radio tower and call for rescue.

var world: World
var _buttons: Array[Button] = []
var _radio_def: BuildingDef


func _ready() -> void:
	_radio_def = load("res://data/buildings/radio_tower.tres") as BuildingDef
	%Close.pressed.connect(hide)
	%Radio.pressed.connect(_radio)
	%Endless.pressed.connect(_endless)
	for tech in Campaign.TECHS:
		var button := Button.new()
		button.pressed.connect(_learn.bind(tech))
		%Techs.add_child(button)
		_buttons.append(button)
		var benefit := Label.new()
		benefit.text = tech.benefit
		%Techs.add_child(benefit)


func open(town: World) -> void:
	world = town
	%Feedback.text = ""
	show()
	refresh()


func refresh() -> void:
	if not visible or world == null:
		return
	var campaign := world.campaign
	%Stock.text = (
		"Blueprints %d · Scrap %d · Radio parts %d"
		% [
			Economy.get_amount(&"blueprints"),
			Economy.get_amount(&"scrap"),
			Economy.get_amount(&"radio_parts")
		]
	)
	for i in Campaign.TECHS.size():
		var tech := Campaign.TECHS[i]
		var reason := campaign.blocker(tech)
		_buttons[i].text = (
			"%s · %s"
			% [tech.title, BuildingDef.format_cost(tech.cost) if reason.is_empty() else reason]
		)
		_buttons[i].disabled = not reason.is_empty()
	%Radio.visible = campaign.has_tech(&"reclaim") and not campaign.won and not campaign.endless
	%Radio.text = (
		"Call Haven Point"
		if campaign.radio(world) != null
		else "Build radio tower · " + BuildingDef.format_cost(_radio_def.cost)
	)
	%Endless.visible = not campaign.endless
	if campaign.won:
		%Status.text = "Haven Point answers. Halder Ford is on tonight's Tally."
	elif campaign.endless:
		%Status.text = "Endless settlement · keep the town alive."
	else:
		%Status.text = "Find blueprints on expeditions. Recover radio parts at the Relay Station."


func _learn(tech: TechDef) -> void:
	world.campaign.research(tech)
	refresh()


func _radio() -> void:
	if world.campaign.radio(world) == null:
		world.build_tool.select(_radio_def)
		hide()
	else:
		world.campaign.transmit(world)
		refresh()


func _endless() -> void:
	world.campaign.play_endless()
	refresh()
