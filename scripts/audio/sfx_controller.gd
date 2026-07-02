class_name SfxController
extends Node

const BUTTON_SOUND_CONNECTED_META := "_zh_sfx_button_connected"
const BUTTON_SOUND_SKIP_META := "_zh_sfx_skip_button"

@export var sfx_bus_name: StringName = &"SFX"
@export_range(1, 32, 1) var player_pool_size: int = 16
@export_range(-60.0, 6.0, 0.1) var default_volume_db: float = -2.0
@export var bind_button_sounds: bool = true
@export var spatial_world_sfx: bool = false
@export_range(1.0, 120.0, 1.0) var spatial_max_distance: float = 44.0

@export var ui_select_stream: AudioStream
@export var participant_join_stream: AudioStream
@export var countdown_tick_stream: AudioStream
@export var round_start_stream: AudioStream
@export var base_win_stream: AudioStream
@export var base_breach_stream: AudioStream
@export var mine_explosion_stream: AudioStream
@export var minigun_shot_stream: AudioStream
@export var defender_shot_stream: AudioStream
@export var defender_down_stream: AudioStream
@export var obstacle_hit_stream: AudioStream
@export var boost_pad_stream: AudioStream
@export var zombie_crawler_stream: AudioStream
@export var zombie_die_stream: AudioStream
@export_file("*.wav") var ui_select_stream_path: String = "res://assets/audio/sfx/ui_select.wav"
@export_file("*.wav") var participant_join_stream_path: String = "res://assets/audio/sfx/participant_join.wav"
@export_file("*.wav") var countdown_tick_stream_path: String = "res://assets/audio/sfx/countdown_tick.wav"
@export_file("*.wav") var round_start_stream_path: String = "res://assets/audio/sfx/round_start.wav"
@export_file("*.wav") var base_win_stream_path: String = "res://assets/audio/sfx/base_win.wav"
@export_file("*.wav") var base_breach_stream_path: String = "res://assets/audio/sfx/base_breach.wav"
@export_file("*.wav") var mine_explosion_stream_path: String = "res://assets/audio/sfx/mine_explosion.wav"
@export_file("*.wav") var minigun_shot_stream_path: String = "res://assets/audio/sfx/minigun_shot.wav"
@export_file("*.wav") var defender_shot_stream_path: String = "res://assets/audio/sfx/defender_shot.wav"
@export_file("*.wav") var defender_down_stream_path: String = "res://assets/audio/sfx/defender_down.wav"
@export_file("*.wav") var obstacle_hit_stream_path: String = "res://assets/audio/sfx/obstacle_hit.wav"
@export_file("*.wav") var boost_pad_stream_path: String = "res://assets/audio/sfx/boost_pad.wav"
@export_file("*.wav") var zombie_crawler_stream_path: String = "res://assets/audio/sfx/zombie_crawler.wav"
@export_file("*.wav") var zombie_die_stream_path: String = "res://assets/audio/sfx/zombie_die.wav"

var _players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0
var _last_played_msec: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_audio_bus(sfx_bus_name)
	_ensure_streams_loaded()
	_rebuild_player_pool()
	_connect_game_events()
	if bind_button_sounds:
		call_deferred("_bind_buttons_in_tree")
		if not get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.connect(_on_node_added)

func play_ui_select() -> void:
	_play_stream(ui_select_stream, "ui_select", -2.0, Vector2(0.98, 1.04), 0.03)

func _connect_game_events() -> void:
	if not GameEvents.participant_registered.is_connected(_on_participant_registered):
		GameEvents.participant_registered.connect(_on_participant_registered)
	if not GameEvents.round_countdown_changed.is_connected(_on_round_countdown_changed):
		GameEvents.round_countdown_changed.connect(_on_round_countdown_changed)
	if not GameEvents.round_started.is_connected(_on_round_started):
		GameEvents.round_started.connect(_on_round_started)
	if not GameEvents.round_ended.is_connected(_on_round_ended):
		GameEvents.round_ended.connect(_on_round_ended)
	if not GameEvents.zombie_died.is_connected(_on_zombie_died):
		GameEvents.zombie_died.connect(_on_zombie_died)
	if not GameEvents.zombie_became_crawler.is_connected(_on_zombie_became_crawler):
		GameEvents.zombie_became_crawler.connect(_on_zombie_became_crawler)
	if not GameEvents.zombie_reached_base.is_connected(_on_zombie_reached_base):
		GameEvents.zombie_reached_base.connect(_on_zombie_reached_base)
	if not GameEvents.minigun_fired.is_connected(_on_minigun_fired):
		GameEvents.minigun_fired.connect(_on_minigun_fired)
	if not GameEvents.human_defender_fired.is_connected(_on_human_defender_fired):
		GameEvents.human_defender_fired.connect(_on_human_defender_fired)
	if not GameEvents.human_defender_died.is_connected(_on_human_defender_died):
		GameEvents.human_defender_died.connect(_on_human_defender_died)
	if not GameEvents.mine_triggered.is_connected(_on_mine_triggered):
		GameEvents.mine_triggered.connect(_on_mine_triggered)
	if not GameEvents.obstacle_triggered.is_connected(_on_obstacle_triggered):
		GameEvents.obstacle_triggered.connect(_on_obstacle_triggered)
	if not GameEvents.boost_pad_triggered.is_connected(_on_boost_pad_triggered):
		GameEvents.boost_pad_triggered.connect(_on_boost_pad_triggered)

