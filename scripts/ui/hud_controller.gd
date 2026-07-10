class_name HudController
extends CanvasLayer

signal layout_edit_finished(save_changes: bool)
signal main_menu_requested()

const STANDINGS_REFRESH_SECONDS: float = 0.25
const STANDINGS_MAX_RESULTS: int = 10
const LAYOUT_EDITOR_SCRIPT := preload("res://scripts/ui/hud_layout_editor.gd")
const HUD_LAYOUT_PROFILE := preload("res://scripts/ui/hud_layout_profile.gd")

const PANEL_PATHS: Dictionary = {
	"top": "Root/TopPanel",
	"roster": "Root/RosterPanel",
	"leaderboard": "Root/LeaderboardPanel",
	"command": "Root/CommandPanel",
	"countdown": "Root/CountdownPanel",
}

@export var round_manager_path: NodePath
@export var join_source_path: NodePath
@export var debug_join_source_path: NodePath
@export var twitch_join_source_path: NodePath
@export var leaderboard_store_path: NodePath
@export var zombie_manager_path: NodePath
@export var world_status_board_path: NodePath
@export var world_feed_board_path: NodePath
@export var world_leaders_board_path: NodePath
@export var world_command_board_path: NodePath
@export var world_countdown_board_path: NodePath
@export var world_results_board_path: NodePath
@export var world_results_reset_button_path: NodePath
@export var world_boards_root_path: NodePath

var _round_manager: RoundManager
var _join_source: JoinSource
var _debug_join_source: DebugJoinSource
var _twitch_join_source: TwitchJoinSource
var _leaderboard_store: LeaderboardStore
var _zombie_manager: ZombieManager
var _world_status_board: WorldTextBoard
var _world_feed_board: WorldTextBoard
var _world_leaders_board: WorldTextBoard
var _world_command_board: WorldTextBoard
var _world_countdown_board: WorldTextBoard
var _world_results_board: WorldTextBoard
var _world_results_reset_button: MainMenu3DButton
var _world_boards_root: Node3D
var _queued_count: int = 0
var _living_count: int = 0
var _total_count: int = 0
var _state_text: String = "Idle"
var _leader_text: String = "Leader: -"
var _winner_text: String = "Winner: -"
var _chat_status_text: String = "Chat: Debug only"
var _command_text: String = "Type !brains to join."
var _leaderboard_text: String = "Fastest Winners\n-"
var _last_winner_name: String = ""
var _last_base_won: bool = false
var _results_showing: bool = false
var _podium_showing: bool = false
var _last_visible_state: bool = false
var _standings_refresh_timer: float = 0.0
var _queued_names: PackedStringArray = PackedStringArray()
var _feed_lines: Array[String] = []
var _last_stats: Dictionary = {}
var _round_number: int = 0
var _auto_reset_seconds_remaining: int = 0
var _layout_profile
var _layout_editor
var _layout_edit_active: bool = false
var _layout_edit_snapshot
var _pre_round_hidden_for_layout_edit: bool = false
var _hud_layer_before_layout_edit: int = 6
var _hud_visible_before_layout_edit: bool = false

@onready var _root: Control = get_node("Root") as Control
@onready var _screen_wash: ColorRect = get_node("Root/ScreenWash") as ColorRect
@onready var _state_label: Label = get_node("Root/TopPanel/Margin/VBox/StateLabel") as Label
@onready var _count_label: Label = get_node("Root/TopPanel/Margin/VBox/CountLabel") as Label
@onready var _leader_label: Label = get_node("Root/TopPanel/Margin/VBox/LeaderLabel") as Label
@onready var _winner_label: Label = get_node("Root/TopPanel/Margin/VBox/WinnerLabel") as Label
@onready var _chat_status_label: Label = get_node("Root/TopPanel/Margin/VBox/ChatStatusLabel") as Label
@onready var _command_label: Label = get_node("Root/CommandPanel/Margin/VBox/CommandLabel") as Label
@onready var _queue_label: Label = get_node("Root/RosterPanel/Margin/VBox/QueueLabel") as Label
@onready var _roster_label: Label = get_node("Root/RosterPanel/Margin/VBox/RosterLabel") as Label
@onready var _standings_header_label: Label = (
	get_node("Root/LeaderboardPanel/Margin/VBox/HeaderBar/HeaderLabel") as Label
)
@onready var _leaderboard_label: Label = get_node("Root/LeaderboardPanel/Margin/VBox/LeaderboardLabel") as Label
@onready var _countdown_panel: HudLayoutPanel = get_node("Root/CountdownPanel") as HudLayoutPanel
@onready var _countdown_label: Label = get_node("Root/CountdownPanel/Margin/VBox/CountdownLabel") as Label
@onready var _podium_overlay: PodiumOverlay = get_node("Root/PodiumOverlay") as PodiumOverlay
@onready var _results_overlay: RoundResultsOverlay = get_node("Root/RoundResultsOverlay") as RoundResultsOverlay
@onready var _start_button: Button = get_node("Root/ControlPanel/Margin/HBox/StartButton") as Button
@onready var _reset_button: Button = get_node("Root/ControlPanel/Margin/HBox/ResetButton") as Button
@onready var _join_button: Button = get_node("Root/ControlPanel/Margin/HBox/JoinButton") as Button
@onready var _hold_reset_button: HoldToConfirmButton = get_node("Root/HoldResetButton") as HoldToConfirmButton
@onready var _main_menu_button: Button = get_node("Root/MainMenuButton") as Button

