extends SceneTree
## Generates the placeholder terrain texture and TileSet.
## Run: godot --headless --script res://tools/make_terrain.gd
## (on a fresh checkout run godot --headless --import first)
## Tiles (atlas x): 0 ground, 1 rubble, 2 water, 3 border.

const TILE := 32
const PNG_PATH := "res://assets/tiles/terrain.png"
const TILESET_PATH := "res://assets/tiles/terrain_tileset.tres"
const TERRAIN_SET_PATH := "res://data/terrain/terrain_set.tres"


func _initialize() -> void:
	var terrain := load(TERRAIN_SET_PATH) as TerrainSet
	var image := Image.create(TILE * terrain.types.size(), TILE, false, Image.FORMAT_RGBA8)
	for i in terrain.types.size():
		_paint_tile(image, i, terrain.types[i].color)
	image.save_png(ProjectSettings.globalize_path(PNG_PATH))
	if not ResourceLoader.exists(PNG_PATH):
		push_error("Run 'godot --headless --import' once, then run this script again.")
		quit(1)
		return
	var texture := load(PNG_PATH) as Texture2D

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	tileset.add_source(source, 0)
	for i in terrain.types.size():
		source.create_tile(Vector2i(i, 0))
	var err := ResourceSaver.save(tileset, TILESET_PATH)
	print("tileset saved: ", err)
	quit()


func _paint_tile(image: Image, index: int, base: Color) -> void:
	var ox := index * TILE
	for y in TILE:
		for x in TILE:
			var c := base
			match index:
				0:
					if (x * 7 + y * 13) % 29 == 0:
						c = base.lightened(0.15)
				1:
					if (x / 4 + y / 4) % 3 == 0:
						c = base.darkened(0.25)
				2:
					if (y + x / 6) % 8 == 0:
						c = base.lightened(0.2)
				3:
					if (x + y) % 8 < 2:
						c = Color(0.3, 0.25, 0.1)
			if x == 0 or y == 0:
				c = c.darkened(0.1)
			image.set_pixel(ox + x, y, c)