func _rebuild_player_pool() -> void:
	_ensure_audio_bus(sfx_bus_name)
	for player in _players:
		if player != null and is_instance_valid(player):
			player.queue_free()

	_players.clear()
	for index in range(max(player_pool_size, 1)):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		player.bus = sfx_bus_name
		add_child(player)
		_players.append(player)

func _on_node_added(node: Node) -> void:
	if bind_button_sounds:
		_try_bind_button(node)

func _bind_buttons_in_tree() -> void:
	if not bind_button_sounds:
		return
	_bind_buttons_below(get_tree().root)

func _bind_buttons_below(node: Node) -> void:
	_try_bind_button(node)
	for child in node.get_children():
		_bind_buttons_below(child)

func _try_bind_button(node: Node) -> void:
	var button: Button = node as Button
	if button == null or button.has_meta(BUTTON_SOUND_CONNECTED_META):
		return
	if button.has_meta(BUTTON_SOUND_SKIP_META):
		return

	button.set_meta(BUTTON_SOUND_CONNECTED_META, true)
	button.pressed.connect(_on_button_pressed.bind(button))

func _ensure_streams_loaded() -> void:
	if ui_select_stream == null:
		ui_select_stream = load(ui_select_stream_path) as AudioStream
	if participant_join_stream == null:
		participant_join_stream = load(participant_join_stream_path) as AudioStream
	if countdown_tick_stream == null:
		countdown_tick_stream = load(countdown_tick_stream_path) as AudioStream
	if round_start_stream == null:
		round_start_stream = load(round_start_stream_path) as AudioStream
	if base_win_stream == null:
		base_win_stream = load(base_win_stream_path) as AudioStream
	if base_breach_stream == null:
		base_breach_stream = load(base_breach_stream_path) as AudioStream
	if mine_explosion_stream == null:
		mine_explosion_stream = load(mine_explosion_stream_path) as AudioStream
	if minigun_shot_stream == null:
		minigun_shot_stream = load(minigun_shot_stream_path) as AudioStream
	if defender_shot_stream == null:
		defender_shot_stream = load(defender_shot_stream_path) as AudioStream
	if defender_down_stream == null:
		defender_down_stream = load(defender_down_stream_path) as AudioStream
	if obstacle_hit_stream == null:
		obstacle_hit_stream = load(obstacle_hit_stream_path) as AudioStream
	if boost_pad_stream == null:
		boost_pad_stream = load(boost_pad_stream_path) as AudioStream
	if zombie_crawler_stream == null:
		zombie_crawler_stream = load(zombie_crawler_stream_path) as AudioStream
	if zombie_die_stream == null:
		zombie_die_stream = load(zombie_die_stream_path) as AudioStream

func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return

	AudioServer.add_bus()
	var bus_index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, &"Master")

func _on_button_pressed(_button: Button) -> void:
	play_ui_select()

func _on_participant_registered(_display_name: String, _queued_count: int) -> void:
	_play_stream(participant_join_stream, "participant_join", -1.5, Vector2(0.96, 1.06), 0.08)

func _on_round_countdown_changed(seconds_remaining: int) -> void:
	if seconds_remaining > 0:
		_play_stream(countdown_tick_stream, "countdown_tick", -2.0, Vector2(1.0, 1.0), 0.7)

func _on_round_started(_round_number: int) -> void:
	_play_stream(round_start_stream, "round_start", 0.0, Vector2(0.98, 1.02), 0.25)

func _on_round_ended(_winner_name: String, base_won: bool) -> void:
	if base_won:
		_play_stream(base_win_stream, "base_win", -0.5, Vector2(0.98, 1.02), 0.3)

func _on_zombie_reached_base(zombie_node: Node) -> void:
	var zombie: Node3D = zombie_node as Node3D
	var position: Vector3 = Vector3.ZERO
	if zombie != null:
		position = zombie.global_position
	_play_world_stream(base_breach_stream, "base_breach", position, -0.5, Vector2(0.96, 1.02), 0.2)

