extends TestCase

var _economy: Node


func _setup() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	_economy = tree.root.get_node("Economy")
	var start: Dictionary[StringName, int] = {&"wood": 10, &"scrap": 5}
	_economy.reset(start)


func test_can_afford() -> void:
	_setup()
	var cheap: Dictionary[StringName, int] = {&"wood": 10}
	var dear: Dictionary[StringName, int] = {&"wood": 11}
	assert_true(_economy.can_afford(cheap), "should afford 10 wood")
	assert_true(not _economy.can_afford(dear), "should not afford 11 wood")


func test_spend_removes_resources() -> void:
	_setup()
	var cost: Dictionary[StringName, int] = {&"wood": 4, &"scrap": 5}
	assert_true(_economy.spend(cost), "spend should succeed")
	assert_eq(_economy.get_amount(&"wood"), 6, "wood")
	assert_eq(_economy.get_amount(&"scrap"), 0, "scrap")


func test_failed_spend_changes_nothing() -> void:
	_setup()
	var cost: Dictionary[StringName, int] = {&"wood": 4, &"scrap": 6}
	assert_true(not _economy.spend(cost), "spend should fail")
	assert_eq(_economy.get_amount(&"wood"), 10, "wood")


func test_stock_never_negative() -> void:
	_setup()
	_economy.add(&"wood", -50)
	assert_eq(_economy.get_amount(&"wood"), 0, "wood")
