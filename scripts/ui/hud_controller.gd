class_name HudController
extends CanvasLayer

@export var round_manager_path: NodePath
@export var join_source_path: NodePath
@export var twitch_join_source_path: NodePath
@export var leaderboard_store_path: NodePath

var _round_manager: RoundManager
var _join_source: JoinSource
var _twitch_join_source: TwitchJoinSource
var _leaderboard_store: LeaderboardStore
var _queued_count: int = 0
var _living_count: int = 0
var _total_count: int = 0
var _state_text: String = "Idle"
var _winner_text: String = "Winner: -"
var _queued_names: PackedStringArray = PackedStringArray()
var _feed_lines: Array[String] = []
var _last_stats: Dictionary = {}

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
	_refresh_static_labels()

func _on_round_started(round_number: int) -> void:
	_winner_text = "Winner: -"
	if _results_overlay != null:
		_results_overlay.hide_results()
	if _state_label != null:
		_state_label.text = "Round %d: Running" % round_number

func _on_round_reset() -> void:
	_queued_count = 0
	_queued_names = PackedStringArray()
	_feed_lines.clear()
	_last_stats.clear()
	_winner_text = "Winner: -"
	_countdown_panel.visible = false
	if _results_overlay != null:
		_results_overlay.hide_results()
	_refresh_static_labels()
	_refresh_roster()

func _on_round_ended(winner_name: String, base_won: bool) -> void:
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

func _on_zombie_died(zombie_node: Node, cause: String) -> void:
	_record_feed("%s - %s" % [_get_zombie_display_name(zombie_node), _format_kill_cause(cause)])

func _on_leader_changed(leader_name: String, progress: float) -> void:
	if _leader_label == null:
		return

	if leader_name.is_empty():
		_leader_label.text = "Leader: -"
	else:
		_leader_label.text = "Leader: %s (%d%%)" % [leader_name, int(round(progress * 100.0))]

func _on_command_text_changed(text: String) -> void:
	if _command_label != null:
		_command_label.text = text

func _on_chat_connection_status_changed(status_text: String, detail_text: String) -> void:
	if _chat_status_label == null:
		return

	if detail_text.is_empty():
		_chat_status_label.text = "Chat: %s" % status_text
	else:
		_chat_status_label.text = "Chat: %s (%s)" % [status_text, detail_text]

func _on_round_countdown_changed(seconds_remaining: int) -> void:
	if _countdown_panel == null or _countdown_label == null:
		return

	_countdown_panel.visible = seconds_remaining > 0
	if seconds_remaining > 0:
		_countdown_label.text = str(seconds_remaining)

func _on_round_stats_changed(stats: Dictionary) -> void:
	_last_stats = stats
	if _results_overlay != null and _results_overlay.is_showing_results():
		_results_overlay.update_stats(stats)

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

func _refresh_roster() -> void:
	if _queue_label != null:
		_queue_label.text = _format_queue_text()
	if _roster_label != null:
		_roster_label.text = _format_roster_text()

func _refresh_leaderboard() -> void:
	if _leaderboard_label == null:
		return

	if _leaderboard_store == null:
		_leaderboard_label.text = "Fastest Winners\n-"
		return

	var entries: Array = _leaderboard_store.get_entries()
	if entries.is_empty():
		_leaderboard_label.text = "Fastest Winners\n-"
		return

	var lines: Array[String] = ["Fastest Winners"]
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		lines.append("%d. %s  %s" % [
			index + 1,
			str(entry.get("display_name", "Zombie")),
			_format_finish_time(float(entry.get("elapsed_seconds", 0.0)))
		])
	_leaderboard_label.text = _join_strings(lines, "\n")

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
	if _chat_status_label == null:
		return

	if _twitch_join_source == null:
		_chat_status_label.text = "Chat: Debug only"
		return

	_on_chat_connection_status_changed(
		_twitch_join_source.get_status_text(),
		_twitch_join_source.get_status_detail()
	)