func _on_zombie_died(zombie_node: Node, cause: String) -> void:
	if cause == "mine":
		return

	var zombie: Node3D = zombie_node as Node3D
	if zombie != null:
		_play_world_stream(zombie_die_stream, "zombie_die", zombie.global_position, -3.0, Vector2(0.92, 1.08), 0.08)
	else:
		_play_stream(zombie_die_stream, "zombie_die", -3.0, Vector2(0.92, 1.08), 0.08)

func _on_zombie_became_crawler(zombie_node: Node, _cause: String) -> void:
	var zombie: Node3D = zombie_node as Node3D
	if zombie != null:
		_play_world_stream(zombie_crawler_stream, "zombie_crawler", zombie.global_position, -4.0, Vector2(0.92, 1.08), 0.12)
	else:
		_play_stream(zombie_crawler_stream, "zombie_crawler", -4.0, Vector2(0.92, 1.08), 0.12)

func _on_minigun_fired(_target_name: String, _hit: bool) -> void:
	_play_stream(minigun_shot_stream, "minigun_shot", -5.0, Vector2(0.96, 1.05), 0.045)

func _on_human_defender_fired(_defender_name: String, _target_name: String, _hit: bool) -> void:
	_play_stream(defender_shot_stream, "defender_shot", -6.0, Vector2(0.94, 1.08), 0.055)

func _on_human_defender_died(_defender_name: String) -> void:
	_play_stream(defender_down_stream, "defender_down", -1.5, Vector2(0.96, 1.02), 0.2)

func _on_mine_triggered(_target_name: String, world_position: Vector3) -> void:
	_play_world_stream(mine_explosion_stream, "mine_explosion", world_position, 1.0, Vector2(0.96, 1.02), 0.08)

func _on_obstacle_triggered(_target_name: String, _obstacle_name: String, world_position: Vector3) -> void:
	_play_world_stream(obstacle_hit_stream, "obstacle_hit", world_position, -2.5, Vector2(0.9, 1.08), 0.08)

func _on_boost_pad_triggered(_target_name: String, world_position: Vector3) -> void:
	_play_world_stream(boost_pad_stream, "boost_pad", world_position, -1.5, Vector2(0.96, 1.08), 0.08)

func _play_world_stream(
	stream: AudioStream,
	sound_key: String,
	world_position: Vector3,
	volume_offset_db: float = 0.0,
	pitch_range: Vector2 = Vector2(1.0, 1.0),
	cooldown_seconds: float = 0.0
) -> void:
	if stream == null or not _can_play(sound_key, cooldown_seconds):
		return

	if not spatial_world_sfx or get_tree().current_scene == null:
		_play_stream(stream, sound_key, volume_offset_db, pitch_range, 0.0, false)
		return

	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = "%sSfx" % sound_key.capitalize().replace(" ", "")
	player.stream = stream
	player.bus = sfx_bus_name
	player.volume_db = default_volume_db + volume_offset_db
	player.pitch_scale = _random_pitch(pitch_range)
	player.max_distance = spatial_max_distance
	get_tree().current_scene.add_child(player)
	player.global_position = world_position
	player.finished.connect(Callable(player, "queue_free"))
	player.play()

func _play_stream(
	stream: AudioStream,
	sound_key: String,
	volume_offset_db: float = 0.0,
	pitch_range: Vector2 = Vector2(1.0, 1.0),
	cooldown_seconds: float = 0.0,
	apply_cooldown: bool = true
) -> void:
	if stream == null:
		return
	if apply_cooldown and not _can_play(sound_key, cooldown_seconds):
		return

	var player: AudioStreamPlayer = _get_available_player()
	player.stop()
	player.stream = stream
	player.bus = sfx_bus_name
	player.volume_db = default_volume_db + volume_offset_db
	player.pitch_scale = _random_pitch(pitch_range)
	player.play()

func _get_available_player() -> AudioStreamPlayer:
	if _players.is_empty():
		_rebuild_player_pool()

	for player in _players:
		if player != null and not player.playing:
			return player

	var player: AudioStreamPlayer = _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % max(_players.size(), 1)
	return player

func _can_play(sound_key: String, cooldown_seconds: float) -> bool:
	if cooldown_seconds <= 0.0:
		return true

	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(_last_played_msec.get(sound_key, -1000000))
	if now_msec - last_msec < int(cooldown_seconds * 1000.0):
		return false

	_last_played_msec[sound_key] = now_msec
	return true

func _random_pitch(pitch_range: Vector2) -> float:
	var low: float = min(pitch_range.x, pitch_range.y)
	var high: float = max(pitch_range.x, pitch_range.y)
	if is_equal_approx(low, high):
		return low
	return _rng.randf_range(low, high)
