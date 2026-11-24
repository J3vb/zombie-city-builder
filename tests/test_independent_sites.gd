extends TestCase

const GARDEN := preload("res://data/buildings/garden.tres")
const WORKSHOP := preload("res://data/buildings/scrap_workshop.tres")
const FARM := preload("res://data/buildings/farm.tres")
const MAIN := preload("res://scenes/main/main.tscn")


func test_garden_and_workshop_can_be_built_before_any_home() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var before := Economy.stock.duplicate()
	var start := Vector2i(20, 20)
	w.build_tool.select(GARDEN)
	assert_true(w.build_tool.place(start))
	assert_true(w.build_tool.place(start + Vector2i.RIGHT))
	assert_true(not w.build_tool.place(start), "two sites cannot share a cell")
	w.build_tool.select(WORKSHOP)
	assert_true(not w.build_tool.place(start + Vector2i.LEFT), "whole workshop footprint checked")
	var anchor := start + Vector2i(3, 0)
	assert_true(w.build_tool.place(anchor))
	var site := w.grid.building_at(anchor)
	assert_eq(site.plot, null)
	assert_eq(site.cells.size(), 4)
	assert_eq(w.grid.building_at(anchor + Vector2i.ONE), site)
	assert_eq(
		Economy.get_amount(&"wood"),
		before[&"wood"] - 2 * GARDEN.cost[&"wood"] - WORKSHOP.cost[&"wood"]
	)
	assert_eq(Economy.get_amount(&"scrap"), before[&"scrap"] - WORKSHOP.cost[&"scrap"])
	assert_true(not w.build_tool.place(Vector2i(10, 90)), "water rejects placement")
	var no_stock: Dictionary[StringName, int] = {}
	Economy.reset(no_stock)
	assert_true(not w.build_tool.place(anchor + Vector2i(5, 0)), "unaffordable placement")
	assert_eq(w.grid.building_at(anchor + Vector2i(5, 0)), null)
	site.demolish()
	assert_true(w.grid.is_free(site.cells))
	assert_eq(w.grid.building_at(start).def, GARDEN)
	fx.destroy()


func test_ground_behind_home_can_be_owned_and_removed_independently() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var start := w.roads.entrance
	var road := w.roads.add_road(PackedVector2Array([start, start + Vector2(0, 420)]))
	var cursor := road.line[road.line.size() / 2] + Vector2.RIGHT * 10
	var plot := w.plots.reserve(cursor, w.plots.rules.plot_frontage)
	assert_true(plot != null)
	var back_wall := plot.center - plot.front * w.grid.tile_size
	var garden_cell := w.grid.world_to_cell(back_wall - plot.front * w.grid.tile_size)
	assert_true(not plot.cells.has(garden_cell), "one tile behind the house is free")
	assert_eq(w.try_place_building(GARDEN, plot.door), null, "entrance remains reserved")
	assert_eq(
		w.try_place_building(GARDEN, w.grid.world_to_cell(plot.attachment)),
		null,
		"street remains clear"
	)
	var garden := w.try_place_building(GARDEN, garden_cell)
	assert_true(garden != null, "can use former backyard land")
	w.grower.step()
	var home := plot.home
	assert_true(is_instance_valid(home), "neighboring garden allows home growth")
	GameClock.day = 2
	w.grower.step()
	assert_eq(home.level, 2)
	assert_eq(w.grid.building_at(garden_cell), garden, "home upgrade preserves garden")
	home.demolish()
	assert_true(w.plots.remove_plot(plot.id))
	assert_eq(
		w.grid.building_at(garden_cell), garden, "removing the home and plot preserves garden"
	)
	garden.demolish()
	assert_true(w.grid.is_free(garden.cells))
	fx.destroy()


func test_toolbar_switches_between_sites_farm_zoning_and_inspection() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var main := MAIN.instantiate() as Main
	tree.root.add_child(main)
	var w := main.world
	var hud := main.get_node("Hud") as Hud
	var row := hud.get_node("%Build")
	var garden_button: Button
	var workshop_button: Button
	var farm_button: Button
	for button: Button in row.get_children():
		match button.text:
			"Garden":
				garden_button = button
			"Scrap workshop":
				workshop_button = button
			"Farm zone":
				farm_button = button
	garden_button.pressed.emit()
	var anchor := Vector2i(53, 56)
	w.camera.position = w.to_view(w.grid.cell_to_world(anchor))
	w.camera.lens.force_update_transform()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = w.camera.lens.unproject_position(w.camera.position)
	w.build_tool._unhandled_input(click)
	var site := w.grid.building_at(anchor)
	assert_eq(site.def, GARDEN)
	assert_true(not site.get_node("View/Body").visible, "garden displays its own model")
	workshop_button.pressed.emit()
	hud._process(0)
	assert_eq(w.build_tool.selected, WORKSHOP)
	assert_true(workshop_button.button_pressed and not garden_button.button_pressed)
	farm_button.pressed.emit()
	assert_eq(w.build_tool.selected, null)
	assert_eq(w.plot_tool.mode, PlotTool.Mode.ZONE)
	assert_eq(w.plot_tool.zone, FARM)
	farm_button.pressed.emit()
	w.plot_tool._unhandled_input(click)
	hud._process(0)
	assert_eq(w.plot_tool.selected_building, site)
	assert_eq(hud.get_node("BuildingInfo").get_node("%Title").text, "Garden")
	main.free()
