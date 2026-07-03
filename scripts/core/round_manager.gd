class_name RoundManager
extends Node

enum RoundState {
	IDLE,
	COUNTDOWN,
	RUNNING,
	ENDED
}

@export var round_config: RoundConfig
@export var join_source_path: NodePath
@export var debug_join_source_path: NodePath
@export var zombie_manager_path: NodePath
@export var hazard_manager_path: NodePath
@export var powerup_manager_path: NodePath
@export var defender_manager_path: NodePath
@export var leaderboard_store_path: NodePath
@export var minigun_path: NodePath
@export var base_goal_path: NodePath

var state: RoundState = RoundState.IDLE
var round_number: int = 0
var pending_participants: Array[String] = []

var _stats: RoundStats = RoundStats.new()
var _join_source: JoinSource
var _debug_join_source: DebugJoinSource
var _zombie_manager: ZombieManager
var _hazard_manager: HazardManager
var _powerup_manager: PowerupManager
var _defender_manager: HumanDefenderManager
var _leaderboard_store: LeaderboardStore
var _minigun: BaseMinigun
var _base_goal: StreamerBaseGoal
var _round_token: int = 0
var _round_started_msec: int = 0

func _ready() -> void:
	_join_source = get_node_or_null(join_source_path) as JoinSource
	_debug_join_source = get_node_or_null(debug_join_source_path) as DebugJoinSource
	_zombie_manager = get_node_or_null(zombie_manager_path) as ZombieManager
	_hazard_manager = get_node_or_null(hazard_manager_path) as HazardManager
	_powerup_manager = get_node_or_null(powerup_manager_path) as PowerupManager
	_defender_manager = get_node_or_null(defender_manager_path) as HumanDefenderManager
	_leaderboard_store = get_node_or_null(leaderboard_store_path) as LeaderboardStore
	_minigun = get_node_or_null(minigun_path) as BaseMinigun
	_base_goal = get_node_or_null(base_goal_path) as StreamerBaseGoal

	if _join_source != null:
		_join_source.participant_join_requested.connect(_on_participant_join_requested)
	if _debug_join_source != null and _debug_join_source != _join_source:
		_debug_join_source.participant_join_requested.connect(_on_participant_join_requested)

	GameEvents.zombie_reached_base.connect(_on_zombie_reached_base)
	GameEvents.zombie_died.connect(_on_zombie_died)
	GameEvents.zombie_spawned.connect(_on_zombie_spawned)
	GameEvents.zombie_became_crawler.connect(_on_zombie_became_crawler)
	GameEvents.zombie_survived_dismemberment.connect(_on_zombie_survived_dismemberment)
	GameEvents.minigun_fired.connect(_on_minigun_fired)
	GameEvents.mine_triggered.connect(_on_mine_triggered)

	if round_config != null:
		GameEvents.command_text_changed.emit(round_config.command_text)

	_setup_preview_board()
	_publish_state()
	_seed_debug_roster_if_enabled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("round_start"):
		start_round()
	elif event.is_action_pressed("round_reset"):
		reset_round()
	elif event.is_action_pressed("debug_join"):
		var debug_source: DebugJoinSource = _get_debug_join_source()
		if debug_source != null:
			debug_source.request_random_join()

func start_round() -> void:
	if state == RoundState.COUNTDOWN or state == RoundState.RUNNING:
		return
	if _zombie_manager == null:
		return

	var minimum_count: int = 1
	if round_config != null:
		minimum_count = round_config.min_participants_to_start

	if pending_participants.size() < minimum_count:
		GameEvents.command_text_changed.emit("Waiting for zombies. Type !brains to join.")
		return

	round_number += 1
	_round_token += 1
	_stats.reset_for_round(round_number)
	state = RoundState.COUNTDOWN

	_zombie_manager.clear_all_zombies()
	_zombie_manager.set_round_active(false)

	var reserved_hazard_positions: Array[Vector3] = []
	if _hazard_manager != null:
		_hazard_manager.setup_round(round_number)
		reserved_hazard_positions = _hazard_manager.get_reserved_positions()
	if _powerup_manager != null:
		_powerup_manager.setup_round(round_number, reserved_hazard_positions)
		for reserved_powerup_position in _powerup_manager.get_reserved_positions():
			reserved_hazard_positions.append(reserved_powerup_position)
	if _defender_manager != null:
		_defender_manager.setup_round(round_number, reserved_hazard_positions)
		_defender_manager.set_round_active(false)
	if _minigun != null:
		_minigun.set_round_active(false)
	if _base_goal != null:
		_base_goal.set_goal_enabled(false)

	_zombie_manager.spawn_participants(pending_participants)
	pending_participants.clear()
	_publish_queue()
	_publish_stats()

	_publish_state()
	_run_countdown(_round_token)

