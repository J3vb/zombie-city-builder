extends Node
## Resource stockpile. Ids: food, water, wood, scrap, fuel, medicine, ammo.

const BALANCE_PATH := "res://data/balance.tres"

var stock: Dictionary[StringName, int] = {}


func _ready() -> void:
	var balance := load(BALANCE_PATH) as BalanceDef
	reset(balance.start_resources)


func reset(start: Dictionary[StringName, int]) -> void:
	stock = start.duplicate()
	for id: StringName in stock:
		EventBus.resource_changed.emit(id, stock[id])


func get_amount(id: StringName) -> int:
	return stock.get(id, 0)


func add(id: StringName, amount: int) -> void:
	stock[id] = maxi(get_amount(id) + amount, 0)
	EventBus.resource_changed.emit(id, stock[id])


func can_afford(cost: Dictionary[StringName, int]) -> bool:
	for id: StringName in cost:
		if get_amount(id) < cost[id]:
			return false
	return true


func spend(cost: Dictionary[StringName, int]) -> bool:
	if not can_afford(cost):
		return false
	for id: StringName in cost:
		add(id, -cost[id])
	return true
