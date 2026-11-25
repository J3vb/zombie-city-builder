class_name BarrierSegment
extends RefCounted
## One paid grid claim, from construction stakes to a finished defense.

var def: BarrierDef
var cell: Vector2i
var along_z := false
var health: int
var progress := 0.0
var complete := false
var opened := true
var auto_close := true
var close_pending := false
var repair_fraction := 0.0
var post: DefenseTower


func blocks() -> bool:
	return complete and (not def.gate or not opened)
