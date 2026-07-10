class_name DevControlPanelController
extends CanvasLayer

const THEME := preload("res://scripts/ui/control_room_theme.gd")
const PANEL_WIDTH := 420.0
const PANEL_HEIGHT := 700.0
const REFRESH_INTERVAL_SEC := 0.25
const FONT_TITLE := 20
const FONT_SECTION := 15
const FONT_BODY := 13
const FONT_SMALL := 11

@export var round_manager_path: NodePath
@export var debug_join_source_path: NodePath
@export var zombie_manager_path: NodePath
@export var race_map_controller_path: NodePath
@export var race_world_path: NodePath
@export var spectator_camera_path: NodePath

var _round_manager: RoundManager
var _debug_join_source: DebugJoinSource
var _zombie_manager: ZombieManager
var _race_map_controller: RaceMapController
var _race_world: Node3D
var _flow_analyzer: ZombieFlowAnalyzer
var _markers_root: Node3D
var _fake_viewer_simulator: FakeViewerSimulator
var _stress_profiler: PerformanceStressProfiler
var _annotation_painter: DevAnnotationPainter

var _panel_open: bool = false
var _refresh_elapsed: float = 0.0
var _flow_analyzer_enabled: bool = false
var _flow_markers_visible: bool = true
var _blueprint_debug_visible: bool = false
var _annotation_paint_enabled: bool = false
var _annotation_marks_visible: bool = true

var _root: PanelContainer
var _tab_container: TabContainer
var _status_state_label: Label
var _status_map_label: Label
var _status_npc_label: Label
var _state_label: Label
var _npc_counts_label: Label
var _config_inspector_label: Label
var _force_end_button: Button
var _clear_queue_button: Button
var _simulator_status_label: Label
var _flow_status_label: Label
var _flow_toggle: CheckButton
var _flow_markers_toggle: CheckButton
var _stress_status_label: Label
var _blueprint_debug_toggle: CheckButton
var _hint_label: Label
var _paint_hint_label: Label
var _dev_map_status_label: Label
var _annotation_status_label: Label
var _annotation_paint_toggle: CheckButton
var _annotation_marks_toggle: CheckButton
var _annotation_note_field: LineEdit
var _annotation_color_buttons: Dictionary = {}
var _race_primary_button: Button

const FALLTHROUGH_LOWER_DECK_TEST_MAP_ID := "ai_generated_fallthrough_lower_deck_test"


func _enter_tree() -> void:
	if not OS.is_debug_build():
		queue_free()


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	_resolve_nodes()
	_ensure_fake_viewer_simulator()
	_ensure_stress_profiler()
	_build_ui()
	_build_hint_overlay()
	_ensure_annotation_painter()
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
	_root.visible = true
	if _hint_label != null:
		_hint_label.visible = false
	if _annotation_painter != null:
		_annotation_painter.set_panel_blocks_input(true)
	set_process(true)
	_refresh_display()


