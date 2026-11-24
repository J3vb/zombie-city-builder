extends Node
## Resource stockpile. Ids: food, water, wood, scrap, fuel, medicine, ammo.

signal capacity_changed

const BALANCE_PATH := "res://data/balance.tres"

var capacity: int
var stock: Dictionary[StringName, int] = {}


func _ready() -> void:
	var balance := load(BALANCE_PATH) as BalanceDef
	capacity = balance.station_capacity
	reset(balance.start_resources)


func reset(start: Dictionary[StringName, int]) -> void:
	stock = start.duplicate()
	for id: StringName in stock:
		EventBus.resource_changed.emit(id, stock[id])


func get_amount(id: StringName) -> int:
	return stock.get(id, 0)


func set_capacity(limit: int) -> void:
	if limit != capacity:
		capacity = limit
		capacity_changed.emit()


## Positive deliveries need free space. Already stored goods survive a loss of capacity.
func add(id: StringName, amount: int) -> int:
	var current := get_amount(id)
	var accepted := clampi(amount, -current, maxi(0, capacity - current))
	if accepted != 0:
		stock[id] = current + accepted
		EventBus.resource_changed.emit(id, stock[id])
	return accepted


## Return previously paid materials even if storage filled while the order was open.
func refund(materials: Dictionary[StringName, int]) -> void:
	for id in materials:
		stock[id] = get_amount(id) + materials[id]
	for id in materials:
		EventBus.resource_changed.emit(id, stock[id])


func pack_ammo(rules: BalanceDef) -> bool:
	if get_amount(&"ammo") + rules.ammo_batch > capacity or not can_afford(rules.ammo_batch_cost):
		return false
	for id in rules.ammo_batch_cost:
		stock[id] = get_amount(id) - rules.ammo_batch_cost[id]
	stock[&"ammo"] = get_amount(&"ammo") + rules.ammo_batch
	for id in rules.ammo_batch_cost:
		EventBus.resource_changed.emit(id, stock[id])
	EventBus.resource_changed.emit(&"ammo", stock[&"ammo"])
	return true


func can_afford(cost: Dictionary[StringName, int]) -> bool:
	for id: StringName in cost:
		if get_amount(id) < cost[id]:
			return false
	return true


func spend(cost: Dictionary[StringName, int]) -> bool:
	if not can_afford(cost):
		return false
	for id: StringName in cost:
		stock[id] = get_amount(id) - cost[id]
	for id: StringName in cost:
		EventBus.resource_changed.emit(id, stock[id])
	return true
