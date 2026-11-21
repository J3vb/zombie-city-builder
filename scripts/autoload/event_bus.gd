extends Node
## Low-rate game events only (a few per second at most).
## High-rate events like hits and shots are batched by their systems.

@warning_ignore_start("unused_signal")
signal building_placed(building: Node)
signal building_destroyed(building: Node)
signal resource_changed(id: StringName, value: int)
signal day_started(day: int)
signal dusk_started(day: int)
signal night_started(day: int)
signal game_over(days_survived: int)
@warning_ignore_restore("unused_signal")
