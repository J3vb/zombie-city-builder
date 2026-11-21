extends Node
## Day/night clock and fixed-step simulation tick.
## time_of_day runs from 0.0 (dawn) to 1.0 (next dawn).

signal sim_tick(dt: float)

const BALANCE_PATH := "res://data/balance.tres"

var day: int = 1
var time_of_day: float = 0.0
var speed: int = 1

var _balance: BalanceDef
var _accumulator: float = 0.0
var _dusk_sent: bool = false
var _night_sent: bool = false


func _ready() -> void:
	_balance = load(BALANCE_PATH) as BalanceDef


func reset() -> void:
	day = 1
	time_of_day = 0.0
	speed = 1
	_accumulator = 0.0
	_dusk_sent = false
	_night_sent = false


func set_speed(value: int) -> void:
	speed = clampi(value, 0, 3)


func skip_to_night() -> void:
	time_of_day = maxf(time_of_day, _balance.night_at - 0.005)


func is_night() -> bool:
	return time_of_day >= _balance.night_at


func _process(delta: float) -> void:
	if speed == 0:
		return
	var step: float = 1.0 / _balance.sim_ticks_per_second
	_accumulator += delta * speed
	var ticks: int = 0
	while _accumulator >= step and ticks < _balance.max_catch_up_ticks * speed:
		_accumulator -= step
		ticks += 1
		_advance(step)
	if ticks >= _balance.max_catch_up_ticks * speed:
		_accumulator = 0.0


func _advance(dt: float) -> void:
	time_of_day += dt / _balance.day_length_seconds
	if not _dusk_sent and time_of_day >= _balance.dusk_at:
		_dusk_sent = true
		EventBus.dusk_started.emit(day)
	if not _night_sent and time_of_day >= _balance.night_at:
		_night_sent = true
		EventBus.night_started.emit(day)
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
		_dusk_sent = false
		_night_sent = false
		EventBus.day_started.emit(day)
	sim_tick.emit(dt)
