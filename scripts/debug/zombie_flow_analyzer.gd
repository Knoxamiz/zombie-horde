class_name ZombieFlowAnalyzer
extends Node

const MARKERS_SCRIPT: Script = preload("res://scripts/debug/zombie_flow_markers.gd")
const MARKER_SPAWN: int = 0
const MARKER_FINISH: int = 1
const MARKER_DEATH: int = 2
const MARKER_STUCK: int = 3
const MARKER_HAZARD: int = 4
const STUCK_SECONDS: float = 5.0
const PROGRESS_EPSILON: float = 0.005
const AREA_BUCKET_SIZE: float = 4.0
const FALLING_VELOCITY_Y: float = -0.75

const KILLED_CAUSES: Array[String] = ["sewer", "mine", "minigun", "defender", "obstacle"]

@export var race_map_controller_path: NodePath
@export var zombie_manager_path: NodePath
@export var markers_root_path: NodePath = NodePath("../../World/ZombieFlowMarkers")

var _force_enabled: bool = false
var _recording: bool = false
var _round_running: bool = false
var _round_start_msec: int = 0
var _map_id: String = ""
var _records: Dictionary = {}
var _stuck_timers: Dictionary = {}
var _stuck_progress: Dictionary = {}
var _marked_stuck: Dictionary = {}
var _deck_half_width: float = 6.1
var _deck_y: float = 0.0
var _last_report_text: String = ""

var _race_map_controller: RaceMapController
var _zombie_manager: ZombieManager
var _markers: Node3D


func _ready() -> void:
	_resolve_nodes()
	_refresh_recording_state()
	if _recording:
		_connect_signals()
	set_process(_recording)


func _resolve_nodes() -> void:
	_race_map_controller = get_node_or_null(race_map_controller_path) as RaceMapController
	_zombie_manager = get_node_or_null(zombie_manager_path) as ZombieManager
	_markers = get_node_or_null(markers_root_path) as Node3D


func set_force_enabled(enabled: bool) -> void:
	_force_enabled = enabled
	_resolve_nodes()
	_refresh_recording_state()


func is_recording_enabled() -> bool:
	return _recording


func get_last_report_text() -> String:
	return _last_report_text


func get_record_count() -> int:
	return _records.size()


func get_marker_count() -> int:
	if _markers == null:
		return 0
	return _markers.get_child_count()


func are_markers_visible() -> bool:
	if _markers == null or not _markers.has_method("are_markers_visible"):
		return false
	return bool(_markers.call("are_markers_visible"))


func set_markers_visible(visible: bool) -> void:
	_resolve_nodes()
	if _markers != null and _markers.has_method("set_markers_visible"):
		_markers.call("set_markers_visible", visible)


func clear_markers() -> void:
	_resolve_nodes()
	if _markers != null and _markers.has_method("clear_markers"):
		_markers.call("clear_markers")


func print_last_report() -> void:
	if _last_report_text.is_empty():
		print("ZOMBIE FLOW REPORT\n(no report recorded yet)")
		return
	print(_last_report_text)


func _refresh_recording_state() -> void:
	var should_record: bool = _force_enabled or _is_enabled_from_settings()
	if should_record == _recording:
		return

	_recording = should_record
	if _recording:
		_connect_signals()
	else:
		_disconnect_signals()

	set_process(_recording)


func _is_enabled_from_settings() -> bool:
	if not OS.is_debug_build():
		return false
	var game_settings: GameSettingsController = get_node_or_null("/root/GameSettings") as GameSettingsController
	if game_settings == null:
		return false
	if not game_settings.has_method("is_zombie_flow_analyzer_enabled"):
		return false
	return game_settings.is_zombie_flow_analyzer_enabled()


