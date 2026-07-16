class_name PerformanceStressProfiler
extends Node

const STRESS_QUEUE_TIMEOUT_SEC := 12.0
const STRESS_RUNNING_TIMEOUT_SEC := 180.0
const STRESS_BOOT_WAIT_SEC := 0.35

var _round_manager: RoundManager
var _zombie_manager: ZombieManager
var _race_map_controller: RaceMapController
var _fake_viewer_simulator: FakeViewerSimulator
var _flow_analyzer: ZombieFlowAnalyzer
var _game_flow_controller: GameFlowController

var _stress_active: bool = false
var _stop_requested: bool = false
var _sampling: bool = false
var _fake_simulator_used: bool = false

var _requested_zombies: int = 0
var _spawned_zombies: int = 0
var _map_id: String = ""
var _analyzer_enabled: bool = false
var _markers_enabled: bool = false
var _notes: String = ""

var _frame_ms_samples: Array[float] = []
var _race_sample_seconds: float = 0.0
var _last_report_text: String = ""


func _enter_tree() -> void:
	if not OS.is_debug_build():
		queue_free()


func _process(delta: float) -> void:
	if not _sampling or delta <= 0.0:
		return
	_frame_ms_samples.append(delta * 1000.0)
	_race_sample_seconds += delta


func configure(
	round_manager: RoundManager,
	zombie_manager: ZombieManager,
	race_map_controller: RaceMapController,
	fake_viewer_simulator: FakeViewerSimulator,
	flow_analyzer: ZombieFlowAnalyzer = null,
	game_flow_controller: GameFlowController = null
) -> void:
	_round_manager = round_manager
	_zombie_manager = zombie_manager
	_race_map_controller = race_map_controller
	_fake_viewer_simulator = fake_viewer_simulator
	_flow_analyzer = flow_analyzer
	_game_flow_controller = game_flow_controller


func is_stress_active() -> bool:
	return _stress_active


func is_sampling() -> bool:
	return _sampling


func get_last_report_text() -> String:
	return _last_report_text


func get_status_text() -> String:
	if _stress_active:
		return "running (%d requested)" % _requested_zombies
	if _sampling:
		return "sampling"
	return "idle"


func print_performance_report() -> void:
	if _last_report_text.is_empty():
		print("PERFORMANCE STRESS REPORT\n(no report recorded yet)")
		return
	print(_last_report_text)


func finalize_manual_profile(
	map_id: String,
	requested_zombies: int,
	spawned_zombies: int,
	notes: String = "manual profile sample"
) -> void:
	_map_id = map_id
	_requested_zombies = requested_zombies
	_spawned_zombies = spawned_zombies
	_notes = notes
	_analyzer_enabled = _flow_analyzer != null and _flow_analyzer.is_recording_enabled()
	_markers_enabled = _flow_analyzer != null and _flow_analyzer.are_markers_visible()
	_build_and_print_report()


func start_sampling() -> void:
	_reset_samples()
	_sampling = true
	set_process(true)


func stop_sampling() -> void:
	_sampling = false
	if not _stress_active:
		set_process(false)


func record_frame_sample(delta_sec: float) -> void:
	if delta_sec <= 0.0:
		return
	_frame_ms_samples.append(delta_sec * 1000.0)
	_race_sample_seconds += delta_sec


func run_stress_test(zombie_count: int) -> void:
	if _stress_active:
		return
	if zombie_count <= 0:
		return
	_run_stress_test_async(zombie_count)


func stop_stress_test() -> void:
	if not _stress_active and not _sampling:
		return
	_stop_requested = true
	if _fake_viewer_simulator != null:
		_fake_viewer_simulator.stop_simulation()
	if _round_manager != null and _round_manager.state == RoundManager.RoundState.RUNNING:
		_round_manager.debug_force_end_round()


