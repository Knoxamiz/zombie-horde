class_name HudController
extends CanvasLayer

const STANDINGS_REFRESH_SECONDS: float = 0.25
const STANDINGS_MAX_RESULTS: int = 10

@export var round_manager_path: NodePath
@export var join_source_path: NodePath
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
var _last_visible_state: bool = false
var _standings_refresh_timer: float = 0.0
var _queued_names: PackedStringArray = PackedStringArray()
var _feed_lines: Array[String] = []
var _last_stats: Dictionary = {}

@onready var _root: Control = get_node("Root") as Control
@onready var _state_label: Label = get_node("Root/TopPanel/Margin/VBox/StateLabel") as Label
@onready var _count_label: Label = get_node("Root/TopPanel/Margin/VBox/CountLabel") as Label
@onready var _leader_label: Label = get_node("Root/TopPanel/Margin/VBox/LeaderLabel") as Label
@onready var _winner_label: Label = get_node("Root/TopPanel/Margin/VBox/WinnerLabel") as Label
@onready var _chat_status_label: Label = get_node("Root/TopPanel/Margin/VBox/ChatStatusLabel") as Label
@onready var _command_label: Label = get_node("Root/CommandLabel") as Label
@onready var _queue_label: Label = get_node("Root/RosterPanel/Margin/VBox/QueueLabel") as Label
@onready var _roster_label: Label = get_node("Root/RosterPanel/Margin/VBox/RosterLabel") as Label
@onready var _leaderboard_label: Label = get_node("Root/LeaderboardPanel/Margin/VBox/LeaderboardLabel") as Label
@onready var _countdown_panel: PanelContainer = get_node("Root/CountdownPanel") as PanelContainer
@onready var _countdown_label: Label = get_node("Root/CountdownPanel/Margin/CountdownLabel") as Label
@onready var _results_overlay: RoundResultsOverlay = get_node("Root/RoundResultsOverlay") as RoundResultsOverlay
@onready var _start_button: Button = get_node("Root/ControlPanel/Margin/HBox/StartButton") as Button
@onready var _reset_button: Button = get_node("Root/ControlPanel/Margin/HBox/ResetButton") as Button
@onready var _join_button: Button = get_node("Root/ControlPanel/Margin/HBox/JoinButton") as Button