func _close_panel() -> void:
	_panel_open = false
	_root.visible = false
	if _hint_label != null:
		_hint_label.visible = true
	if _annotation_painter != null:
		_annotation_painter.set_panel_blocks_input(false)
	set_process(false)


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.offset_left = 12.0
	_root.offset_top = 12.0
	_root.offset_right = 12.0 + PANEL_WIDTH
	_root.offset_bottom = 12.0 + PANEL_HEIGHT
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_theme_stylebox_override(
		"panel",
		THEME.panel_style(THEME.COLOR_ORANGE, Color(0.018, 0.024, 0.02, 0.98), 3)
	)
	add_child(_root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_root.add_child(margin)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	margin.add_child(shell)

	_build_header_row(shell)
	_build_status_bar(shell)
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.custom_minimum_size = Vector2(PANEL_WIDTH - 28.0, PANEL_HEIGHT - 120.0)
	_style_tab_container(_tab_container)
	shell.add_child(_tab_container)

	_tab_container.add_child(_build_quick_tab())
	_tab_container.set_tab_title(0, "Quick")
	_tab_container.add_child(_build_maps_tab())
	_tab_container.set_tab_title(1, "Maps")
	_tab_container.add_child(_build_testing_tab())
	_tab_container.set_tab_title(2, "Testing")
	_tab_container.add_child(_build_info_tab())
	_tab_container.set_tab_title(3, "Info")
	_tab_container.current_tab = 0

	_add_footer_hint(shell, "F3 or Esc to close  •  P = spray paint  •  Backspace = pause")

	_root.visible = false


func _build_header_row(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var title := Label.new()
	title.text = "DEV TOOLS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	THEME.apply_label(title, FONT_TITLE, THEME.COLOR_GREEN)
	row.add_child(title)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(72, 32)
	_style_action_button(close_button, Color(0.12, 0.14, 0.12, 1.0), THEME.COLOR_MUTED)
	close_button.pressed.connect(_on_close_pressed)
	row.add_child(close_button)


func _build_status_bar(parent: Control) -> void:
	var card := _make_section_card(parent, THEME.COLOR_BLUE)
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 4)
	card.add_child(grid)

	_status_state_label = _add_status_line(grid, "Race", "—")
	_status_map_label = _add_status_line(grid, "Map", "—")
	_status_npc_label = _add_status_line(grid, "Racers", "—")

	_state_label = _status_state_label


func _build_quick_tab() -> Control:
	var scroll := _make_tab_scroll()
	var body := _get_tab_body(scroll)

	_build_spray_paint_card(body)

	var race_card := _make_section_card(body, THEME.COLOR_GREEN)
	_add_card_title(race_card, "Race")
	_add_card_hint(race_card, "Stage first, then hit Go when ready. Backspace pauses.")
	var race_row := _add_styled_button_row(race_card, [
		["Stage", _on_start_race_pressed],
		["Reset", _on_reset_race_pressed],
	])
	if race_row.get_child_count() > 0:
		_race_primary_button = race_row.get_child(0) as Button
	_force_end_button = _add_styled_button(race_card, "Force End", _on_force_end_pressed)
	_add_styled_button(race_card, "Return to Lobby", _on_return_lobby_pressed)

	var npc_card := _make_section_card(body, THEME.COLOR_ORANGE)
	_add_card_title(npc_card, "Add Racers")
	_npc_counts_label = _add_card_readout(npc_card, "Queued: —")
	_add_styled_button_row(npc_card, [
		["+1", _on_add_one_npc_pressed],
		["+5", _on_add_five_npcs_pressed],
		["+20", _on_add_twenty_npcs_pressed],
	])
	_clear_queue_button = _add_styled_button(npc_card, "Clear Queue", _on_clear_queue_pressed)

	return scroll


func _build_maps_tab() -> Control:
	var scroll := _make_tab_scroll()
	var body := _get_tab_body(scroll)

	var map_card := _make_section_card(body, THEME.COLOR_PURPLE)
	_add_card_title(map_card, "Prototype Maps")
	_add_card_hint(map_card, "Loads test maps not listed in the streamer menu.")
	_dev_map_status_label = _add_card_readout(map_card, "No dev map loaded.")
	_add_styled_button(map_card, "Load Fallthrough Lower Deck", _on_load_fallthrough_lower_deck_pressed)
	_add_styled_button(map_card, "Load + Queue 20 NPCs", _on_load_fallthrough_queue_twenty_pressed)

	var debug_card := _make_section_card(body, THEME.COLOR_MUTED)
	_add_card_title(debug_card, "Debug Overlays")
	_blueprint_debug_toggle = CheckButton.new()
	_style_toggle(_blueprint_debug_toggle, "Blueprint debug layer")
	_blueprint_debug_toggle.toggled.connect(_on_blueprint_debug_toggled)
	debug_card.add_child(_blueprint_debug_toggle)

	return scroll


func _build_testing_tab() -> Control:
	var scroll := _make_tab_scroll()
	var body := _get_tab_body(scroll)

	var sim_card := _make_section_card(body, THEME.COLOR_BLUE)
	_add_card_title(sim_card, "Fake Viewers")
	_add_card_hint(sim_card, "Simulate Twitch joins without chat.")
	_simulator_status_label = _add_card_readout(sim_card, "Simulator idle")
	_add_styled_button_row(sim_card, [
		["5", _on_simulate_five_pressed],
		["20", _on_simulate_twenty_pressed],
		["100", _on_simulate_hundred_pressed],
	])
	_add_styled_button(sim_card, "Trickle 1/sec × 20s", _on_trickle_joins_pressed)
	_add_styled_button(sim_card, "Burst 20 in 3s", _on_burst_joins_pressed)
	_add_styled_button_row(sim_card, [
		["Clear Queue", _on_clear_sim_queue_pressed],
		["Stop", _on_stop_simulation_pressed],
	])

	var flow_card := _make_section_card(body, THEME.COLOR_GREEN)
	_add_card_title(flow_card, "Zombie Flow")
	_flow_status_label = _add_card_readout(flow_card, "Analyzer off")
	_flow_toggle = CheckButton.new()
	_style_toggle(_flow_toggle, "Record spawn / death / stuck events")
	_flow_toggle.toggled.connect(_on_flow_analyzer_toggled)
	flow_card.add_child(_flow_toggle)
	_flow_markers_toggle = CheckButton.new()
	_style_toggle(_flow_markers_toggle, "Show world markers")
	_flow_markers_toggle.button_pressed = true
	_flow_markers_toggle.toggled.connect(_on_flow_markers_toggled)
	flow_card.add_child(_flow_markers_toggle)
	_add_styled_button_row(flow_card, [
		["Clear", _on_clear_flow_markers_pressed],
		["Report", _on_print_flow_report_pressed],
	])
	_add_styled_button(flow_card, "Run 20-viewer analysis", _on_run_flow_test_pressed)

	var stress_card := _make_section_card(body, THEME.COLOR_RED)
	_add_card_title(stress_card, "Performance")
	_stress_status_label = _add_card_readout(stress_card, "Profiler idle")
	_add_styled_button_row(stress_card, [
		["20", _on_stress_twenty_pressed],
		["100", _on_stress_hundred_pressed],
	])
	_add_styled_button_row(stress_card, [
		["250", _on_stress_two_fifty_pressed],
		["500", _on_stress_five_hundred_pressed],
	])
	_add_styled_button_row(stress_card, [
		["Stop", _on_stop_stress_pressed],
		["Report", _on_print_stress_report_pressed],
	])

	return scroll


func _build_info_tab() -> Control:
	var scroll := _make_tab_scroll()
	var body := _get_tab_body(scroll)

	var tools_card := _make_section_card(body, THEME.COLOR_GREEN)
	_add_card_title(tools_card, "Diagnostics")
	_add_styled_button(tools_card, "Run Self Check", _on_self_check_pressed)
	_add_styled_button(tools_card, "Copy Config Snapshot", _on_copy_snapshot_pressed)

	var config_card := _make_section_card(body, THEME.COLOR_MUTED)
	_add_card_title(config_card, "Active Config")
	_add_card_hint(config_card, "Runtime map and race values.")
	var config_scroll := ScrollContainer.new()
	config_scroll.custom_minimum_size = Vector2(0, 220)
	config_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	config_card.add_child(config_scroll)
	_config_inspector_label = Label.new()
	_config_inspector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	THEME.apply_label(_config_inspector_label, FONT_SMALL, THEME.COLOR_MUTED)
	config_scroll.add_child(_config_inspector_label)

	return scroll


func _make_tab_scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll


func _get_tab_body(scroll: ScrollContainer) -> VBoxContainer:
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	return body


func _build_spray_paint_card(parent: Control) -> void:
	var card := _make_section_card(parent, Color(1.0, 0.35, 0.45, 1.0))
	_add_card_title(card, "Mark a Bug")
	_add_card_hint(card, "Enable Race Free Cam, then spray the problem spot.")
	_annotation_status_label = _add_card_readout(card, "Paint: off")

	_annotation_paint_toggle = CheckButton.new()
	_style_toggle(_annotation_paint_toggle, "Spray paint mode (P)")
	_annotation_paint_toggle.toggled.connect(_on_annotation_paint_toggled)
	card.add_child(_annotation_paint_toggle)

	_annotation_marks_toggle = CheckButton.new()
	_style_toggle(_annotation_marks_toggle, "Show spray marks")
	_annotation_marks_toggle.button_pressed = true
	_annotation_marks_toggle.toggled.connect(_on_annotation_marks_toggled)
	card.add_child(_annotation_marks_toggle)

	_add_card_hint(card, "Colors: Bug = broken  •  Visual = looks wrong  •  Walk = should be floor")
	_add_annotation_color_row(card)

	_annotation_note_field = LineEdit.new()
	_annotation_note_field.placeholder_text = "Short note for the agent (optional)"
	_annotation_note_field.custom_minimum_size = Vector2(0, 34)
	_style_line_edit(_annotation_note_field)
	_annotation_note_field.text_changed.connect(_on_annotation_note_changed)
	card.add_child(_annotation_note_field)

	_add_styled_button_row(card, [
		["Export", _on_export_annotation_pressed],
		["Clear", _on_clear_annotation_pressed],
	])

	var steps := Label.new()
	steps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	steps.text = "1. Stage race  2. Enable free cam  3. P (panel auto-closes)  4. Left-drag  5. Export"
	THEME.apply_label(steps, FONT_SMALL, THEME.COLOR_MUTED)
	card.add_child(steps)


func _make_section_card(parent: Control, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		THEME.panel_style(accent.darkened(0.35), Color(0.03, 0.04, 0.035, 0.96), 2)
	)
	parent.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	margin.add_child(body)

	card.set_meta("card_body", body)
	return card


func _get_card_body(card: PanelContainer) -> VBoxContainer:
	return card.get_meta("card_body") as VBoxContainer


func _add_card_title(card: PanelContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	THEME.apply_label(label, FONT_SECTION, THEME.COLOR_TEXT)
	_get_card_body(card).add_child(label)


func _add_card_hint(card: PanelContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	THEME.apply_label(label, FONT_SMALL, THEME.COLOR_MUTED)
	_get_card_body(card).add_child(label)


func _add_card_readout(card: PanelContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	THEME.apply_label(label, FONT_BODY, THEME.COLOR_BLUE)
	_get_card_body(card).add_child(label)
	return label


func _add_status_line(parent: Control, prefix: String, value: String) -> Label:
	var label := Label.new()
	label.text = "%s: %s" % [prefix, value]
	THEME.apply_label(label, FONT_BODY, THEME.COLOR_TEXT)
	parent.add_child(label)
	return label


func _add_footer_hint(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	THEME.apply_label(label, FONT_SMALL, THEME.COLOR_MUTED)
	parent.add_child(label)


func _style_tab_container(tabs: TabContainer) -> void:
	var tab_bg := StyleBoxFlat.new()
	tab_bg.bg_color = Color(0.04, 0.05, 0.045, 1.0)
	tab_bg.set_content_margin_all(8)
	tabs.add_theme_stylebox_override("panel", tab_bg)
	tabs.add_theme_font_size_override("font_size", FONT_BODY)
	tabs.add_theme_color_override("font_selected_color", THEME.COLOR_GREEN)
	tabs.add_theme_color_override("font_unselected_color", THEME.COLOR_MUTED)


func _style_action_button(button: Button, base: Color, border: Color) -> void:
	button.custom_minimum_size = Vector2(0, 34)
	THEME.apply_button(button, base, base.lightened(0.08), border, FONT_BODY)


func _style_toggle(toggle: CheckButton, text: String) -> void:
	toggle.text = text
	toggle.add_theme_font_size_override("font_size", FONT_BODY)
	toggle.add_theme_color_override("font_color", THEME.COLOR_TEXT)
	toggle.add_theme_color_override("font_hover_color", Color.WHITE)


func _style_line_edit(field: LineEdit) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.055, 1.0)
	style.border_color = THEME.COLOR_MUTED.darkened(0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	field.add_theme_stylebox_override("normal", style)
	field.add_theme_stylebox_override("focus", style)
	field.add_theme_color_override("font_color", THEME.COLOR_TEXT)
	field.add_theme_color_override("font_placeholder_color", THEME.COLOR_MUTED)
	field.add_theme_font_size_override("font_size", FONT_BODY)


func _add_styled_button(parent: Control, text: String, callback: Callable) -> Button:
	var body: VBoxContainer
	if parent is PanelContainer:
		body = _get_card_body(parent as PanelContainer)
	else:
		body = parent as VBoxContainer
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(button, Color(0.1, 0.12, 0.1, 1.0), THEME.COLOR_ORANGE.darkened(0.25))
	button.pressed.connect(callback)
	body.add_child(button)
	return button


func _add_styled_button_row(parent: Control, specs: Array) -> HBoxContainer:
	var body: VBoxContainer
	if parent is PanelContainer:
		body = _get_card_body(parent as PanelContainer)
	else:
		body = parent as VBoxContainer
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for spec in specs:
		var button := Button.new()
		button.text = str(spec[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(button, Color(0.1, 0.12, 0.1, 1.0), THEME.COLOR_ORANGE.darkened(0.25))
		button.pressed.connect(spec[1])
		row.add_child(button)
	body.add_child(row)
	return row


func _build_hint_overlay() -> void:
	_hint_label = Label.new()
	_hint_label.name = "DevToolsHint"
	_hint_label.text = "F3 Dev Tools"
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint_label.offset_left = -280.0
	_hint_label.offset_top = -36.0
	_hint_label.offset_right = -12.0
	_hint_label.offset_bottom = -12.0
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.modulate = Color(0.82, 0.86, 0.92, 0.88)
	add_child(_hint_label)

	_paint_hint_label = Label.new()
	_paint_hint_label.name = "PaintModeHint"
	_paint_hint_label.text = "SPRAY PAINT: left-drag mark | right-drag look | P or Esc exit"
	_paint_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_paint_hint_label.offset_top = 8.0
	_paint_hint_label.offset_bottom = 32.0
	_paint_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paint_hint_label.modulate = Color(1.0, 0.45, 0.55, 0.95)
	_paint_hint_label.visible = false
	add_child(_paint_hint_label)


func _on_self_check_pressed() -> void:
	DevToolsSelfCheck.print_report(
		true,
		_round_manager,
		_debug_join_source,
		_race_map_controller,
		_fake_viewer_simulator,
		_get_flow_analyzer_reference(),
		_get_stress_profiler_reference()
	)
	_refresh_display()


func _get_systems_node() -> Node:
	return get_node_or_null("../Systems")


func _get_flow_analyzer_reference() -> ZombieFlowAnalyzer:
	var systems: Node = _get_systems_node()
	if systems == null:
		return null
	return systems.get_node_or_null("ZombieFlowAnalyzer") as ZombieFlowAnalyzer


func _get_stress_profiler_reference() -> PerformanceStressProfiler:
	return get_node_or_null("PerformanceStressProfiler") as PerformanceStressProfiler


func _on_close_pressed() -> void:
	_close_panel()


func _on_start_race_pressed() -> void:
	if _round_manager == null:
		return
	if _round_manager.state == RoundManager.RoundState.COUNTDOWN:
		_round_manager.launch_round()
	else:
		_round_manager.start_round()
	_refresh_display()


func _on_reset_race_pressed() -> void:
	if _fake_viewer_simulator != null:
		_fake_viewer_simulator.stop_simulation()
	if _round_manager != null:
		_round_manager.reset_round()
	_refresh_display()


func _on_force_end_pressed() -> void:
	if _round_manager != null:
		_round_manager.debug_force_end_round()
	_refresh_display()


func _on_return_lobby_pressed() -> void:
	if _fake_viewer_simulator != null:
		_fake_viewer_simulator.stop_simulation()
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


func _on_load_fallthrough_lower_deck_pressed() -> void:
	_load_dev_test_map(FALLTHROUGH_LOWER_DECK_TEST_MAP_ID)


func _on_load_fallthrough_queue_twenty_pressed() -> void:
	if _load_dev_test_map(FALLTHROUGH_LOWER_DECK_TEST_MAP_ID):
		_run_simulator_batch(20)


func _load_dev_test_map(map_id: String) -> bool:
	if not OS.is_debug_build():
		push_error("Dev map tests are only available in debug/editor builds")
		_refresh_display()
		return false
	if _race_map_controller == null:
		push_error("Dev map test: RaceMapController missing")
		_refresh_display()
		return false

	if _round_manager != null:
		var state: int = _round_manager.state
		if state in [
			RoundManager.RoundState.RUNNING,
			RoundManager.RoundState.COUNTDOWN,
			RoundManager.RoundState.PAUSED,
			RoundManager.RoundState.ENDED,
		]:
			if _fake_viewer_simulator != null:
				_fake_viewer_simulator.stop_simulation()
			_round_manager.reset_round()

	var catalog_entry: Dictionary = MapCatalog.get_entry_by_id(map_id)
	if catalog_entry.is_empty() or not MapCatalog.is_prototype_testable(catalog_entry):
		push_error("Dev map test: '%s' is not a prototype-testable catalog entry" % map_id)
		_refresh_display()
		return false

	if not _race_map_controller.load_prototype_map_for_test(map_id):
		push_error(
			"DEV MAP LOAD FAILED [%s]: %s"
			% [map_id, _race_map_controller.get_last_load_failure_reason()]
		)
		_refresh_display()
		return false
	if _race_map_controller.did_last_load_use_fallback():
		push_error("DEV MAP LOAD FAILED [%s]: City Highway fallback was used" % map_id)
		_refresh_display()
		return false
	if _race_map_controller.get_resolved_map_id() != map_id:
		push_error(
			"DEV MAP LOAD FAILED [%s]: resolved '%s'"
			% [map_id, _race_map_controller.get_resolved_map_id()]
		)
		_refresh_display()
		return false

	print("DevControlPanel: dev map load succeeded for '%s'" % map_id)
	_refresh_display()
	return true


func _ensure_fake_viewer_simulator() -> void:
	_fake_viewer_simulator = get_node_or_null("FakeViewerSimulator") as FakeViewerSimulator
	if _fake_viewer_simulator == null:
		_fake_viewer_simulator = FakeViewerSimulator.new()
		_fake_viewer_simulator.name = "FakeViewerSimulator"
		add_child(_fake_viewer_simulator)
	_fake_viewer_simulator.configure(_debug_join_source, _round_manager, _zombie_manager)


func _on_simulate_five_pressed() -> void:
	_run_simulator_batch(5)


func _on_simulate_twenty_pressed() -> void:
	_run_simulator_batch(20)


func _on_simulate_hundred_pressed() -> void:
	_run_simulator_batch(100)


func _on_trickle_joins_pressed() -> void:
	_ensure_fake_viewer_simulator()
	if _fake_viewer_simulator != null:
		_fake_viewer_simulator.start_trickle_joins()
	_refresh_display()


func _on_burst_joins_pressed() -> void:
	_ensure_fake_viewer_simulator()
	if _fake_viewer_simulator != null:
		_fake_viewer_simulator.start_burst_joins()
	_refresh_display()


func _on_clear_sim_queue_pressed() -> void:
	_ensure_fake_viewer_simulator()
	if _fake_viewer_simulator != null:
		_fake_viewer_simulator.clear_simulator_queue()
	_refresh_display()


func _on_stop_simulation_pressed() -> void:
	_ensure_fake_viewer_simulator()
	if _fake_viewer_simulator != null:
		_fake_viewer_simulator.stop_simulation()
	_refresh_display()


func _run_simulator_batch(count: int) -> void:
	_ensure_fake_viewer_simulator()
	if _fake_viewer_simulator != null:
		_fake_viewer_simulator.simulate_viewers(count)
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
	_refresh_display()


func _on_flow_markers_toggled(visible: bool) -> void:
	_flow_markers_visible = visible
	var analyzer := _ensure_flow_analyzer()
	if analyzer != null:
		analyzer.set_markers_visible(visible)
	_refresh_display()


func _on_clear_flow_markers_pressed() -> void:
	var analyzer := _ensure_flow_analyzer()
	if analyzer != null:
		analyzer.clear_markers()
	_refresh_display()


func _on_print_flow_report_pressed() -> void:
	var analyzer := _ensure_flow_analyzer()
	if analyzer != null:
		analyzer.print_last_report()
	_refresh_display()


func _on_run_flow_test_pressed() -> void:
	_ensure_fake_viewer_simulator()
	var analyzer := _ensure_flow_analyzer()
	if analyzer != null:
		analyzer.set_force_enabled(true)
		_flow_analyzer_enabled = true
	if _fake_viewer_simulator != null:
		_fake_viewer_simulator.simulate_viewers(20)
	_refresh_display()


func _ensure_stress_profiler() -> PerformanceStressProfiler:
	if _stress_profiler != null and is_instance_valid(_stress_profiler):
		return _stress_profiler

	_stress_profiler = get_node_or_null("PerformanceStressProfiler") as PerformanceStressProfiler
	if _stress_profiler == null:
		_stress_profiler = PerformanceStressProfiler.new()
		_stress_profiler.name = "PerformanceStressProfiler"
		add_child(_stress_profiler)

	_ensure_fake_viewer_simulator()
	_stress_profiler.configure(
		_round_manager,
		_zombie_manager,
		_race_map_controller,
		_fake_viewer_simulator,
		_ensure_flow_analyzer(),
		get_node_or_null("../Systems/GameFlowController") as GameFlowController
	)
	return _stress_profiler


func _on_stress_twenty_pressed() -> void:
	_run_stress_test(20)


func _on_stress_hundred_pressed() -> void:
	_run_stress_test(100)


func _on_stress_two_fifty_pressed() -> void:
	_run_stress_test(250)


func _on_stress_five_hundred_pressed() -> void:
	_run_stress_test(500)


func _on_stop_stress_pressed() -> void:
	var profiler := _ensure_stress_profiler()
	if profiler != null:
		profiler.stop_stress_test()
	_refresh_display()


func _on_print_stress_report_pressed() -> void:
	var profiler := _ensure_stress_profiler()
	if profiler != null:
		profiler.print_performance_report()
	_refresh_display()


func _run_stress_test(count: int) -> void:
	var profiler := _ensure_stress_profiler()
	if profiler == null or profiler.is_stress_active():
		return
	profiler.configure(
		_round_manager,
		_zombie_manager,
		_race_map_controller,
		_fake_viewer_simulator,
		_ensure_flow_analyzer(),
		get_node_or_null("../Systems/GameFlowController") as GameFlowController
	)
	profiler.run_stress_test(count)
	_refresh_display()


func _on_blueprint_debug_toggled(enabled: bool) -> void:
	_blueprint_debug_visible = enabled
	var arena := _get_blueprint_arena()
	if arena == null:
		return
	arena.show_debug_layer = enabled
	arena.build_map()


func _add_annotation_color_row(parent: Control) -> void:
	var body: VBoxContainer
	if parent is PanelContainer:
		body = _get_card_body(parent as PanelContainer)
	else:
		body = parent as VBoxContainer
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var specs: Array = [
		["Bug", DevAnnotationPainter.SprayColor.BUG, THEME.COLOR_RED],
		["Visual", DevAnnotationPainter.SprayColor.VISUAL, THEME.COLOR_ORANGE],
		["Walk", DevAnnotationPainter.SprayColor.SHOULD_WALK, THEME.COLOR_GREEN],
	]
	for spec in specs:
		var button := Button.new()
		button.text = str(spec[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var color: DevAnnotationPainter.SprayColor = spec[1]
		var accent: Color = spec[2]
		_style_action_button(button, accent.darkened(0.55), accent)
		button.pressed.connect(_on_annotation_color_pressed.bind(color))
		row.add_child(button)
		_annotation_color_buttons[color] = button
	body.add_child(row)
	_set_annotation_color_button_states()


func _on_annotation_paint_toggled(enabled: bool) -> void:
	var painter := _ensure_annotation_painter()
	if painter == null:
		return
	if enabled and _panel_open:
		_close_panel()
	painter.set_paint_mode_enabled(enabled)
	_refresh_annotation_status()


func _on_annotation_marks_toggled(visible: bool) -> void:
	_annotation_marks_visible = visible
	var painter := _ensure_annotation_painter()
	if painter != null:
		painter.set_marks_visible(visible)
	_refresh_annotation_status()


func _on_annotation_color_pressed(color: DevAnnotationPainter.SprayColor) -> void:
	var painter := _ensure_annotation_painter()
	if painter != null:
		painter.set_spray_color(color)
	_set_annotation_color_button_states()
	_refresh_annotation_status()


func _on_annotation_note_changed(new_text: String) -> void:
	var painter := _ensure_annotation_painter()
	if painter != null:
		painter.set_note(new_text)


func _on_clear_annotation_pressed() -> void:
	var painter := _ensure_annotation_painter()
	if painter == null:
		return
	painter.clear_all_paint()
	_refresh_annotation_status()


func _on_export_annotation_pressed() -> void:
	_export_annotation_report()


func _export_annotation_report() -> void:
	var painter := _ensure_annotation_painter()
	if painter == null:
		return
	var was_panel_open: bool = _panel_open
	if was_panel_open:
		_close_panel()
	await painter.export_report(true)
	if was_panel_open:
		_open_panel()
	_refresh_annotation_status()


func _ensure_annotation_painter() -> DevAnnotationPainter:
	if _annotation_painter != null and is_instance_valid(_annotation_painter):
		return _annotation_painter

	var systems: Node = _get_systems_node()
	if systems == null:
		return null

	_annotation_painter = systems.get_node_or_null("DevAnnotationPainter") as DevAnnotationPainter
	if _annotation_painter == null:
		_annotation_painter = DevAnnotationPainter.new()
		_annotation_painter.name = "DevAnnotationPainter"
		_annotation_painter.race_world_path = NodePath("../../World")
		_annotation_painter.race_map_controller_path = NodePath("../RaceMapController")
		_annotation_painter.spectator_camera_path = NodePath("../../SpectatorCamera")
		systems.add_child(_annotation_painter)

	if not is_instance_valid(_annotation_painter):
		_annotation_painter = null
		return null

	if not _annotation_painter.paint_mode_changed.is_connected(_on_annotation_paint_mode_changed):
		_annotation_painter.paint_mode_changed.connect(_on_annotation_paint_mode_changed)
	if not _annotation_painter.strokes_changed.is_connected(_on_annotation_strokes_changed):
		_annotation_painter.strokes_changed.connect(_on_annotation_strokes_changed)
	if _annotation_note_field != null:
		_annotation_painter.set_note(_annotation_note_field.text)
	return _annotation_painter


func _on_annotation_paint_mode_changed(enabled: bool) -> void:
	_annotation_paint_enabled = enabled
	if enabled and _panel_open:
		_close_panel()
	if _annotation_paint_toggle != null:
		_annotation_paint_toggle.set_block_signals(true)
		_annotation_paint_toggle.button_pressed = enabled
		_annotation_paint_toggle.set_block_signals(false)
	if _paint_hint_label != null:
		_paint_hint_label.visible = enabled
	_refresh_annotation_status()


func _on_annotation_strokes_changed() -> void:
	_refresh_annotation_status()


func _set_annotation_color_button_states() -> void:
	var painter := _ensure_annotation_painter()
	if painter == null:
		return
	var active_color: DevAnnotationPainter.SprayColor = painter.get_spray_color()
	for color in _annotation_color_buttons.keys():
		var button: Button = _annotation_color_buttons[color]
		if button == null:
			continue
		button.disabled = color == active_color


func _refresh_annotation_status() -> void:
	if _annotation_status_label == null:
		return
	var painter := _ensure_annotation_painter()
	if painter == null:
		_annotation_status_label.text = "Paint: unavailable"
		return
	_annotation_status_label.text = painter.get_status_text()


func _ensure_flow_analyzer() -> ZombieFlowAnalyzer:
	if _flow_analyzer != null and is_instance_valid(_flow_analyzer):
		return _flow_analyzer

	var systems: Node = _get_systems_node()
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
	_refresh_dev_map_status()
	_refresh_simulator_status()
	_refresh_config_inspector()
	_refresh_flow_analyzer_status()
	_refresh_stress_profiler_status()
	_refresh_annotation_status()
	_refresh_toggle_states()


func _refresh_race_state() -> void:
	if _round_manager == null:
		if _status_state_label != null:
			_status_state_label.text = "Race: unavailable"
		if _force_end_button != null:
			_force_end_button.disabled = true
		return

	var state_text: String = _round_manager.get_state_text()
	var round_number: int = _round_manager.round_number
	if _status_state_label != null:
		_status_state_label.text = "Race: %s (#%d)" % [state_text, round_number]
	if _force_end_button != null:
		_force_end_button.disabled = _round_manager.state != RoundManager.RoundState.RUNNING
	if _clear_queue_button != null:
		_clear_queue_button.disabled = (
			_round_manager.state != RoundManager.RoundState.IDLE
			or _round_manager.get_pending_count() <= 0
		)
	_refresh_start_button_label()


func _refresh_start_button_label() -> void:
	if _round_manager == null or _race_primary_button == null:
		return
	match _round_manager.state:
		RoundManager.RoundState.COUNTDOWN:
			_race_primary_button.text = "Go"
		RoundManager.RoundState.ENDED:
			_race_primary_button.text = "Restart"
		_:
			_race_primary_button.text = "Stage"


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
		"Queued %d  •  Racing %d  •  Alive %d  •  Finished %d  •  Dead %d"
		% [queued, racing, living, finished, dead]
	)
	if _status_npc_label != null:
		_status_npc_label.text = "Racers: %d queued / %d alive" % [queued, living]


func _refresh_dev_map_status() -> void:
	if _dev_map_status_label == null:
		return
	if not OS.is_debug_build():
		_dev_map_status_label.text = "Dev map load: unavailable (release build)"
		return
	if _race_map_controller == null:
		_dev_map_status_label.text = "Dev map load: RaceMapController missing"
		return

	var active_id: String = _race_map_controller.get_resolved_map_id()
	var is_dev_map: bool = active_id == FALLTHROUGH_LOWER_DECK_TEST_MAP_ID
	var load_status: String = "idle"
	if _race_map_controller.is_prototype_test_load_active():
		load_status = "loaded" if is_dev_map else "other prototype"
	elif not _race_map_controller.get_last_load_failure_reason().is_empty():
		load_status = "failed"

	_dev_map_status_label.text = (
		"Active: %s\nStatus: %s"
		% [
			active_id if not active_id.is_empty() else "unknown",
			load_status,
		]
	)
	if _status_map_label != null:
		_status_map_label.text = "Map: %s" % (active_id if not active_id.is_empty() else "unknown")


func _refresh_simulator_status() -> void:
	if _simulator_status_label == null:
		return
	_ensure_fake_viewer_simulator()
	if _fake_viewer_simulator == null:
		_simulator_status_label.text = "Simulator: unavailable"
		return

	var running_text: String = "running" if _fake_viewer_simulator.is_running() else "stopped"
	_simulator_status_label.text = (
		"Simulator: %s | mode: %s | pending: %d | sent: %d | rejected: %d"
		% [
			running_text,
			_fake_viewer_simulator.get_mode_text(),
			_fake_viewer_simulator.get_pending_simulated_joins(),
			_fake_viewer_simulator.get_joins_sent(),
			_fake_viewer_simulator.get_joins_rejected(),
		]
	)


func _refresh_config_inspector() -> void:
	if _config_inspector_label == null:
		return
	_config_inspector_label.text = ActiveConfigInspector.build_display_text(
		_round_manager,
		_race_map_controller,
		_zombie_manager
	)


func _refresh_flow_analyzer_status() -> void:
	if _flow_status_label == null:
		return
	var analyzer := _ensure_flow_analyzer()
	if analyzer == null:
		_flow_status_label.text = "Analyzer: unavailable"
		return

	var enabled_text: String = "enabled" if analyzer.is_recording_enabled() else "disabled"
	_flow_status_label.text = (
		"Analyzer: %s | records: %d | markers: %d"
		% [enabled_text, analyzer.get_record_count(), analyzer.get_marker_count()]
	)


func _refresh_stress_profiler_status() -> void:
	if _stress_status_label == null:
		return
	var profiler := _ensure_stress_profiler()
	if profiler == null:
		_stress_status_label.text = "Profiler: unavailable"
		return
	_stress_status_label.text = "Profiler: %s" % profiler.get_status_text()


func _refresh_toggle_states() -> void:
	if _flow_toggle != null:
		var analyzer := _ensure_flow_analyzer()
		_flow_toggle.disabled = analyzer == null
		if analyzer != null:
			_flow_analyzer_enabled = analyzer.is_recording_enabled()
			_flow_toggle.set_block_signals(true)
			_flow_toggle.button_pressed = _flow_analyzer_enabled
			_flow_toggle.set_block_signals(false)

	if _flow_markers_toggle != null:
		var analyzer := _ensure_flow_analyzer()
		_flow_markers_toggle.disabled = analyzer == null
		if analyzer != null:
			_flow_markers_visible = analyzer.are_markers_visible()
			_flow_markers_toggle.set_block_signals(true)
			_flow_markers_toggle.button_pressed = _flow_markers_visible
			_flow_markers_toggle.set_block_signals(false)

	if _blueprint_debug_toggle != null:
		var arena := _get_blueprint_arena()
		_blueprint_debug_toggle.disabled = arena == null
		if arena != null:
			_blueprint_debug_visible = arena.show_debug_layer
			_blueprint_debug_toggle.set_block_signals(true)
			_blueprint_debug_toggle.button_pressed = _blueprint_debug_visible
			_blueprint_debug_toggle.set_block_signals(false)

	if _annotation_paint_toggle != null or _annotation_marks_toggle != null:
		var painter := _ensure_annotation_painter()
		if _annotation_paint_toggle != null:
			_annotation_paint_toggle.disabled = painter == null
			if painter != null:
				_annotation_paint_enabled = painter.is_paint_mode_enabled()
				_annotation_paint_toggle.set_block_signals(true)
				_annotation_paint_toggle.button_pressed = _annotation_paint_enabled
				_annotation_paint_toggle.set_block_signals(false)
		if _annotation_marks_toggle != null:
			_annotation_marks_toggle.disabled = painter == null
			if painter != null:
				_annotation_marks_visible = painter.are_marks_visible()
				_annotation_marks_toggle.set_block_signals(true)
				_annotation_marks_toggle.button_pressed = _annotation_marks_visible
				_annotation_marks_toggle.set_block_signals(false)
