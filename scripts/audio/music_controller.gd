class_name MusicController
extends Node

enum MusicLayer {
	NONE,
	MENU_LOBBY,
	RACE,
}

@export var menu_lobby_stream: AudioStream
@export var race_stream: AudioStream
@export_file("*.mp3") var menu_lobby_stream_path: String = "res://assets/Music/hitslab-gaming-game-minecraft-background-music-278382.mp3"
@export_file("*.mp3") var race_stream_path: String = "res://assets/Music/hitslab-retro-retro-synthwave-gaming-music-270173.mp3"
@export var music_bus_name: StringName = &"Music"
@export_range(0.0, 8.0, 0.05) var fade_seconds: float = 1.2
@export_range(-60.0, 6.0, 0.1) var music_volume_db: float = -3.0
@export_range(-80.0, -12.0, 0.1) var silent_volume_db: float = -60.0
@export var play_menu_on_ready: bool = true

var _primary_player: AudioStreamPlayer
var _secondary_player: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _idle_player: AudioStreamPlayer
var _current_layer: int = MusicLayer.NONE
var _fade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_bus(music_bus_name)
	_ensure_players()
	if play_menu_on_ready:
		play_menu_music(true)

func play_menu_music(immediate: bool = false) -> void:
	_play_layer(MusicLayer.MENU_LOBBY, immediate)

func play_lobby_music(immediate: bool = false) -> void:
	_play_layer(MusicLayer.MENU_LOBBY, immediate)

func play_race_music(immediate: bool = false) -> void:
	_play_layer(MusicLayer.RACE, immediate)

func stop_music(immediate: bool = false) -> void:
	_current_layer = MusicLayer.NONE
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	if immediate or _active_player == null or not _active_player.playing:
		_stop_player(_primary_player)
		_stop_player(_secondary_player)
		return

	var outgoing_player: AudioStreamPlayer = _active_player
	_fade_tween = create_tween()
	_fade_tween.tween_property(outgoing_player, "volume_db", silent_volume_db, max(fade_seconds, 0.01))
	_fade_tween.tween_callback(Callable(self, "_stop_player").bind(outgoing_player))

func play_ui_select() -> void:
	var sfx_controller: SfxController = get_node_or_null("SfxController") as SfxController
	if sfx_controller != null:
		sfx_controller.play_ui_select()

func _play_layer(layer: int, immediate: bool) -> void:
	_ensure_players()
	var requested_stream: AudioStream = _get_layer_stream(layer)
	if requested_stream == null:
		push_warning("Music stream is not configured for %s." % _get_layer_name(layer))
		stop_music(immediate)
		return

	if (
		_current_layer == layer
		and _active_player != null
		and _active_player.playing
		and _active_player.stream == requested_stream
	):
		_active_player.bus = music_bus_name
		_active_player.volume_db = music_volume_db
		return

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	var incoming_player: AudioStreamPlayer = _idle_player
	var outgoing_player: AudioStreamPlayer = _active_player
	incoming_player.stop()
	incoming_player.stream = requested_stream
	incoming_player.bus = music_bus_name
	incoming_player.volume_db = music_volume_db if immediate else silent_volume_db
	incoming_player.play(0.0)

	_active_player = incoming_player
	_idle_player = outgoing_player
	_current_layer = layer

	if immediate or outgoing_player == null or not outgoing_player.playing or fade_seconds <= 0.0:
		if outgoing_player != null:
			_stop_player(outgoing_player)
		incoming_player.volume_db = music_volume_db
		return

	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(incoming_player, "volume_db", music_volume_db, fade_seconds)
	_fade_tween.tween_property(outgoing_player, "volume_db", silent_volume_db, fade_seconds)
	_fade_tween.set_parallel(false)
	_fade_tween.tween_callback(Callable(self, "_stop_player").bind(outgoing_player))

func _ensure_players() -> void:
	_ensure_audio_bus(music_bus_name)
	if _primary_player == null:
		_primary_player = get_node_or_null("PrimaryPlayer") as AudioStreamPlayer
	if _secondary_player == null:
		_secondary_player = get_node_or_null("SecondaryPlayer") as AudioStreamPlayer

	if _primary_player == null:
		_primary_player = _create_player("PrimaryPlayer")
	if _secondary_player == null:
		_secondary_player = _create_player("SecondaryPlayer")

	_configure_player(_primary_player)
	_configure_player(_secondary_player)

	if _active_player == null:
		_active_player = _primary_player
	if _idle_player == null:
		_idle_player = _secondary_player

func _create_player(player_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	add_child(player)
	return player

func _configure_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return

	player.bus = music_bus_name
	if not player.finished.is_connected(Callable(self, "_on_player_finished").bind(player)):
		player.finished.connect(Callable(self, "_on_player_finished").bind(player))

func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return

	AudioServer.add_bus()
	var bus_index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, &"Master")

func _on_player_finished(player: AudioStreamPlayer) -> void:
	if player == _active_player and _current_layer != MusicLayer.NONE:
		player.play(0.0)

func _stop_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return

	player.stop()
	player.volume_db = silent_volume_db

func _get_layer_stream(layer: int) -> AudioStream:
	match layer:
		MusicLayer.MENU_LOBBY:
			if menu_lobby_stream == null:
				menu_lobby_stream = load(menu_lobby_stream_path) as AudioStream
			return menu_lobby_stream
		MusicLayer.RACE:
			if race_stream == null:
				race_stream = load(race_stream_path) as AudioStream
			return race_stream
	return null

func _get_layer_name(layer: int) -> String:
	match layer:
		MusicLayer.MENU_LOBBY:
			return "menu/lobby music"
		MusicLayer.RACE:
			return "race music"
	return "music"