func reset_round() -> void:
	_round_token += 1
	state = RoundState.IDLE
	pending_participants.clear()
	_stats.reset_for_round(0)
	_round_started_msec = 0

	if _zombie_manager != null:
		_zombie_manager.set_round_active(false)
		_zombie_manager.clear_all_zombies()
	if _hazard_manager != null:
		_hazard_manager.setup_preview(round_number)
	if _powerup_manager != null:
		_powerup_manager.clear_powerups()
	if _defender_manager != null:
		_defender_manager.set_round_active(false)
		_defender_manager.clear_defenders()
	if _minigun != null:
		_minigun.set_round_active(false)
	if _base_goal != null:
		_base_goal.set_goal_enabled(false)

	GameEvents.round_reset.emit()
	GameEvents.round_countdown_changed.emit(0)
	_publish_queue()
	_publish_stats()
	_publish_state()
	_seed_debug_roster_if_enabled()

func _on_participant_join_requested(display_name: String) -> void:
	var clean_name: String = display_name.strip_edges()
	if clean_name.is_empty() or _has_participant_name(clean_name):
		return

	if state == RoundState.COUNTDOWN and _zombie_manager != null:
		var spawned_zombie: Zombie = _zombie_manager.spawn_zombie(clean_name)
		if spawned_zombie != null:
			spawned_zombie.set_round_active(false)
		GameEvents.participant_registered.emit(clean_name, pending_participants.size())
		_publish_queue()
		return

	if state != RoundState.IDLE:
		GameEvents.command_text_changed.emit("Round in progress. Join opens after reset.")
		return

	var max_pending: int = 128
	if round_config != null:
		max_pending = round_config.max_pending_participants
	if pending_participants.size() >= max_pending:
		return

	pending_participants.append(clean_name)
	GameEvents.participant_registered.emit(clean_name, pending_participants.size())
	_publish_queue()

func get_pending_count() -> int:
	return pending_participants.size()

func get_state_text() -> String:
	return _state_to_text(state)

func get_pending_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for participant_name in pending_participants:
		names.append(participant_name)
	return names

func _on_zombie_reached_base(zombie_node: Node) -> void:
	var zombie: Zombie = zombie_node as Zombie
	if state != RoundState.RUNNING or zombie == null or not zombie.is_alive():
		return

	_end_round(zombie.display_name, false)

func _on_zombie_died(zombie_node: Node, cause: String) -> void:
	if state != RoundState.RUNNING or _zombie_manager == null:
		return

	var zombie: Zombie = zombie_node as Zombie
	if zombie != null:
		GameEvents.zombie_status_changed.emit(zombie.display_name, "Dead - %s" % _format_cause(cause))
	_stats.record_death(cause)
	_publish_stats()

	if _zombie_manager.get_living_count() <= 0:
		_end_round("Streamer Base", true)

func _end_round(winner_name: String, base_won: bool) -> void:
	state = RoundState.ENDED

	if _zombie_manager != null:
		_zombie_manager.set_round_active(false)
	if _minigun != null:
		_minigun.set_round_active(false)
	if _defender_manager != null:
		_defender_manager.set_round_active(false)
	if _base_goal != null:
		_base_goal.set_goal_enabled(false)

	var elapsed_seconds: float = _get_round_elapsed_seconds()
	_stats.record_winner(winner_name, base_won, elapsed_seconds)
	var excluded_runner_name: String = "" if base_won else winner_name
	if _zombie_manager != null:
		_stats.record_runner_ups(_zombie_manager.get_ranked_results(3, excluded_runner_name))
	if _leaderboard_store != null:
		_leaderboard_store.submit_result(winner_name, elapsed_seconds, round_number, base_won)
	if not base_won:
		GameEvents.zombie_status_changed.emit(winner_name, "Winner")
	_publish_stats()
	GameEvents.camera_shake_requested.emit(0.18 if base_won else 0.26, 0.28)
	GameEvents.round_countdown_changed.emit(0)
	GameEvents.round_ended.emit(winner_name, base_won)
	_publish_state()

func _publish_state() -> void:
	GameEvents.round_state_changed.emit(get_state_text())
	if round_config != null:
		GameEvents.command_text_changed.emit(round_config.command_text)

func _state_to_text(value: RoundState) -> String:
	match value:
		RoundState.IDLE:
			return "Joining"
		RoundState.COUNTDOWN:
			return "Countdown"
		RoundState.RUNNING:
			return "Running"
		RoundState.ENDED:
			return "Ended"
	return "Unknown"

