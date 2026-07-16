class_name DevToolsSelfCheck
extends RefCounted

static func build_report(
	panel_loaded: bool,
	round_manager: RoundManager,
	debug_join_source: DebugJoinSource,
	race_map_controller: RaceMapController,
	fake_viewer_simulator: FakeViewerSimulator,
	flow_analyzer: ZombieFlowAnalyzer,
	stress_profiler: PerformanceStressProfiler
) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("DEV TOOLS SELF CHECK")
	lines.append("- Dev panel loaded: %s" % _yes_no(panel_loaded))
	lines.append("- RoundManager found: %s" % _yes_no(round_manager != null))
	lines.append("- DebugJoinSource found: %s" % _yes_no(debug_join_source != null))
	lines.append("- RaceMapController found: %s" % _yes_no(race_map_controller != null))
	lines.append("- FakeViewerSimulator found: %s" % _yes_no(fake_viewer_simulator != null))
	lines.append("- ActiveConfigInspector found: %s" % _yes_no(_active_config_inspector_available()))
	lines.append(
		"- ZombieFlowAnalyzer available: %s"
		% _yes_no(_zombie_flow_analyzer_available(flow_analyzer))
	)
	lines.append(
		"- PerformanceStressProfiler available: %s"
		% _yes_no(_performance_stress_profiler_available(stress_profiler))
	)
	lines.append("- Active map id: %s" % _resolve_map_id(race_map_controller))
	lines.append("- Current round state: %s" % _resolve_round_state(round_manager))
	return "\n".join(lines)


static func print_report(
	panel_loaded: bool,
	round_manager: RoundManager,
	debug_join_source: DebugJoinSource,
	race_map_controller: RaceMapController,
	fake_viewer_simulator: FakeViewerSimulator,
	flow_analyzer: ZombieFlowAnalyzer,
	stress_profiler: PerformanceStressProfiler
) -> void:
	print(build_report(
		panel_loaded,
		round_manager,
		debug_join_source,
		race_map_controller,
		fake_viewer_simulator,
		flow_analyzer,
		stress_profiler
	))


static func _active_config_inspector_available() -> bool:
	return ResourceLoader.exists("res://scripts/debug/active_config_inspector.gd")


static func _zombie_flow_analyzer_available(flow_analyzer: ZombieFlowAnalyzer) -> bool:
	if flow_analyzer != null:
		return true
	return ResourceLoader.exists("res://scripts/debug/zombie_flow_analyzer.gd")


static func _performance_stress_profiler_available(stress_profiler: PerformanceStressProfiler) -> bool:
	if stress_profiler != null:
		return true
	return ResourceLoader.exists("res://scripts/debug/performance_stress_profiler.gd")


static func _resolve_map_id(race_map_controller: RaceMapController) -> String:
	if race_map_controller == null:
		return "unavailable"
	if not race_map_controller.active_map_id.is_empty():
		return race_map_controller.active_map_id
	return "unknown"


static func _resolve_round_state(round_manager: RoundManager) -> String:
	if round_manager == null:
		return "unavailable"
	return round_manager.get_state_text()


static func _yes_no(value: bool) -> String:
	return "yes" if value else "no"
