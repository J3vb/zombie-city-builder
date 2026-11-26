extends Node
## Plays settlement music and mixes bounded sound effects independently from simulation.

const TRACKS := ["day_watch", "dusk_watch", "horde_watch"]
const EFFECTS := ["gate", "breach", "radio", "warning", "work", "shot", "groan", "select"]
const POOL_SIZE := 10
const TITLE_MUSIC_GAIN := 0.85

var town: World
var track := ""
var _clips: Dictionary[String, AudioStream] = {}
var _voices: Array[AudioStreamPlayer] = []
var _music := AudioStreamPlayer.new()
var _ui := AudioStreamPlayer.new()
var _alert := AudioStreamPlayer.new()
var _last: Dictionary[String, int] = {}
var _headless := DisplayServer.get_name() == "headless"
var _quitting := false
var _radio_pending := false
var _groan_in := 0.0
var _phase_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(quit_game)
	for id: String in TRACKS + EFFECTS:
		var clip := load("res://assets/audio/%s.ogg" % id) as AudioStreamOggVorbis
		if clip != null:
			clip.loop = id in TRACKS
			_clips[id] = clip
	for player in [_music, _ui, _alert]:
		add_child(player)
	_music.bus = &"Music"
	_ui.bus = &"UI"
	_alert.bus = &"SFX"
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_voices.append(player)
	EventBus.building_placed.connect(_building)
	get_tree().node_added.connect(_new_control)
	play_title_music()


func play_title_music() -> void:
	_music.volume_linear = TITLE_MUSIC_GAIN
	_play_track("day_watch")


func _new_control(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_click):
		node.pressed.connect(_click)


func _building(_site: Node) -> void:
	effect("work")


func _click() -> void:
	_play(_ui, "select")


func bind(world: World) -> void:
	town = world
	_last.clear()
	_radio_pending = false
	_groan_in = 3.0
	_phase_timer = 0.0
	_music.volume_linear = 1.0
	_play_track("day_watch")


func _process(dt: float) -> void:
	_phase_timer -= dt
	if _phase_timer > 0.0:
		return
	_phase_timer = 0.25
	if not is_instance_valid(town) or not town.is_inside_tree():
		town = null
		_play_track("day_watch")
		return
	var choice := town.expeditions.phase == Expeditions.Phase.CHOICE
	if choice and not _radio_pending:
		effect("radio")
	_radio_pending = choice
	if get_tree().paused or GameClock.ended or GameClock.speed == 0:
		return
	if (
		GameClock.is_night()
		and town.horde.warning_day == GameClock.day
		and town.horde.approach >= 0
	):
		_play_track("horde_watch")
	elif GameClock._dusk_sent:
		_play_track("dusk_watch")
	else:
		_play_track("day_watch")
	_groan_in -= _phase_timer
	if _groan_in <= 0.0 and town.zombies.count() > 0:
		var center := town.to_sim(town.camera.position)
		if town.zombies.has_living_near(center, town.tile_size().x * 24):
			effect("groan")
		_groan_in = 5.0


func _play_track(id: String) -> void:
	if track != id:
		track = id
		_play(_music, id)


func _play(player: AudioStreamPlayer, id: String) -> void:
	if not _quitting and _clips.has(id):
		player.stream = _clips[id]
		if not _headless:
			player.play()


func effect(id: String) -> void:
	if not is_instance_valid(town) or not town.is_inside_tree() or not _clips.has(id):
		return
	var now := Time.get_ticks_msec()
	if _last.has(id) and now - _last[id] < 140:
		return
	_last[id] = now
	if id in ["warning", "radio", "breach"]:
		_play(_alert, id)
		return
	for voice in _voices:
		if not voice.playing:
			_play(voice, id)
			return


func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	for player: AudioStreamPlayer in _voices + [_music, _ui, _alert]:
		player.stop()
	# Let the audio driver finish the outstanding mix before releasing the streams.
	await get_tree().create_timer(maxf(0.12, AudioServer.get_output_latency() * 2.0)).timeout
	get_tree().quit()


func _exit_tree() -> void:
	for player: AudioStreamPlayer in _voices + [_music, _ui, _alert]:
		player.stop()
		player.stream = null
	_clips.clear()
