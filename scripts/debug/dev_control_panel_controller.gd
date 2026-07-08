class_name DevControlPanelController
extends CanvasLayer

const PANEL_WIDTH := 360.0
const REFRESH_INTERVAL_SEC := 0.25

@export var round_manager_path: NodePath
@export var debug_join_source_path: NodePath
@export var zombie_manager_path: NodePath
@export var race_map_controller_path: NodePath
@export var race_world_path: NodePath

var _round_manager: RoundManager
var _debug_join_source: DebugJoinSource
var _zombie_manager: ZombieManager
var _race_map_controller: RaceMapController
var _race_world: Node3D
var _flow_analyzer: ZombieFlowAnalyzer
var _markers_root: Node3D

var _panel_open: bool = false
var _refresh_elapsed: float = 0.0
var _flow_analyzer_enabled: bool = false
var _blueprint_debug_visible: bool = false

var _root: PanelContainer
var _state_label: Label
var _npc_counts_label: Label
var _config_inspector_label: Label
var _force_end_button: Button
var _clear_queue_button: Button
var _flow_toggle: CheckButton
var _blueprint_debug_toggle: CheckButton


func _enter_tree() -> void:
	if not OS.is_debug_build():
		queue_free()


func _ready() -> void:
	layer = 90
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_resolve_nodes()
	_build_ui()
	set_process(false)


func _resolve_nodes() -> void:
	_round_manager = get_node_or_null(round_manager_path) as RoundManager
	_debug_join_source = get_node_or_null(debug_join_source_path) as DebugJoinSource
	_zombie_manager = get_node_or_null(zombie_manager_path) as ZombieManager
	_race_map_controller = get_node_or_null(race_map_controller_path) as RaceMapController
	_race_world = get_node_or_null(race_world_path) as Node3D


func _unhandled_input(event: InputEvent) -> void:
	if not _panel_open and event.is_action_pressed("dev_panel"):
		_open_panel()
		get_viewport().set_input_as_handled()
	elif _panel_open and event.is_action_pressed("dev_panel"):
		_close_panel()
		get_viewport().set_input_as_handled()
	elif _panel_open and event.is_action_pressed("ui_cancel"):
		_close_panel()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _panel_open:
		return
	_refresh_elapsed += delta
	if _refresh_elapsed < REFRESH_INTERVAL_SEC:
		return
	_refresh_elapsed = 0.0
	_refresh_display()


func _open_panel() -> void:
	_panel_open = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	_refresh_display()


func _close_panel() -> void:
	_panel_open = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process(false)


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.offset_left = 12.0
	_root.offset_top = 12.0
	_root.offset_right = 12.0 + PANEL_WIDTH
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_root.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PANEL_WIDTH - 20.0, 560.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)

	_add_header(body, "Dev Control Panel (F3)")
	_add_hint(body, "Debug builds only. Hidden when closed.")

	_add_section(body, "Race")
	_state_label = _add_readout(body, "State: —")
	_add_button_row(body, [
		["Start Race", _on_start_race_pressed],
		["Reset Race", _on_reset_race_pressed],
	])
	_force_end_button = _add_button(body, "Force End Race", _on_force_end_pressed)
	_add_button(body, "Return to Lobby", _on_return_lobby_pressed)

	_add_section(body, "NPCs")
	_npc_counts_label = _add_readout(body, "Counts: —")
	_add_button_row(body, [
		["+1 NPC", _on_add_one_npc_pressed],
		["+5 NPCs", _on_add_five_npcs_pressed],
		["+20 NPCs", _on_add_twenty_npcs_pressed],
	])
	_clear_queue_button = _add_button(body, "Clear Queued NPCs", _on_clear_queue_pressed)

	_add_section(body, "Active Config Inspector")
	_add_hint(body, "Read-only runtime values after map load.")
	_config_inspector_label = _add_readout(body, "Config: —")
	_config_inspector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_button(body, "Copy / Print Config Snapshot", _on_copy_snapshot_pressed)

	_add_section(body, "Debug Toggles")
	_flow_toggle = CheckButton.new()
	_flow_toggle.text = "Zombie Flow Analyzer"
	_flow_toggle.toggled.connect(_on_flow_analyzer_toggled)
	body.add_child(_flow_toggle)

	_blueprint_debug_toggle = CheckButton.new()
	_blueprint_debug_toggle.text = "Blueprint Debug Layer"
	_blueprint_debug_toggle.toggled.connect(_on_blueprint_debug_toggled)
	body.add_child(_blueprint_debug_toggle)

	_add_button(body, "Close (F3 / Esc)", _on_close_pressed)


func _add_header(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)


