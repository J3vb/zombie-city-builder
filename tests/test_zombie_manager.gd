extends TestCase

const WALKER := preload("res://data/zombies/walker.tres")


func test_spawn_until_full() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var zm := world.zombies
	var cap: int = (load("res://data/balance.tres") as BalanceDef).max_zombies
	for i in cap:
		zm.spawn(Vector2(100, 100), WALKER)
	assert_eq(zm.count(), cap, "filled")
	assert_true(not zm.spawn(Vector2(100, 100), WALKER), "full -> false")
	fx.destroy()


func test_deaths_removed_at_end_of_frame() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var zm := world.zombies
	for i in 5:
		zm.spawn(Vector2(100 + i * 40, 100), WALKER)
	zm.kill(1)
	zm.kill(1)
	zm.kill(4)
	assert_eq(zm.count(), 5, "still 5 inside the frame")
	zm._process(0.0)
	assert_eq(zm.count(), 3, "two removed")
	var xs: Array[float] = []
	for i in zm.count():
		xs.append(zm.position_of(i).x)
	xs.sort()
	assert_eq(xs, [100.0, 180.0, 220.0] as Array[float], "survivors")
	fx.destroy()


func test_damage_to_zero_kills() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var zm := world.zombies
	zm.spawn(Vector2(100, 100), WALKER)
	zm.damage(0, WALKER.health - 1)
	zm._process(0.0)
	assert_eq(zm.count(), 1, "alive at 1 hp")
	zm.damage(0, 1)
	zm._process(0.0)
	assert_eq(zm.count(), 0, "dead")
	fx.destroy()


func test_zombies_walk_to_command_post_and_attack() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var zm := world.zombies
	var cp := world.command_post
	var start := cp.position + Vector2(-6 * 32, 16)
	zm.spawn(start, WALKER)
	var before := start.distance_to(cp.position)
	for i in 60:
		zm._process(0.1)
	assert_true(zm.position_of(0).distance_to(cp.position) < before, "moved closer")
	for i in 200:
		zm._process(0.1)
	assert_true(cp.health < cp.def.max_health, "command post damaged")
	fx.destroy()


func test_zombie_never_enters_blocked_tile() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var zm := world.zombies
	zm.spawn(world.command_post.position + Vector2(-64, 16), WALKER)
	for i in 300:
		zm._process(0.1)
		var cell := world.grid.world_to_cell(zm.position_of(0))
		if world.grid.get_cost(cell) <= 0:
			fail("zombie inside blocked tile at step %d" % i)
			break
	fx.destroy()