func _connect_signals() -> void:
	if not GameEvents.zombie_spawned.is_connected(_on_zombie_spawned):
		GameEvents.zombie_spawned.connect(_on_zombie_spawned)
	if not GameEvents.zombie_died.is_connected(_on_zombie_died):
		GameEvents.zombie_died.connect(_on_zombie_died)
	if not GameEvents.zombie_reached_base.is_connected(_on_zombie_reached_base):
		GameEvents.zombie_reached_base.connect(_on_zombie_reached_base)
	if not GameEvents.mine_triggered.is_connected(_on_mine_triggered):
		GameEvents.mine_triggered.connect(_on_mine_triggered)
	if not GameEvents.obstacle_triggered.is_connected(_on_obstacle_triggered):
		GameEvents.obstacle_triggered.connect(_on_obstacle_triggered)
	if not GameEvents.round_started.is_connected(_on_round_started):
		GameEvents.round_started.connect(_on_round_started)
	if not GameEvents.round_reset.is_connected(_on_round_reset):
		GameEvents.round_reset.connect(_on_round_reset)
	if not GameEvents.round_ended.is_connected(_on_round_ended):
		GameEvents.round_ended.connect(_on_round_ended)


func _disconnect_signals() -> void:
	if GameEvents.zombie_spawned.is_connected(_on_zombie_spawned):
		GameEvents.zombie_spawned.disconnect(_on_zombie_spawned)
	if GameEvents.zombie_died.is_connected(_on_zombie_died):
		GameEvents.zombie_died.disconnect(_on_zombie_died)
	if GameEvents.zombie_reached_base.is_connected(_on_zombie_reached_base):
		GameEvents.zombie_reached_base.disconnect(_on_zombie_reached_base)
	if GameEvents.mine_triggered.is_connected(_on_mine_triggered):
		GameEvents.mine_triggered.disconnect(_on_mine_triggered)
	if GameEvents.obstacle_triggered.is_connected(_on_obstacle_triggered):
		GameEvents.obstacle_triggered.disconnect(_on_obstacle_triggered)
	if GameEvents.round_started.is_connected(_on_round_started):
		GameEvents.round_started.disconnect(_on_round_started)
	if GameEvents.round_reset.is_connected(_on_round_reset):
		GameEvents.round_reset.disconnect(_on_round_reset)
	if GameEvents.round_ended.is_connected(_on_round_ended):
		GameEvents.round_ended.disconnect(_on_round_ended)


func _process(delta: float) -> void:
	if not _recording or not _round_running:
		return
	_refresh_recording_state()
	if not _recording:
		return
	_tick_stuck_detection(delta)


func _on_round_started(_round_number: int) -> void:
	_refresh_recording_state()
	if not _recording:
		return
	_round_running = true
	_round_start_msec = Time.get_ticks_msec()
	_map_id = _resolve_map_id()
	_apply_map_bounds()


func _on_round_reset() -> void:
	if not _recording:
		return
	_round_running = false
	_clear_session(true)


func _on_round_ended(_winner_name: String, _base_won: bool) -> void:
	if not _recording:
		return
	call_deferred("_finalize_round_report")


func finalize_round_report() -> void:
	if not _recording:
		return
	if _last_report_text.is_empty():
		_finalize_round_report()


func _finalize_round_report() -> void:
	_round_running = false
	_finalize_stuck_records()
	_finalize_unresolved_records()
	_update_final_positions()
	_print_report()


func _on_zombie_spawned(zombie_node: Node) -> void:
	if not _recording:
		return
	var zombie: Zombie = zombie_node as Zombie
	if zombie == null:
		return

	if not _round_running and not _records.is_empty() and _zombie_manager != null:
		if _zombie_manager.get_total_count() <= 1:
			_clear_session(true)

	if _map_id.is_empty():
		_map_id = _resolve_map_id()
		_apply_map_bounds()

	var record_key: int = zombie.get_instance_id()
	var zombie_type: String = _format_zombie_type(zombie)
	var spawn_position: Vector3 = zombie.global_position
	_records[record_key] = {
		"name": zombie.display_name,
		"zombie_type": zombie_type,
		"spawn_position": spawn_position,
		"final_position": spawn_position,
		"finish_position": Vector3.ZERO,
		"death_position": Vector3.ZERO,
		"stuck_position": Vector3.ZERO,
		"max_progress": 0.0,
		"finish_time": -1.0,
		"death_reason": "",
		"map_id": _map_id,
		"outcome": "unresolved",
		"zombie_ref": zombie,
	}
	_stuck_timers[record_key] = 0.0
	_stuck_progress[record_key] = 0.0
	_ensure_markers()
	_add_marker(spawn_position, MARKER_SPAWN)