func _add_hint(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color(0.75, 0.75, 0.75, 1.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _add_section(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	parent.add_child(label)


func _add_readout(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_button_row(parent: Control, specs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for spec in specs:
		var button := Button.new()
		button.text = str(spec[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(spec[1])
		row.add_child(button)
	parent.add_child(row)
	return row


func _on_close_pressed() -> void:
	_close_panel()


func _on_start_race_pressed() -> void:
	if _round_manager != null:
		_round_manager.start_round()
	_refresh_display()


func _on_reset_race_pressed() -> void:
	if _round_manager != null:
		_round_manager.reset_round()
	_refresh_display()


func _on_force_end_pressed() -> void:
	if _round_manager != null:
		_round_manager.debug_force_end_round()
	_refresh_display()


func _on_return_lobby_pressed() -> void:
	if _round_manager != null:
		_round_manager.reset_round()
	_refresh_display()


func _on_add_one_npc_pressed() -> void:
	_add_npcs(1)


func _on_add_five_npcs_pressed() -> void:
	_add_npcs(5)


func _on_add_twenty_npcs_pressed() -> void:
	_add_npcs(20)


func _add_npcs(count: int) -> void:
	if _debug_join_source == null or count <= 0:
		return
	for _index in range(count):
		_debug_join_source.request_random_join()
	_refresh_display()


func _on_clear_queue_pressed() -> void:
	if _round_manager != null:
		_round_manager.debug_clear_pending_participants()
	_refresh_display()


func _on_copy_snapshot_pressed() -> void:
	var snapshot: String = ActiveConfigInspector.build_snapshot_text(
		_round_manager,
		_race_map_controller,
		_zombie_manager
	)
	print(snapshot)
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(snapshot)
	_refresh_display()


func _on_flow_analyzer_toggled(enabled: bool) -> void:
	_flow_analyzer_enabled = enabled
	var analyzer := _ensure_flow_analyzer()
	if analyzer != null:
		analyzer.set_force_enabled(enabled)


func _on_blueprint_debug_toggled(enabled: bool) -> void:
	_blueprint_debug_visible = enabled
	var arena := _get_blueprint_arena()
	if arena == null:
		return
	arena.show_debug_layer = enabled
	arena.build_map()


func _ensure_flow_analyzer() -> ZombieFlowAnalyzer:
	if _flow_analyzer != null and is_instance_valid(_flow_analyzer):
		return _flow_analyzer

	var systems: Node = get_node_or_null("../../Systems")
	if systems == null:
		return null

	_flow_analyzer = systems.get_node_or_null("ZombieFlowAnalyzer") as ZombieFlowAnalyzer
	if _flow_analyzer == null:
		_flow_analyzer = ZombieFlowAnalyzer.new()
		_flow_analyzer.name = "ZombieFlowAnalyzer"
		_flow_analyzer.race_map_controller_path = NodePath("../RaceMapController")
		_flow_analyzer.zombie_manager_path = NodePath("../ZombieManager")
		_flow_analyzer.markers_root_path = NodePath("../../World/ZombieFlowMarkers")
		systems.add_child(_flow_analyzer)

	_ensure_flow_markers()
	return _flow_analyzer


func _ensure_flow_markers() -> void:
	if _race_world == null:
		_race_world = get_node_or_null(race_world_path) as Node3D
	if _race_world == null:
		return

	_markers_root = _race_world.get_node_or_null("ZombieFlowMarkers") as Node3D
	if _markers_root == null:
		_markers_root = ZombieFlowMarkers.new()
		_markers_root.name = "ZombieFlowMarkers"
		_markers_root.visible = false
		_race_world.add_child(_markers_root)


func _get_blueprint_arena() -> BlueprintMapArena:
	if _race_world == null:
		return null
	var road_arena: Node3D = _race_world.get_node_or_null("RoadArena") as Node3D
	if road_arena == null:
		return null
	var core_road: Node = road_arena.get_node_or_null("CoreRoad")
	return core_road as BlueprintMapArena


func _refresh_display() -> void:
	_refresh_race_state()
	_refresh_npc_counts()
	_refresh_config_inspector()
	_refresh_toggle_states()


func _refresh_race_state() -> void:
	if _state_label == null:
		return
	if _round_manager == null:
		_state_label.text = "State: RoundManager missing"
		_force_end_button.disabled = true
		return

	var state_text: String = _round_manager.get_state_text()
	var round_number: int = _round_manager.round_number
	_state_label.text = "State: %s (round #%d)" % [state_text, round_number]
	_force_end_button.disabled = _round_manager.state != RoundManager.RoundState.RUNNING
	_clear_queue_button.disabled = (
		_round_manager.state != RoundManager.RoundState.IDLE
		or _round_manager.get_pending_count() <= 0
	)


func _refresh_npc_counts() -> void:
	if _npc_counts_label == null:
		return

	var queued: int = _round_manager.get_pending_count() if _round_manager != null else 0
	var racing: int = 0
	var living: int = 0
	var total: int = 0
	var finished: int = 0
	var dead: int = 0

	if _zombie_manager != null:
		racing = _zombie_manager.get_racing_count()
		living = _zombie_manager.get_living_count()
		total = _zombie_manager.get_total_count()
		for zombie in _zombie_manager.get_living_zombies():
			if zombie != null and zombie.has_finished_race():
				finished += 1
		dead = max(total - living, 0)

	_npc_counts_label.text = (
		"Queued: %d | Racing: %d | Alive: %d | Finished: %d | Dead: %d | Total: %d"
		% [queued, racing, living, finished, dead, total]
	)


func _refresh_config_inspector() -> void:
	if _config_inspector_label == null:
		return
	_config_inspector_label.text = ActiveConfigInspector.build_display_text(
		_round_manager,
		_race_map_controller,
		_zombie_manager
	)


func _refresh_toggle_states() -> void:
	if _flow_toggle != null:
		var analyzer := _ensure_flow_analyzer()
		_flow_toggle.disabled = analyzer == null
		if analyzer != null:
			_flow_analyzer_enabled = analyzer.is_recording_enabled()
			_flow_toggle.set_block_signals(true)
			_flow_toggle.button_pressed = _flow_analyzer_enabled
			_flow_toggle.set_block_signals(false)

	if _blueprint_debug_toggle != null:
		var arena := _get_blueprint_arena()
		_blueprint_debug_toggle.disabled = arena == null
		if arena != null:
			_blueprint_debug_visible = arena.show_debug_layer
			_blueprint_debug_toggle.set_block_signals(true)
			_blueprint_debug_toggle.button_pressed = _blueprint_debug_visible
			_blueprint_debug_toggle.set_block_signals(false)