func _run_stress_test_async(zombie_count: int) -> void:
	_stress_active = true
	_stop_requested = false
	_fake_simulator_used = false
	_requested_zombies = zombie_count
	_notes = ""
	_capture_context_flags()
	_reset_samples()

	if _fake_viewer_simulator != null and _fake_viewer_simulator.is_running():
		_fake_viewer_simulator.stop_simulation()

	if _round_manager != null and _round_manager.state != RoundManager.RoundState.IDLE:
		_round_manager.reset_round()
		await get_tree().create_timer(0.2).timeout

	await _ensure_race_view_active()

	if _fake_viewer_simulator == null or _round_manager == null:
		_notes = "missing fake viewer simulator or round manager"
		_finish_stress_session()
		return

	_fake_viewer_simulator.simulate_viewers(zombie_count)
	_fake_simulator_used = true

	var queued: bool = await _wait_for_pending_count(zombie_count, STRESS_QUEUE_TIMEOUT_SEC)
	if _stop_requested:
		_finish_stress_session()
		return
	if not queued:
		_notes = "only %d/%d viewers queued before timeout" % [
			_round_manager.get_pending_count(),
			zombie_count,
		]

	_round_manager.start_round()
	var running: bool = await _wait_for_round_state(
		RoundManager.RoundState.RUNNING,
		STRESS_QUEUE_TIMEOUT_SEC
	)
	if _stop_requested:
		_finish_stress_session()
		return
	if not running:
		_notes = "race never entered RUNNING"
		_finish_stress_session()
		return

	_spawned_zombies = _zombie_manager.get_total_count() if _zombie_manager != null else 0
	start_sampling()

	var ended: bool = await _wait_for_round_state(
		RoundManager.RoundState.ENDED,
		STRESS_RUNNING_TIMEOUT_SEC
	)
	stop_sampling()

	if _stop_requested:
		if _notes.is_empty():
			_notes = "stopped manually"
	elif not ended:
		_notes = "race sampling timed out after %.0fs" % STRESS_RUNNING_TIMEOUT_SEC
		if _round_manager != null and _round_manager.state == RoundManager.RoundState.RUNNING:
			_round_manager.debug_force_end_round()
			await get_tree().create_timer(0.25).timeout

	_finish_stress_session()


func _finish_stress_session() -> void:
	stop_sampling()
	_build_and_print_report()
	_stress_active = false
	_stop_requested = false
	set_process(false)


func _capture_context_flags() -> void:
	_map_id = _resolve_map_id()
	_analyzer_enabled = _flow_analyzer != null and _flow_analyzer.is_recording_enabled()
	_markers_enabled = _flow_analyzer != null and _flow_analyzer.are_markers_visible()


func _resolve_map_id() -> String:
	if _race_map_controller == null:
		return MapCatalog.DEFAULT_MAP_ID
	if not _race_map_controller.active_map_id.is_empty():
		return _race_map_controller.active_map_id
	return MapCatalog.DEFAULT_MAP_ID


func _ensure_race_view_active() -> void:
	if _game_flow_controller != null:
		_game_flow_controller.show_race()
	await get_tree().create_timer(STRESS_BOOT_WAIT_SEC).timeout


func _wait_for_pending_count(target_count: int, timeout_sec: float) -> bool:
	var elapsed: float = 0.0
	while elapsed < timeout_sec:
		if _stop_requested:
			return false
		if _round_manager.get_pending_count() >= target_count:
			return true
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	return _round_manager.get_pending_count() >= target_count


func _wait_for_round_state(target_state: int, timeout_sec: float) -> bool:
	var elapsed: float = 0.0
	while elapsed < timeout_sec:
		if _stop_requested:
			return false
		if _round_manager.state == target_state:
			return true
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	return _round_manager.state == target_state


func _reset_samples() -> void:
	_frame_ms_samples.clear()
	_race_sample_seconds = 0.0
	_last_report_text = ""


