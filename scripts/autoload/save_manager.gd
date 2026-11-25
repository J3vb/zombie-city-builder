extends Node
## Stores three manual saves and a dawn autosave, with an atomic write and previous copy.
# gdlint: disable=max-returns

const VERSION := 1
const MANUAL := [1, 2, 3]
const MAX_BYTES := 12 * 1024 * 1024
var directory := "user://saves"
var message := ""
var _game: WeakRef


func _ready() -> void:
	EventBus.day_started.connect(_dawn)


func bind(game: Main) -> void:
	_game = weakref(game)


func _dawn(day: int) -> void:
	var game := _game.get_ref() as Main if _game != null else null
	if is_instance_valid(game) and game.is_inside_tree() and is_instance_valid(game.world):
		_after_dawn.call_deferred(weakref(game.world), day)


func _after_dawn(candidate: WeakRef, day: int) -> void:
	var game := _game.get_ref() as Main if _game != null else null
	if (
		game != null
		and game.is_inside_tree()
		and game.world == candidate.get_ref()
		and GameClock.day == day
		and not GameClock.ended
	):
		write_slot(game, 0)


func write_slot(game: Main, slot: int) -> bool:
	if (
		not _valid_slot(slot)
		or game == null
		or not is_instance_valid(game.world)
		or GameClock.ended
	):
		message = "This settlement cannot be saved."
		return false
	var guide := game.get_node("Hud/OpeningGuide") as OpeningGuide
	var snapshot := SaveLayout.capture(game.world, {"step": guide.step, "hidden": guide.dismissed})
	if snapshot.is_empty():
		message = "Could not capture the settlement."
		return false
	var payload := JSON.stringify(snapshot, "", true, true)
	var record := {
		"version": VERSION,
		"day": GameClock.day,
		"payload": payload,
		"digest": payload.sha256_text()
	}
	if not _replace(slot, JSON.stringify(record)):
		message = "Could not write the save. Your previous copy is available."
		return false
	message = "Saved day %d." % GameClock.day
	return true


func _replace(slot: int, text: String) -> bool:
	if (
		text.to_utf8_buffer().size() > MAX_BYTES
		or DirAccess.make_dir_recursive_absolute(directory) != OK
	):
		return false
	var path := _path(slot)
	var temp := path + ".tmp"
	var copy := path + ".bak"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var clean := file.get_error() == OK
	file.close()
	if not clean:
		return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(copy) and not _intact(path):
			if DirAccess.remove_absolute(path) != OK:
				return false
		else:
			if FileAccess.file_exists(copy) and DirAccess.remove_absolute(copy) != OK:
				return false
			if DirAccess.rename_absolute(path, copy) != OK:
				return false
	if DirAccess.rename_absolute(temp, path) == OK:
		return true
	if FileAccess.file_exists(copy) and not FileAccess.file_exists(path):
		DirAccess.rename_absolute(copy, path)
	return false


func _intact(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return false
	var wrapper: Variant = _parse(file.get_as_text())
	return (
		wrapper is Dictionary
		and wrapper.get("payload") is String
		and wrapper.payload.sha256_text() == wrapper.get("digest")
	)


func read_slot(slot: int) -> Dictionary:
	if not _valid_slot(slot):
		message = "Unknown save slot."
		return {}
	for suffix: String in ["", ".bak"]:
		var path := _path(slot) + suffix
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > MAX_BYTES:
			continue
		var wrapper: Variant = _parse(file.get_as_text())
		file.close()
		if not wrapper is Dictionary:
			continue
		if wrapper.get("version", -1) != VERSION:
			message = "This save uses an unsupported version."
			return {}
		var payload: Variant = wrapper.get("payload")
		if not payload is String or payload.sha256_text() != wrapper.get("digest", ""):
			continue
		var data: Variant = _parse(payload)
		if data is Dictionary and SaveLayout.MAPS.has(data.get("map")):
			message = "Recovered the previous save." if suffix != "" else "Loaded settlement."
			return data
	message = "The save is missing or damaged."
	return {}


func _parse(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null


func occupied(slot: int) -> bool:
	return (
		_valid_slot(slot)
		and (FileAccess.file_exists(_path(slot)) or FileAccess.file_exists(_path(slot) + ".bak"))
	)


func _valid_slot(slot: int) -> bool:
	return slot == 0 or slot in MANUAL


func _path(slot: int) -> String:
	return directory.path_join("slot_%d.json" % slot)