func _seed_debug_roster_if_enabled() -> void:
	var debug_source: DebugJoinSource = _get_debug_join_source()
	if debug_source != null and debug_source.auto_seed_on_boot:
		debug_source.seed_default_participants()

func _setup_preview_board() -> void:
	if _hazard_manager != null:
		_hazard_manager.setup_preview(round_number)

func _has_participant_name(display_name: String) -> bool:
	for participant_name in pending_participants:
		if participant_name.to_lower() == display_name.to_lower():
			return true

	if _zombie_manager == null:
		return false

	return _zombie_manager.has_display_name(display_name)

func _run_countdown(token: int) -> void:
	var remaining: int = _get_countdown_seconds()
	while remaining > 0:
		if token != _round_token or state != RoundState.COUNTDOWN:
			return
		GameEvents.round_countdown_changed.emit(remaining)
		await get_tree().create_timer(1.0).timeout
		remaining -= 1

	if token != _round_token or state != RoundState.COUNTDOWN:
		return

	_launch_round()

func _launch_round() -> void:
	state = RoundState.RUNNING
	_round_started_msec = Time.get_ticks_msec()
	if _zombie_manager != null:
		_zombie_manager.set_round_active(true)
		for zombie in _zombie_manager.get_living_zombies():
			GameEvents.zombie_status_changed.emit(zombie.display_name, "Runner")
	if _minigun != null:
		_minigun.set_round_active(true)
	if _defender_manager != null:
		_defender_manager.set_round_active(true)
	if _base_goal != null:
		_base_goal.set_goal_enabled(true)

	GameEvents.round_countdown_changed.emit(0)
	GameEvents.round_started.emit(round_number)
	_publish_state()
	_publish_stats()

func _on_zombie_spawned(zombie_node: Node) -> void:
	if state != RoundState.COUNTDOWN and state != RoundState.RUNNING:
		return

	var zombie: Zombie = zombie_node as Zombie
	if zombie == null:
		return

	_stats.record_spawn()
	GameEvents.zombie_status_changed.emit(zombie.display_name, "Ready" if state == RoundState.COUNTDOWN else "Runner")
	_publish_stats()

func _on_zombie_became_crawler(zombie_node: Node, _cause: String) -> void:
	if state != RoundState.RUNNING:
		return

	var zombie: Zombie = zombie_node as Zombie
	if zombie != null:
		GameEvents.zombie_status_changed.emit(zombie.display_name, "Crawler")
	_stats.record_crawler_created()
	_publish_stats()

func _on_zombie_survived_dismemberment(zombie_node: Node, _cause: String) -> void:
	if state != RoundState.RUNNING:
		return

	var zombie: Zombie = zombie_node as Zombie
	if zombie != null:
		GameEvents.zombie_status_changed.emit(zombie.display_name, "Crawler survivor")
	_stats.record_dismember_survival()
	_publish_stats()

func _on_minigun_fired(_target_name: String, hit: bool) -> void:
	if state != RoundState.RUNNING:
		return

	_stats.record_minigun_shot(hit)
	_publish_stats()

func _on_mine_triggered(_target_name: String, _world_position: Vector3) -> void:
	if state != RoundState.RUNNING:
		return

	_stats.record_mine_trigger()
	_publish_stats()

func _publish_queue() -> void:
	GameEvents.participant_queue_changed.emit(get_pending_names())

func _publish_stats() -> void:
	var living_count: int = 0
	if _zombie_manager != null:
		living_count = _zombie_manager.get_living_count()
	GameEvents.round_stats_changed.emit(_stats.to_dictionary(living_count))

func _get_countdown_seconds() -> int:
	if round_config != null:
		return round_config.countdown_seconds
	return 5

func _get_round_elapsed_seconds() -> float:
	if _round_started_msec <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - _round_started_msec) / 1000.0

func _format_cause(cause: String) -> String:
	match cause:
		"mine":
			return "Mine"
		"minigun":
			return "Minigun"
		"defender":
			return "Defender"
		"sewer":
			return "Sewer"
		"out_of_bounds":
			return "Out of Bounds"
		_:
			return cause.capitalize()

func _get_debug_join_source() -> DebugJoinSource:
	if _debug_join_source != null:
		return _debug_join_source

	var direct_debug_source: DebugJoinSource = _join_source as DebugJoinSource
	if direct_debug_source != null:
		return direct_debug_source

	var hub: JoinSourceHub = _join_source as JoinSourceHub
	if hub != null:
		return hub.get_debug_source()

	return null