func _build_and_print_report() -> void:
	if _spawned_zombies <= 0 and _zombie_manager != null:
		_spawned_zombies = _zombie_manager.get_total_count()

	var frame_stats: Dictionary = _compute_frame_stats()
	var zombie_stats: Dictionary = _collect_zombie_stats()

	var lines: PackedStringArray = PackedStringArray()
	lines.append("PERFORMANCE STRESS REPORT")
	lines.append("map_id: %s" % (_map_id if not _map_id.is_empty() else "unknown"))
	lines.append("requested_zombies: %d" % _requested_zombies)
	lines.append("spawned_zombies: %d" % _spawned_zombies)
	lines.append("analyzer_enabled: %s" % ("yes" if _analyzer_enabled else "no"))
	lines.append("markers_enabled: %s" % ("yes" if _markers_enabled else "no"))
	lines.append("avg_fps: %.1f" % float(frame_stats.get("avg_fps", 0.0)))
	lines.append("min_fps: %.1f" % float(frame_stats.get("min_fps", 0.0)))
	lines.append("max_frame_ms: %.2f" % float(frame_stats.get("max_frame_ms", 0.0)))
	lines.append("avg_frame_ms: %.2f" % float(frame_stats.get("avg_frame_ms", 0.0)))
	lines.append("race_time_sampled: %.2f" % _race_sample_seconds)
	lines.append("alive: %d" % int(zombie_stats.get("alive", 0)))
	lines.append("finished: %d" % int(zombie_stats.get("finished", 0)))
	lines.append("fell: %d" % int(zombie_stats.get("fell", 0)))
	lines.append("killed: %d" % int(zombie_stats.get("killed", 0)))
	lines.append("stuck: %d" % int(zombie_stats.get("stuck", 0)))
	lines.append("unresolved: %d" % int(zombie_stats.get("unresolved", 0)))
	lines.append("notes: %s" % _format_notes())

	_last_report_text = "\n".join(lines)
	print(_last_report_text)


func _compute_frame_stats() -> Dictionary:
	if _frame_ms_samples.is_empty():
		return {
			"avg_fps": 0.0,
			"min_fps": 0.0,
			"max_frame_ms": 0.0,
			"avg_frame_ms": 0.0,
		}

	var total_ms: float = 0.0
	var max_frame_ms: float = 0.0
	var min_fps: float = INF
	var fps_sum: float = 0.0
	var fps_count: int = 0

	for frame_ms in _frame_ms_samples:
		total_ms += frame_ms
		max_frame_ms = max(max_frame_ms, frame_ms)
		if frame_ms > 0.0:
			var fps: float = 1000.0 / frame_ms
			fps_sum += fps
			fps_count += 1
			min_fps = min(min_fps, fps)

	var avg_frame_ms: float = total_ms / float(_frame_ms_samples.size())
	var avg_fps: float = fps_sum / float(fps_count) if fps_count > 0 else 0.0
	if min_fps == INF:
		min_fps = 0.0

	return {
		"avg_fps": avg_fps,
		"min_fps": min_fps,
		"max_frame_ms": max_frame_ms,
		"avg_frame_ms": avg_frame_ms,
	}


func _collect_zombie_stats() -> Dictionary:
	var stats: Dictionary = {
		"alive": 0,
		"finished": 0,
		"fell": 0,
		"killed": 0,
		"stuck": 0,
		"unresolved": 0,
	}

	if _zombie_manager != null:
		stats["alive"] = _zombie_manager.get_living_count()
		for zombie in _zombie_manager.get_living_zombies():
			if zombie != null and zombie.has_finished_race():
				stats["finished"] = int(stats["finished"]) + 1

	if _flow_analyzer != null and _flow_analyzer.is_recording_enabled():
		var outcomes: Dictionary = _flow_analyzer.get_outcome_counts()
		stats["finished"] = int(outcomes.get("finished", stats["finished"]))
		stats["fell"] = int(outcomes.get("fell", 0))
		stats["killed"] = int(outcomes.get("killed", 0))
		stats["stuck"] = int(outcomes.get("stuck", 0))
		stats["unresolved"] = int(outcomes.get("unresolved", 0))

	return stats


func _format_notes() -> String:
	var parts: PackedStringArray = PackedStringArray()
	if _fake_simulator_used:
		parts.append("fake viewer simulator used")
	if not _notes.is_empty():
		parts.append(_notes)
	if parts.is_empty():
		return "none"
	return ", ".join(parts)