func _on_zombie_reached_base(zombie_node: Node) -> void:
	if not _recording:
		return
	var zombie: Zombie = zombie_node as Zombie
	if zombie == null:
		return

	var record_key: int = zombie.get_instance_id()
	var record: Dictionary = _records.get(record_key, {})
	if record.is_empty():
		return

	var finish_position: Vector3 = zombie.global_position
	record["finish_position"] = finish_position
	record["final_position"] = finish_position
	record["finish_time"] = _get_elapsed_seconds()
	record["max_progress"] = max(float(record.get("max_progress", 0.0)), zombie.get_progress())
	record["outcome"] = "finished"
	_records[record_key] = record
	_clear_stuck_state(record_key)
	_add_marker(finish_position, MARKER_FINISH)


func _on_zombie_died(zombie_node: Node, cause: String) -> void:
	if not _recording:
		return
	var zombie: Zombie = zombie_node as Zombie
	if zombie == null:
		return

	var record_key: int = zombie.get_instance_id()
	var record: Dictionary = _records.get(record_key, {})
	if record.is_empty():
		return

	var death_position: Vector3 = zombie.global_position
	record["death_position"] = death_position
	record["final_position"] = death_position
	record["death_reason"] = cause
	record["max_progress"] = max(float(record.get("max_progress", 0.0)), zombie.get_progress())
	record["outcome"] = _outcome_for_death_cause(cause)
	_records[record_key] = record
	_clear_stuck_state(record_key)
	_add_marker(death_position, MARKER_DEATH)


func _on_mine_triggered(_target_name: String, world_position: Vector3) -> void:
	if not _recording:
		return
	_add_marker(world_position, MARKER_HAZARD)


func _on_obstacle_triggered(_target_name: String, _obstacle_name: String, world_position: Vector3) -> void:
	if not _recording:
		return
	_add_marker(world_position, MARKER_HAZARD)


func _tick_stuck_detection(delta: float) -> void:
	if _zombie_manager == null:
		return

	for zombie in _zombie_manager.get_living_zombies():
		var record_key: int = zombie.get_instance_id()
		if not _records.has(record_key):
			continue
		if not zombie.is_alive() or zombie.has_finished_race():
			continue

		var progress: float = zombie.get_progress()
		var record: Dictionary = _records[record_key]
		record["max_progress"] = max(float(record.get("max_progress", 0.0)), progress)
		record["final_position"] = zombie.global_position
		_records[record_key] = record

		if not _can_be_stuck(zombie):
			_stuck_timers[record_key] = 0.0
			_stuck_progress[record_key] = progress
			if _marked_stuck.has(record_key):
				_marked_stuck.erase(record_key)
			continue

		var last_progress: float = float(_stuck_progress.get(record_key, progress))
		if abs(progress - last_progress) < PROGRESS_EPSILON:
			_stuck_timers[record_key] = float(_stuck_timers.get(record_key, 0.0)) + delta
		else:
			_stuck_timers[record_key] = 0.0
			_stuck_progress[record_key] = progress
			if _marked_stuck.has(record_key):
				_marked_stuck.erase(record_key)

		if (
			float(_stuck_timers.get(record_key, 0.0)) >= STUCK_SECONDS
			and not _marked_stuck.has(record_key)
		):
			_marked_stuck[record_key] = true
			record = _records[record_key]
			record["stuck_position"] = zombie.global_position
			record["outcome"] = "stuck"
			_records[record_key] = record
			_add_marker(zombie.global_position, MARKER_STUCK)


func _finalize_stuck_records() -> void:
	if _zombie_manager == null:
		return

	for zombie in _zombie_manager.get_living_zombies():
		var record_key: int = zombie.get_instance_id()
		if not _records.has(record_key):
			continue
		var record: Dictionary = _records[record_key]
		if str(record.get("outcome", "")) == "finished":
			continue
		if zombie.has_finished_race():
			continue
		if not zombie.is_alive():
			continue
		if _marked_stuck.has(record_key) and _can_be_stuck(zombie):
			record["stuck_position"] = zombie.global_position
			record["final_position"] = zombie.global_position
			record["outcome"] = "stuck"
			record["max_progress"] = max(float(record.get("max_progress", 0.0)), zombie.get_progress())
			_records[record_key] = record


