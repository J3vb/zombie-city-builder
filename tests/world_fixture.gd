class_name WorldFixture
extends RefCounted
## Creates a real World in the scene tree for tests, and frees it after.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var world: World


func create() -> World:
	var tree := Engine.get_main_loop() as SceneTree
	var balance := load("res://data/balance.tres") as BalanceDef
	Economy.reset(balance.start_resources)
	GameClock.reset()
	world = WORLD_SCENE.instantiate() as World
	tree.root.add_child(world)
	return world


func destroy() -> void:
	world.get_parent().remove_child(world)
	world.free()
