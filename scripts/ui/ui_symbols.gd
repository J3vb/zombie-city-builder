class_name UiSymbols
extends RefCounted
## Cells in the settlement interface's monochrome icon sheet.

enum {
	GATE,
	FOOD,
	WATER,
	WOOD,
	SCRAP,
	AMMO,
	RESIDENTS,
	BUILD,
	TRIPS,
	SERVICES,
	MAP,
	GUIDE,
	MENU,
	STREET,
	ARROW,
	FLAG,
	CURVE,
	FREEFORM
}
const SHEET := "res://assets/ui/interface_symbols.png"
const CELL := 32


static func icon(index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(SHEET)
	texture.region = Rect2((index % 8) * CELL, floori(index / 8.0) * CELL, CELL, CELL)
	texture.filter_clip = true
	return texture