func _finalize_unresolved_records() -> void:
	for record_key in _records.keys():
		var record: Dictionary = _records[record_key]
		var outcome: String = str(record.get("outcome", "unresolved"))
		if outcome in ["finished", "fell", "out_of_bounds", "killed", "stuck"]:
			continue
		record["outcome"] = "unresolved"
		_records[record_key] = record


func _update_final_positions() -> void:
	for record_key in _records.keys():
		var record: Dictionary = _records[record_key]
		var zombie: Zombie = record.get("zombie_ref") as Zombie
		if zombie != null and is_instance_valid(zombie):
			record["final_position"] = zombie.global_position
			record["max_progress"] = max(float(record.get("max_progress", 0.0)), zombie.get_progress())
		record.erase("zombie_ref")
		_records[record_key] = record


func _clear_session(should_clear_markers: bool) -> void:
	_records.clear()
	_stuck_timers.clear()
	_stuck_progress.clear()
	_marked_stuck.clear()
	_map_id = ""
	_last_report_text = ""
	if should_clear_markers:
		clear_markers()


func _clear_stuck_state(record_key: int) -> void:
	_stuck_timers.erase(record_key)
	_stuck_progress.erase(record_key)
	_marked_stuck.erase(record_key)


func _outcome_for_death_cause(cause: String) -> String:
	match cause:
		"fell":
			return "fell"
		"out_of_bounds":
			return "out_of_bounds"
		_:
			if cause in KILLED_CAUSES:
				return "killed"
			return "killed"


func _can_be_stuck(zombie: Zombie) -> bool:
	if not zombie.is_alive() or zombie.has_finished_race():
		return false
	if zombie.velocity.y <= FALLING_VELOCITY_Y:
		return false
	return _is_on_race_surface(zombie)


func _resolve_map_id() -> String:
	if _race_map_controller == null:
		return MapCatalog.DEFAULT_MAP_ID
	if not _race_map_controller.active_map_id.is_empty():
		return _race_map_controller.active_map_id
	return MapCatalog.DEFAULT_MAP_ID


func _apply_map_bounds() -> void:
	var definition: RaceMapDefinition = null
	if _race_map_controller != null:
		definition = _race_map_controller.get_active_map_definition()
	if definition == null:
		_deck_half_width = 6.1
		_deck_y = 0.0
		return
	_deck_half_width = definition.lane_half_width
	_deck_y = definition.deck_y


func _is_on_race_surface(zombie: Zombie) -> bool:
	var position: Vector3 = zombie.global_position
	var surface_min_y: float = _deck_y - 0.5 if _deck_y > 0.0 else -0.5
	var surface_max_y: float = _deck_y + 2.5 if _deck_y > 0.0 else 3.5
	if position.y < surface_min_y:
		return false
	return (
		abs(position.x) <= _deck_half_width + 1.0
		and position.y >= surface_min_y
		and position.y <= surface_max_y
	)


func _get_elapsed_seconds() -> float:
	if _round_start_msec <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - _round_start_msec) / 1000.0


func _format_zombie_type(zombie: Zombie) -> String:
	var tier_label: String = "Viewer"
	var join_info: ParticipantJoinInfo = zombie.get_join_info()
	if join_info != null:
		tier_label = join_info.get_tier_label()
	var mobility_label: String = "Runner"
	match zombie.mobility_state:
		Zombie.MobilityState.CRAWLER:
			mobility_label = "Crawler"
		Zombie.MobilityState.DEAD:
			mobility_label = "Dead"
	return "%s/%s" % [tier_label, mobility_label]