func _ready() -> void:
	_round_manager = get_node_or_null(round_manager_path) as RoundManager
	_join_source = get_node_or_null(join_source_path) as JoinSource
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
	GameEvents.zombie_count_changed.connect(_on_zombie_count_changed)
	GameEvents.zombie_died.connect(_on_zombie_died)
	GameEvents.leader_changed.connect(_on_leader_changed)
	GameEvents.command_text_changed.connect(_on_command_text_changed)
	GameEvents.chat_connection_status_changed.connect(_on_chat_connection_status_changed)
	if _leaderboard_store != null:
		_leaderboard_store.leaderboard_changed.connect(_on_leaderboard_changed)
	if _results_overlay != null:
		_results_overlay.reset_requested.connect(_on_results_reset_requested)
	if _world_results_reset_button != null:
		_world_results_reset_button.pressed.connect(_on_world_button_pressed)

	_start_button.pressed.connect(_on_start_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_join_button.pressed.connect(_on_join_pressed)

	if _round_manager != null:
		_queued_count = _round_manager.get_pending_count()
		_state_text = _round_manager.get_state_text()
		_queued_names = _round_manager.get_pending_names()
	_countdown_panel.visible = false
	if _results_overlay != null:
		_results_overlay.hide_results(true)
	_refresh_chat_status_from_source()
	_refresh_leaderboard()
	_refresh_static_labels()
	_refresh_roster()
	_refresh_world_command_board()
	_set_world_visible(visible)
	_last_visible_state = visible

func _process(delta: float) -> void:
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
	if _round_manager != null:
		_round_manager.start_round()

func _on_reset_pressed() -> void:
	if _round_manager != null:
		_round_manager.reset_round()

func _on_join_pressed() -> void:
	var debug_source: DebugJoinSource = _join_source as DebugJoinSource
	if debug_source != null:
		debug_source.request_random_join()

func _on_round_state_changed(state_text: String) -> void:
	_state_text = state_text
	_standings_refresh_timer = 0.0
	_refresh_static_labels()
	_refresh_world_leaders_board()

func _on_round_started(round_number: int) -> void:
	_winner_text = "Winner: -"
	_results_showing = false
	if _results_overlay != null:
		_results_overlay.hide_results()
	_set_world_results_visible(false)
	if _state_label != null:
		_state_label.text = "Round %d: Running" % round_number
	_state_text = "Running"
	_standings_refresh_timer = 0.0
	_refresh_static_labels()
	_refresh_world_leaders_board()

func _on_round_reset() -> void:
	_queued_count = 0
	_queued_names = PackedStringArray()
	_feed_lines.clear()
	_last_stats.clear()
	_winner_text = "Winner: -"
	_last_winner_name = ""
	_last_base_won = false
	_results_showing = false
	_countdown_panel.visible = false
	if _results_overlay != null:
		_results_overlay.hide_results()
	_set_world_results_visible(false)
	_refresh_static_labels()
	_refresh_roster()

func _on_round_ended(winner_name: String, base_won: bool) -> void:
	_last_winner_name = winner_name
	_last_base_won = base_won
	if base_won:
		_winner_text = "Winner: Streamer Base"
	else:
		_winner_text = "Winner: %s" % winner_name
	_show_result_panel(winner_name, base_won)
	_refresh_static_labels()

func _on_participant_registered(_display_name: String, queued_count: int) -> void:
	_queued_count = queued_count
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
	_record_feed("%s - %s" % [_get_zombie_display_name(zombie_node), _format_kill_cause(cause)])
	_refresh_world_leaders_board()

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
	if _world_countdown_board != null:
		_world_countdown_board.set_board_visible(visible and seconds_remaining > 0)
		if seconds_remaining > 0:
			_world_countdown_board.set_board_text("COUNTDOWN", str(seconds_remaining))

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

func _refresh_static_labels() -> void:
	if _state_label != null:
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
		if _leaderboard_label != null:
			_leaderboard_label.text = _leaderboard_text
		_refresh_world_leaders_board()
		return

	var entries: Array = _leaderboard_store.get_entries()
	if entries.is_empty():
		_leaderboard_text = "Fastest Winners\n-"
		if _leaderboard_label != null:
			_leaderboard_label.text = _leaderboard_text
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
	if _leaderboard_label != null:
		_leaderboard_label.text = _leaderboard_text
	_refresh_world_leaders_board()

func _format_queue_text() -> String:
	if _queued_names.is_empty():
		return "Lotto: waiting for !brains"

	var names: Array[String] = []
	for queued_name in _queued_names:
		names.append(str(queued_name))
	return "Lotto: %d in | %s" % [_queued_names.size(), _join_strings(names, ", ")]

func _format_roster_text() -> String:
	if _feed_lines.is_empty():
		return "Kills:\n-"

	var lines: Array[String] = ["Kills:"]
	for feed_line in _feed_lines:
		lines.append(feed_line)
	return _join_strings(lines, "\n")

func _show_result_panel(winner_name: String, base_won: bool) -> void:
	if _results_overlay != null:
		_results_overlay.show_results(winner_name, base_won, _last_stats)
	_results_showing = true
	_refresh_world_results()
	_set_world_results_visible(visible)

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
			return "Mine"
		"minigun":
			return "Minigun"
		"base":
			return "Base"
		"obstacle":
			return "Obstacle"
		"defender":
			return "Defender"
		"sewer":
			return "Sewer"
		"out_of_bounds":
			return "Out of Bounds"
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

func _set_world_visible(should_show: bool) -> void:
	if _world_boards_root != null:
		_world_boards_root.visible = should_show
	if _root != null:
		_root.visible = false
	if not should_show:
		_set_world_results_visible(false)
		return
	_refresh_static_labels()
	_refresh_roster()
	_refresh_world_leaders_board()
	_refresh_world_command_board()
	_set_world_results_visible(_results_showing)

func _set_world_results_visible(should_show: bool) -> void:
	if _world_results_board != null:
		_world_results_board.set_board_visible(should_show)
	if _world_results_reset_button != null:
		_world_results_reset_button.visible = should_show
		_world_results_reset_button.set_interactable(should_show)

func _refresh_world_leaders_board() -> void:
	if _world_leaders_board == null:
		return

	if _is_race_live():
		_world_leaders_board.set_board_text("TOP 10 STANDINGS", _format_live_standings_body())
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