func _ready() -> void:
	_round_manager = get_node_or_null(round_manager_path) as RoundManager
	_join_source = get_node_or_null(join_source_path) as JoinSource
	_debug_join_source = get_node_or_null(debug_join_source_path) as DebugJoinSource
	_twitch_join_source = get_node_or_null(twitch_join_source_path) as TwitchJoinSource
	_leaderboard_store = get_node_or_null(leaderboard_store_path) as LeaderboardStore
	_zombie_manager = get_node_or_null(zombie_manager_path) as ZombieManager
	if _zombie_manager == null:
		var systems: Node = get_parent().get_node_or_null("Systems")
		if systems != null:
			_zombie_manager = systems.get_node_or_null("ZombieManager") as ZombieManager
	_world_status_board = get_node_or_null(world_status_board_path) as WorldTextBoard
	_world_feed_board = get_node_or_null(world_feed_board_path) as WorldTextBoard
	_world_leaders_board = get_node_or_null(world_leaders_board_path) as WorldTextBoard
	_world_command_board = get_node_or_null(world_command_board_path) as WorldTextBoard
	_world_countdown_board = get_node_or_null(world_countdown_board_path) as WorldTextBoard
	_world_results_board = get_node_or_null(world_results_board_path) as WorldTextBoard
	_world_results_reset_button = get_node_or_null(world_results_reset_button_path) as MainMenu3DButton
	_world_boards_root = get_node_or_null(world_boards_root_path) as Node3D

	if _root != null:
		_root.visible = false

	GameEvents.round_state_changed.connect(_on_round_state_changed)
	GameEvents.round_started.connect(_on_round_started)
	GameEvents.round_reset.connect(_on_round_reset)
	GameEvents.round_ended.connect(_on_round_ended)
	GameEvents.round_countdown_changed.connect(_on_round_countdown_changed)
	GameEvents.round_stats_changed.connect(_on_round_stats_changed)
	GameEvents.participant_registered.connect(_on_participant_registered)
	GameEvents.participant_queue_changed.connect(_on_participant_queue_changed)
	GameEvents.join_rejected.connect(_on_join_rejected)
	GameEvents.join_accepted_late.connect(_on_join_accepted_late)
	GameEvents.post_round_auto_reset_tick.connect(_on_post_round_auto_reset_tick)
	GameEvents.zombie_count_changed.connect(_on_zombie_count_changed)
	GameEvents.zombie_died.connect(_on_zombie_died)
	GameEvents.zombie_status_changed.connect(_on_zombie_status_changed)
	GameEvents.leader_changed.connect(_on_leader_changed)
	GameEvents.command_text_changed.connect(_on_command_text_changed)
	GameEvents.chat_connection_status_changed.connect(_on_chat_connection_status_changed)
	if _leaderboard_store != null:
		_leaderboard_store.leaderboard_changed.connect(_on_leaderboard_changed)
	if _podium_overlay != null:
		_podium_overlay.continue_requested.connect(_on_podium_continue_requested)
		_podium_overlay.restart_requested.connect(_on_restart_same_race_requested)
		_podium_overlay.reset_requested.connect(_on_results_reset_requested)
	if _results_overlay != null:
		_results_overlay.restart_requested.connect(_on_restart_same_race_requested)
		_results_overlay.reset_requested.connect(_on_results_reset_requested)
	if _world_results_reset_button != null:
		_world_results_reset_button.pressed.connect(_on_world_button_pressed)

	_start_button.pressed.connect(_on_start_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	if _hold_reset_button != null:
		_hold_reset_button.hold_confirmed.connect(_on_hold_reset_confirmed)
	if _main_menu_button != null:
		_main_menu_button.pressed.connect(_on_main_menu_pressed)

	if _round_manager != null:
		_queued_count = _round_manager.get_pending_count()
		_state_text = _round_manager.get_state_text()
		_queued_names = _round_manager.get_pending_names()
	_countdown_panel.visible = false
	if _podium_overlay != null:
		_podium_overlay.hide_podium(true)
	if _results_overlay != null:
		_results_overlay.hide_results(true)
	_refresh_chat_status_from_source()
	_refresh_leaderboard()
	_refresh_static_labels()
	_refresh_roster()
	_refresh_world_command_board()
	_setup_layout_editor()
	_apply_saved_layout()
	_set_world_visible(visible)
	_last_visible_state = visible
	apply_stream_capture_visuals()

func apply_stream_capture_visuals() -> void:
	var game_settings: GameSettingsController = get_node_or_null("/root/GameSettings") as GameSettingsController
	if game_settings == null or _screen_wash == null:
		return
	_screen_wash.visible = not game_settings.should_hide_screen_wash()

func _setup_layout_editor() -> void:
	_layout_editor = LAYOUT_EDITOR_SCRIPT.new()
	if _layout_editor == null:
		return
	_layout_editor.name = "LayoutEditor"
	add_child(_layout_editor)
	_layout_editor.setup(self)
	_layout_editor.finished.connect(_on_layout_edit_finished)

func _apply_saved_layout() -> void:
	var viewport_size: Vector2 = _get_layout_viewport_size()
	_layout_profile = HUD_LAYOUT_PROFILE.load_from_disk(viewport_size)
	if not _layout_profile.is_valid_for_viewport(viewport_size):
		_layout_profile = HUD_LAYOUT_PROFILE.create_default_profile(viewport_size)
	_layout_profile.apply_to(self)


func _get_layout_viewport_size() -> Vector2:
	if _root != null:
		return _root.get_rect().size
	return get_viewport().get_visible_rect().size

func get_layout_panel(panel_id: String) -> HudLayoutPanel:
	var path: String = str(PANEL_PATHS.get(panel_id, ""))
	if path.is_empty():
		return null
	return get_node_or_null(path) as HudLayoutPanel

func begin_layout_edit() -> void:
	var viewport_size: Vector2 = _get_layout_viewport_size()
	_layout_profile = HUD_LAYOUT_PROFILE.load_from_disk(viewport_size)
	if not _layout_profile.is_valid_for_viewport(viewport_size):
		_layout_profile = HUD_LAYOUT_PROFILE.create_default_profile(viewport_size)
		_layout_profile.apply_to(self)
	_layout_edit_snapshot = HUD_LAYOUT_PROFILE.capture_from(self)
	_layout_edit_active = true
	_hud_visible_before_layout_edit = visible
	_hud_layer_before_layout_edit = layer
	layer = 15
	visible = true
	_hide_pre_round_ui_for_layout_edit()
	_populate_layout_preview()
	_ensure_layout_panels_visible_for_edit()
	if _podium_overlay != null:
		_podium_overlay.hide_podium(true)
	if _results_overlay != null:
		_results_overlay.hide_results(true)
	_set_race_control_buttons_visible(false)
	if _root != null:
		_root.visible = true
		_root.move_to_front()
	call_deferred("_begin_layout_editor_deferred")

func _begin_layout_editor_deferred() -> void:
	if not _layout_edit_active or _layout_editor == null:
		return
	_layout_editor.begin()

func _ensure_layout_panels_visible_for_edit() -> void:
	for panel_id in PANEL_PATHS.keys():
		var panel: HudLayoutPanel = get_layout_panel(panel_id)
		if panel == null:
			continue
		if panel_id == "countdown":
			panel.visible = false
			if _countdown_label != null:
				_countdown_label.text = "3"
			continue
		panel.visible = true

func end_layout_edit(save_changes: bool) -> void:
	if _layout_editor != null:
		_layout_editor.end()
	if save_changes:
		_layout_profile = HUD_LAYOUT_PROFILE.capture_from(self)
		_layout_profile.save_to_disk()
	else:
		_layout_edit_snapshot.apply_to(self)
	_layout_edit_active = false
	layer = _hud_layer_before_layout_edit
	visible = _hud_visible_before_layout_edit
	_restore_pre_round_ui_after_layout_edit()
	_set_race_control_buttons_visible(true)
	_set_world_visible(visible)

func _hide_pre_round_ui_for_layout_edit() -> void:
	var pre_round: PreRoundUIController = get_parent().get_node_or_null("PreRoundUI") as PreRoundUIController
	if pre_round == null:
		return
	_pre_round_hidden_for_layout_edit = pre_round.visible
	if _pre_round_hidden_for_layout_edit:
		pre_round.set_screen_mode("hidden")

func _restore_pre_round_ui_after_layout_edit() -> void:
	if not _pre_round_hidden_for_layout_edit:
		return
	var pre_round: PreRoundUIController = get_parent().get_node_or_null("PreRoundUI") as PreRoundUIController
	if pre_round != null:
		pre_round.set_screen_mode("lobby")
	_pre_round_hidden_for_layout_edit = false

func reset_layout_to_defaults() -> void:
	HUD_LAYOUT_PROFILE.clear_saved_layout()
	_layout_profile = HUD_LAYOUT_PROFILE.create_default_profile(_get_layout_viewport_size())
	_layout_profile.apply_to(self)

func is_layout_edit_active() -> bool:
	return _layout_edit_active

func _on_layout_edit_finished(save_changes: bool) -> void:
	end_layout_edit(save_changes)
	layout_edit_finished.emit(save_changes)

func _populate_layout_preview() -> void:
	_state_text = "Running"
	_queued_count = 2
	_queued_names = PackedStringArray(["Ada", "HexHunger"])
	_living_count = 8
	_total_count = 13
	_leader_text = "Leader: GlitchGnaw (71%)"
	_winner_text = "Winner: -"
	_chat_status_text = "Chat: Twitch live (#knoxamiz)"
	_command_text = "Type !brains to join."
	_feed_lines = [
		"PixelMunch - Out of Bounds",
		"EchoRot - Sewer",
		"Ada - Out of Bounds",
	]
	_refresh_static_labels()
	_refresh_roster()
	if _standings_header_label != null:
		_standings_header_label.text = "TOP 10 STANDINGS"
	if _leaderboard_label != null:
		_leaderboard_label.text = "1. GlitchGnaw 100%\n2. DoomSprint 83% down\n3. HexHunger 71% down\n4. Ada 48%\n5. CaptainDecay 41%"
	if _command_label != null:
		_command_label.text = _command_text

func _process(delta: float) -> void:
	if _layout_edit_active:
		return

	if _last_visible_state != visible:
		_last_visible_state = visible
		_set_world_visible(visible)

	if not visible or not _is_race_live():
		return

	_standings_refresh_timer += delta
	if _standings_refresh_timer < STANDINGS_REFRESH_SECONDS:
		return
	_standings_refresh_timer = 0.0
	_refresh_world_leaders_board()

func _on_start_pressed() -> void:
	if _round_manager == null:
		return
	if _round_manager.state == RoundManager.RoundState.ENDED:
		_on_restart_same_race_requested()
	else:
		_round_manager.start_round()

func _on_reset_pressed() -> void:
	if _round_manager != null:
		_round_manager.reset_round()

func _on_hold_reset_confirmed() -> void:
	_on_reset_pressed()

func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()

func _on_join_pressed() -> void:
	var debug_source: DebugJoinSource = _get_debug_join_source()
	if debug_source != null:
		debug_source.request_random_join()

func _get_debug_join_source() -> DebugJoinSource:
	if _debug_join_source != null:
		return _debug_join_source
	return _join_source as DebugJoinSource

func _on_round_state_changed(state_text: String) -> void:
	_state_text = state_text
	_standings_refresh_timer = 0.0
	_refresh_static_labels()
	_refresh_world_leaders_board()

func _on_round_started(round_number: int) -> void:
	_round_number = round_number
	_winner_text = "Winner: -"
	_results_showing = false
	_podium_showing = false
	if _podium_overlay != null:
		_podium_overlay.hide_podium()
	if _results_overlay != null:
		_results_overlay.hide_results()
	_set_world_results_visible(false)
	_record_feed(
		"GO! Round %d is live — %d zombies racing."
		% [round_number, max(_total_count, _living_count)]
	)
	_state_text = "Running"
	_standings_refresh_timer = 0.0
	_refresh_static_labels()
	_refresh_world_leaders_board()

func _on_round_reset() -> void:
	_round_number = 0
	_auto_reset_seconds_remaining = 0
	_queued_count = 0
	_queued_names = PackedStringArray()
	_feed_lines.clear()
	_last_stats.clear()
	_winner_text = "Winner: -"
	_last_winner_name = ""
	_last_base_won = false
	_results_showing = false
	_podium_showing = false
	_countdown_panel.visible = false
	if _podium_overlay != null:
		_podium_overlay.hide_podium()
	if _results_overlay != null:
		_results_overlay.hide_results()
	_set_world_results_visible(false)
	_refresh_static_labels()
	_refresh_roster()

func _on_round_ended(winner_name: String, base_won: bool) -> void:
	_last_winner_name = winner_name
	_last_base_won = base_won
	if _round_manager != null and _round_manager.is_auto_repeat_enabled():
		_results_showing = false
		_podium_showing = false
		if _podium_overlay != null:
			_podium_overlay.hide_podium(true)
		if _results_overlay != null:
			_results_overlay.hide_results(true)
		_set_world_results_visible(false)
		_refresh_static_labels()
		return
	var timed_out: bool = _round_manager != null and _round_manager.is_race_timed_out()
	if timed_out:
		_record_feed(StreamerFeedbackMessages.format_time_limit_feed(winner_name, base_won))
		if base_won:
			_winner_text = "Winner: Streamer Base (time limit)"
		else:
			_winner_text = "Winner: %s (time limit)" % winner_name
	elif base_won:
		_winner_text = "Winner: Streamer Base"
		_record_feed("RACE OVER — Base holds! No zombie reached the streamer base.")
	else:
		_winner_text = "Winner: %s" % winner_name
		_record_feed("RACE OVER — %s reached the streamer base!" % winner_name)
	_show_result_panel(winner_name, base_won, timed_out)
	_refresh_static_labels()

func _on_participant_registered(join_info: ParticipantJoinInfo, queued_count: int) -> void:
	_queued_count = queued_count
	if _state_text == "Countdown":
		return
	var display_name: String = join_info.display_name.strip_edges() if join_info != null else ""
	if not display_name.is_empty() and _state_text == "Joining":
		_record_feed("+ %s joined queue (%d waiting)" % [display_name, queued_count])
	_refresh_static_labels()


func _on_join_rejected(display_name: String, reason: String) -> void:
	_record_feed(StreamerFeedbackMessages.format_join_rejected(display_name, reason))


func _on_join_accepted_late(display_name: String) -> void:
	_record_feed(StreamerFeedbackMessages.format_join_accepted_late(display_name))


func _on_post_round_auto_reset_tick(seconds_remaining: int) -> void:
	_auto_reset_seconds_remaining = max(seconds_remaining, 0)
	if _auto_reset_seconds_remaining > 0:
		_command_text = StreamerFeedbackMessages.format_auto_reset_command(_auto_reset_seconds_remaining)
		if _command_label != null:
			_command_label.text = _command_text
		_refresh_world_command_board()
	_refresh_static_labels()

func _on_participant_queue_changed(display_names: PackedStringArray) -> void:
	_queued_names = display_names
	_queued_count = display_names.size()
	_refresh_static_labels()
	_refresh_roster()

func _on_zombie_count_changed(living_count: int, total_count: int) -> void:
	_living_count = living_count
	_total_count = total_count
	_refresh_static_labels()
	_refresh_world_leaders_board()

func _on_zombie_died(zombie_node: Node, cause: String) -> void:
	_record_feed("%s — %s" % [_get_zombie_display_name(zombie_node), _format_kill_cause(cause)])
	_refresh_world_leaders_board()


func _on_zombie_status_changed(display_name: String, status: String) -> void:
	if status.begins_with("Finished #"):
		_record_feed("%s %s — reached the base!" % [display_name, status.to_upper()])
		return
	if status == "Winner":
		_record_feed("%s WINS THE RACE!" % display_name)
		return
	if status == "Winner (time limit)":
		_record_feed("TIME LIMIT — %s led on progress!" % display_name)
		return
	if status == "DNF (time limit)":
		_record_feed("%s did not finish in time" % display_name)

func _on_leader_changed(leader_name: String, progress: float) -> void:
	if leader_name.is_empty():
		_leader_text = "Leader: -"
	else:
		_leader_text = "Leader: %s (%d%%)" % [leader_name, int(round(progress * 100.0))]
	if _leader_label != null:
		_leader_label.text = _leader_text
	_refresh_static_labels()

func _on_command_text_changed(text: String) -> void:
	_command_text = text
	if _command_label != null:
		_command_label.text = text
	_refresh_world_command_board()

func _on_chat_connection_status_changed(status_text: String, detail_text: String) -> void:
	if detail_text.is_empty():
		_chat_status_text = "Chat: %s" % status_text
	else:
		_chat_status_text = "Chat: %s (%s)" % [status_text, detail_text]
	if _chat_status_label != null:
		_chat_status_label.text = _chat_status_text
	_refresh_static_labels()

func _on_round_countdown_changed(seconds_remaining: int) -> void:
	if _countdown_panel == null or _countdown_label == null:
		return

	_countdown_panel.visible = seconds_remaining > 0
	if seconds_remaining > 0:
		_countdown_label.text = str(seconds_remaining)
		if seconds_remaining == 1:
			_record_feed("Get ready...")
	if _world_countdown_board != null:
		_world_countdown_board.set_board_visible(false)

func _on_round_stats_changed(stats: Dictionary) -> void:
	_last_stats = stats
	if _results_overlay != null and _results_overlay.is_showing_results():
		_results_overlay.update_stats(stats)
	if _results_showing:
		_refresh_world_results()

func _on_leaderboard_changed(_entries: Array) -> void:
	_refresh_leaderboard()

func _on_results_reset_requested() -> void:
	if _round_manager != null:
		_round_manager.reset_round()


func _on_restart_same_race_requested() -> void:
	if _round_manager == null:
		return
	if not _round_manager.restart_same_race():
		return
	_results_showing = false
	_podium_showing = false
	if _podium_overlay != null:
		_podium_overlay.hide_podium()
	if _results_overlay != null:
		_results_overlay.hide_results()
	_set_world_results_visible(false)
	_refresh_static_labels()

func _refresh_static_labels() -> void:
	if _state_label != null:
		match _state_text:
			"Running":
				if _round_number > 0:
					_state_label.text = "Round %d | LIVE | Queued: %d" % [_round_number, _queued_count]
				else:
					_state_label.text = "Round LIVE | Queued: %d" % _queued_count
			"Countdown":
				_state_label.text = "Round starting... | Queued: %d" % _queued_count
			"Ended":
				if _auto_reset_seconds_remaining > 0:
					_state_label.text = (
						"Race over | Auto-reset in %ds | Queued: %d"
						% [_auto_reset_seconds_remaining, _queued_count]
					)
				else:
					_state_label.text = "Race over | Queued: %d" % _queued_count
			_:
				_state_label.text = "State: %s | Queued: %d" % [_state_text, _queued_count]
	if _count_label != null:
		_count_label.text = "Zombies: %d alive / %d total" % [_living_count, _total_count]
	if _winner_label != null:
		_winner_label.text = _winner_text
	if _world_status_board != null:
		_world_status_board.set_board_text("RACE STATUS", _format_world_status_body())

func _refresh_roster() -> void:
	if _queue_label != null:
		_queue_label.text = _format_queue_text()
	if _roster_label != null:
		_roster_label.text = _format_roster_text()
	if _world_feed_board != null:
		_world_feed_board.set_board_text("LIVE FEED", "%s\n\n%s" % [_format_queue_text(), _format_roster_text()])

func _refresh_leaderboard() -> void:
	if _leaderboard_store == null:
		_leaderboard_text = "Fastest Winners\n-"
		_refresh_world_leaders_board()
		return

	var entries: Array = _leaderboard_store.get_entries()
	if entries.is_empty():
		_leaderboard_text = "Fastest Winners\n-"
		_refresh_world_leaders_board()
		return

	var lines: Array[String] = ["Fastest Winners"]
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		lines.append("%d. %s  %s" % [
			index + 1,
			str(entry.get("display_name", "Zombie")),
			_format_finish_time(float(entry.get("elapsed_seconds", 0.0)))
		])
	_leaderboard_text = _join_strings(lines, "\n")
	_refresh_world_leaders_board()

func _format_queue_text() -> String:
	if _queued_names.is_empty():
		if _state_text in ["Running", "Countdown", "Ended"]:
			return "Queue: joins reopen after reset"
		return "Queue: waiting for !brains"

	var names: Array[String] = []
	for queued_name in _queued_names:
		names.append(str(queued_name))
	return "Queue: %d waiting | %s" % [_queued_names.size(), _join_strings(names, ", ")]

func _format_roster_text() -> String:
	if _feed_lines.is_empty():
		return "Race feed:\n(waiting for action)"

	var lines: Array[String] = ["Race feed:"]
	for feed_line in _feed_lines:
		lines.append(feed_line)
	return _join_strings(lines, "\n")

func _show_result_panel(winner_name: String, base_won: bool, timed_out: bool = false) -> void:
	_results_showing = true
	_podium_showing = true
	_refresh_world_results()
	_set_podium_visible(true, timed_out)

func _on_podium_continue_requested() -> void:
	_podium_showing = false
	if _podium_overlay != null:
		_podium_overlay.hide_podium()
	_set_world_results_visible(true)
	_refresh_post_round_recovery_hint()

func _refresh_post_round_recovery_hint() -> void:
	if _round_manager == null or _round_manager.state != RoundManager.RoundState.ENDED:
		return
	if _auto_reset_seconds_remaining > 0:
		_command_text = StreamerFeedbackMessages.format_auto_reset_command(_auto_reset_seconds_remaining)
	elif _round_manager.round_config != null and _round_manager.round_config.post_round_auto_reset_seconds > 0.0:
		_command_text = StreamerFeedbackMessages.format_auto_reset_command(
			int(round(_round_manager.round_config.post_round_auto_reset_seconds))
		)
	else:
		_command_text = "Next race: Press Enter to restart, or R to return to lobby."
	if _command_label != null:
		_command_label.text = _command_text
	_refresh_world_command_board()

func _join_strings(values: Array[String], separator: String) -> String:
	var result: String = ""
	for index in range(values.size()):
		if index > 0:
			result += separator
		result += values[index]
	return result

func _record_feed(line: String) -> void:
	_feed_lines.insert(0, line)
	while _feed_lines.size() > 8:
		_feed_lines.remove_at(_feed_lines.size() - 1)
	_refresh_roster()

func _get_zombie_display_name(zombie_node: Node) -> String:
	var zombie: Zombie = zombie_node as Zombie
	if zombie != null:
		return zombie.display_name
	if zombie_node != null:
		return zombie_node.name
	return "Zombie"

func _format_kill_cause(cause: String) -> String:
	match cause:
		"mine":
			return "killed by mine"
		"minigun":
			return "shot by minigun"
		"base":
			return "stopped at base"
		"obstacle":
			return "hit obstacle"
		"defender":
			return "stopped by defender"
		"sewer":
			return "fell in sewer"
		"fell":
			return "fell off track"
		"out_of_bounds":
			return "left the lane"
	return cause.capitalize()

func _format_finish_time(seconds: float) -> String:
	return "%.2fs" % max(seconds, 0.0)

func _refresh_chat_status_from_source() -> void:
	if _twitch_join_source == null:
		_chat_status_text = "Chat: Debug only"
		if _chat_status_label != null:
			_chat_status_label.text = _chat_status_text
		return

	_on_chat_connection_status_changed(
		_twitch_join_source.get_status_text(),
		_twitch_join_source.get_status_detail()
	)

func _on_world_button_pressed(action_id: StringName) -> void:
	if action_id == &"reset":
		_on_results_reset_requested()

func _set_race_control_buttons_visible(should_show: bool) -> void:
	if _hold_reset_button != null:
		_hold_reset_button.visible = should_show
	if _main_menu_button != null:
		_main_menu_button.visible = should_show

func _set_world_visible(should_show: bool) -> void:
	if _world_boards_root != null:
		_world_boards_root.visible = false
	if _root != null:
		_root.visible = should_show or _layout_edit_active
	if not should_show and not _layout_edit_active:
		_set_podium_visible(false)
		_set_world_results_visible(false)
		return
	_refresh_static_labels()
	_refresh_roster()
	_refresh_world_leaders_board()
	_refresh_world_command_board()
	_set_podium_visible(_podium_showing)
	_set_world_results_visible(_results_showing and not _podium_showing)

func _set_world_results_visible(should_show: bool) -> void:
	if _world_results_board != null:
		_world_results_board.set_board_visible(false)
	if _world_results_reset_button != null:
		_world_results_reset_button.visible = false
		_world_results_reset_button.set_interactable(false)
	if _podium_showing:
		should_show = false
	if _results_overlay != null:
		if should_show:
			_results_overlay.show_results(_last_winner_name, _last_base_won, _last_stats)
		else:
			_results_overlay.hide_results()


func _set_podium_visible(should_show: bool, timed_out: bool = false) -> void:
	if _podium_overlay == null:
		return
	if should_show:
		_podium_overlay.show_podium(_last_winner_name, _last_base_won, _last_stats, _zombie_manager, timed_out)
	else:
		_podium_overlay.hide_podium()

func _refresh_world_leaders_board() -> void:
	if _is_race_live():
		var live_body: String = _format_live_standings_body()
		if _standings_header_label != null:
			_standings_header_label.text = "TOP 10 STANDINGS"
		if _leaderboard_label != null:
			_leaderboard_label.text = live_body
		if _world_leaders_board != null:
			_world_leaders_board.set_board_text("TOP 10 STANDINGS", live_body)
		return

	var body: String = _leaderboard_text
	if body.begins_with("Fastest Winners\n"):
		body = body.substr("Fastest Winners\n".length())
	var source_lines: PackedStringArray = body.split("\n")
	var board_lines: Array[String] = []
	var max_lines: int = mini(source_lines.size(), 8)
	for index in range(max_lines):
		board_lines.append(source_lines[index])
	body = _join_strings(board_lines, "\n")
	if body.is_empty() or body == "-":
		body = "—"
	if _standings_header_label != null:
		_standings_header_label.text = "FASTEST WINNERS"
	if _leaderboard_label != null:
		_leaderboard_label.text = body
	if _world_leaders_board != null:
		_world_leaders_board.set_board_text("FASTEST WINNERS", body)

func _format_live_standings_body() -> String:
	if _zombie_manager == null:
		return "-"

	var results: Array[Dictionary] = _zombie_manager.get_ranked_results(STANDINGS_MAX_RESULTS)
	if results.is_empty():
		return "-"

	var lines: Array[String] = []
	var max_lines: int = mini(results.size(), STANDINGS_MAX_RESULTS)
	for index in range(max_lines):
		var result: Dictionary = results[index]
		var display_name: String = str(result.get("display_name", "Zombie"))
		var progress_percent: int = int(round(float(result.get("progress", 0.0)) * 100.0))
		var alive: bool = bool(result.get("alive", false))
		var status_suffix: String = "" if alive else " down"
		lines.append("%d. %s %d%%%s" % [index + 1, display_name, progress_percent, status_suffix])
	return _join_strings(lines, "\n")

func _is_race_live() -> bool:
	return _state_text in ["Countdown", "Running", "Ended"]

func _refresh_world_command_board() -> void:
	if _world_command_board != null:
		_world_command_board.set_board_text("CHAT COMMAND", _command_text)

func _refresh_world_results() -> void:
	if _world_results_board == null:
		return
	_world_results_board.set_board_text("ROUND RESULTS", _format_world_results_body())

func _format_world_status_body() -> String:
	return "State: %s | Queued: %d\nZombies: %d alive / %d total\n%s\n%s\n%s" % [
		_state_text,
		_queued_count,
		_living_count,
		_total_count,
		_leader_text,
		_winner_text,
		_chat_status_text
	]

func _format_world_results_body() -> String:
	var winner_name: String = "Streamer Base" if _last_base_won else _last_winner_name
	if winner_name.is_empty():
		winner_name = "-"

	var lines: Array[String] = ["Winner: %s" % winner_name]
	if not _last_stats.is_empty():
		lines.append("")
		for key in _last_stats.keys():
			lines.append("%s: %s" % [str(key).capitalize(), str(_last_stats[key])])
	return _join_strings(lines, "\n")