func _print_report() -> void:
	var spawned: int = _records.size()
	var finished: int = 0
	var fell: int = 0
	var lateral_oob: int = 0
	var killed: int = 0
	var stuck: int = 0
	var unresolved: int = 0
	var progress_sum: float = 0.0
	var death_buckets: Dictionary = {}
	var stuck_buckets: Dictionary = {}
	var finish_buckets: Dictionary = {}

	for record_key in _records.keys():
		var record: Dictionary = _records[record_key]
		var outcome: String = str(record.get("outcome", "unresolved"))
		var max_progress: float = float(record.get("max_progress", 0.0))
		progress_sum += max_progress

		match outcome:
			"finished":
				finished += 1
				_add_area_bucket(finish_buckets, record.get("finish_position", Vector3.ZERO))
			"fell":
				fell += 1
				_add_area_bucket(death_buckets, record.get("death_position", Vector3.ZERO))
			"out_of_bounds":
				lateral_oob += 1
				_add_area_bucket(death_buckets, record.get("death_position", Vector3.ZERO))
			"killed":
				killed += 1
				_add_area_bucket(death_buckets, record.get("death_position", Vector3.ZERO))
			"stuck":
				stuck += 1
				_add_area_bucket(stuck_buckets, record.get("stuck_position", Vector3.ZERO))
			_:
				unresolved += 1

	var average_progress: float = 0.0
	if spawned > 0:
		average_progress = progress_sum / float(spawned)

	var lines: PackedStringArray = PackedStringArray()
	lines.append("ZOMBIE FLOW REPORT")
	lines.append("map_id: %s" % (_map_id if not _map_id.is_empty() else "unknown"))
	lines.append("zombies spawned: %d" % spawned)
	lines.append("finished: %d" % finished)
	lines.append("fell: %d" % fell)
	lines.append("lateral_oob: %d" % lateral_oob)
	lines.append("killed: %d" % killed)
	lines.append("stuck: %d" % stuck)
	lines.append("unresolved: %d" % unresolved)
	lines.append("average progress: %.3f" % average_progress)
	lines.append("top death area: %s" % _format_top_bucket(death_buckets))
	lines.append("top stuck area: %s" % _format_top_bucket(stuck_buckets))
	lines.append("top finish area: %s" % _format_top_bucket(finish_buckets))

	_last_report_text = "\n".join(lines)
	print(_last_report_text)


func get_outcome_counts() -> Dictionary:
	var counts: Dictionary = {
		"spawned": _records.size(),
		"finished": 0,
		"fell": 0,
		"lateral_oob": 0,
		"killed": 0,
		"stuck": 0,
		"unresolved": 0,
	}
	for record_key in _records.keys():
		var outcome: String = str(_records[record_key].get("outcome", "unresolved"))
		match outcome:
			"finished":
				counts["finished"] = int(counts["finished"]) + 1
			"fell":
				counts["fell"] = int(counts["fell"]) + 1
			"out_of_bounds":
				counts["lateral_oob"] = int(counts["lateral_oob"]) + 1
			"killed":
				counts["killed"] = int(counts["killed"]) + 1
			"stuck":
				counts["stuck"] = int(counts["stuck"]) + 1
			_:
				counts["unresolved"] = int(counts["unresolved"]) + 1
	return counts


func _ensure_markers() -> void:
	if _markers == null:
		_resolve_nodes()


func _add_marker(world_position: Vector3, kind: int) -> void:
	_ensure_markers()
	if _markers != null and _markers.has_method("add_marker"):
		_markers.call("add_marker", world_position, kind)


func _add_area_bucket(buckets: Dictionary, world_position: Vector3) -> void:
	if world_position == Vector3.ZERO:
		return
	var bucket: Vector2i = Vector2i(
		int(floor(world_position.x / AREA_BUCKET_SIZE)),
		int(floor(world_position.z / AREA_BUCKET_SIZE))
	)
	buckets[bucket] = int(buckets.get(bucket, 0)) + 1


func _format_top_bucket(buckets: Dictionary) -> String:
	if buckets.is_empty():
		return "n/a"
	var best_bucket: Vector2i = Vector2i.ZERO
	var best_count: int = -1
	for bucket in buckets.keys():
		var count: int = int(buckets[bucket])
		if count > best_count:
			best_count = count
			best_bucket = bucket
	var center_x: float = (float(best_bucket.x) + 0.5) * AREA_BUCKET_SIZE
	var center_z: float = (float(best_bucket.y) + 0.5) * AREA_BUCKET_SIZE
	return "(%.1f, %.1f) x%d" % [center_x, center_z, best_count]
