class_name PreRoundUIController
extends CanvasLayer

signal ready_requested()
signal settings_requested()

@export var round_manager_path: NodePath
@export var join_source_path: NodePath
@export var twitch_join_source_path: NodePath
@export var leaderboard_store_path: NodePath
@export var feature_config: FeatureAccessConfig

var _round_manager: RoundManager
var _join_source: JoinSource
var _twitch_join_source: TwitchJoinSource
var _leaderboard_store: LeaderboardStore
var _queued_names: PackedStringArray = PackedStringArray()
var _command_text: String = "Type !brains to join."
var _state_text: String = "Joining"

@onready var _root: Control = get_node("Root") as Control
@onready var _lobby_panel: PanelContainer = get_node("Root/LobbyPanel") as PanelContainer
@onready var _lobby_count_label: Label = get_node("Root/LobbyPanel/Margin/VBox/LobbyCountLabel") as Label
@onready var _lobby_names_label: Label = get_node("Root/LobbyPanel/Margin/VBox/LobbyNamesLabel") as Label
@onready var _lobby_chat_label: Label = get_node("Root/LobbyPanel/Margin/VBox/LobbyChatLabel") as Label
@onready var _ready_button: Button = get_node("Root/LobbyPanel/Margin/VBox/ButtonRow/ReadyButton") as Button
@onready var _reset_button: Button = get_node("Root/LobbyPanel/Margin/VBox/ButtonRow/ResetButton") as Button
@onready var _lobby_join_button: Button = get_node("Root/LobbyPanel/Margin/VBox/ButtonRow/AddJoinButton") as Button
@onready var _settings_button: Button = get_node("Root/LobbyPanel/Margin/VBox/ButtonRow/SettingsButton") as Button
@onready var _cage_board_panel: PanelContainer = get_node("Root/CageBoardPanel") as PanelContainer
@onready var _fastest_label: Label = get_node("Root/CageBoardPanel/Margin/VBox/FastestLabel") as Label
@onready var _recent_winners_label: Label = get_node("Root/CageBoardPanel/Margin/VBox/RecentWinnersLabel") as Label

func _ready() -> void:
	_round_manager = get_node_or_null(round_manager_path) as RoundManager
	_join_source = get_node_or_null(join_source_path) as JoinSource
	_twitch_join_source = get_node_or_null(twitch_join_source_path) as TwitchJoinSource
	_leaderboard_store = get_node_or_null(leaderboard_store_path) as LeaderboardStore

	_lobby_join_button.pressed.connect(_on_add_join_pressed)
	_ready_button.pressed.connect(_on_ready_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)

	GameEvents.participant_queue_changed.connect(_on_participant_queue_changed)
	GameEvents.command_text_changed.connect(_on_command_text_changed)
	GameEvents.chat_connection_status_changed.connect(_on_chat_connection_status_changed)
	GameEvents.round_state_changed.connect(_on_round_state_changed)
	if _leaderboard_store != null:
		_leaderboard_store.leaderboard_changed.connect(_on_leaderboard_changed)

	if _round_manager != null:
		_queued_names = _round_manager.get_pending_names()
		_state_text = _round_manager.get_state_text()
	_refresh_chat_status_from_source()
	_refresh_labels()
	_refresh_scoreboards()

func set_screen_mode(mode: String) -> void:
	var should_show: bool = mode != "hidden"
	visible = should_show
	if _root != null:
		_root.visible = should_show
	if _lobby_panel != null:
		_lobby_panel.visible = should_show
	if _cage_board_panel != null:
		_cage_board_panel.visible = should_show
	if should_show:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_ready_pressed() -> void:
	ready_requested.emit()

func _on_reset_pressed() -> void:
	if _round_manager != null:
		_round_manager.reset_round()

func _on_add_join_pressed() -> void:
	var debug_source: DebugJoinSource = _join_source as DebugJoinSource
	if debug_source != null:
		debug_source.request_random_join()

func _on_settings_pressed() -> void:
	if not _can_open_settings():
		return
	settings_requested.emit()

func _on_participant_queue_changed(display_names: PackedStringArray) -> void:
	_queued_names = display_names
	_refresh_labels()

func _on_command_text_changed(text: String) -> void:
	_command_text = text
	_refresh_labels()

func _on_chat_connection_status_changed(status_text: String, detail_text: String) -> void:
	if detail_text.is_empty():
		_command_text = "Chat: %s" % status_text
	else:
		_command_text = "Chat: %s (%s)" % [status_text, detail_text]
	_refresh_labels()

func _on_round_state_changed(state_text: String) -> void:
	_state_text = state_text
	_refresh_labels()

func _on_leaderboard_changed(_entries: Array) -> void:
	_refresh_scoreboards()

func _refresh_labels() -> void:
	var queue_summary: String = _format_queue_summary()
	var command_text: String = _command_text
	if command_text.is_empty():
		command_text = "Type !brains to join."

	if _lobby_count_label != null:
		_lobby_count_label.text = queue_summary
	if _lobby_names_label != null:
		_lobby_names_label.text = _format_lobby_names()
	if _lobby_chat_label != null:
		_lobby_chat_label.text = command_text
	_refresh_ready_button()

func _refresh_scoreboards() -> void:
	if _fastest_label != null:
		_fastest_label.text = _format_fastest_times()
	if _recent_winners_label != null:
		_recent_winners_label.text = _format_recent_winners()

func _format_fastest_times() -> String:
	if _leaderboard_store == null:
		return "Fastest Times\n-"

	var entries: Array = _leaderboard_store.get_entries()
	if entries.is_empty():
		return "Fastest Times\n-"

	var lines: Array[String] = ["Fastest Times"]
	var max_entries: int = mini(entries.size(), 10)
	for index in range(max_entries):
		if typeof(entries[index]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entries[index]
		lines.append("%d. %s  %s" % [
			index + 1,
			str(entry.get("display_name", "Zombie")),
			_format_finish_time(float(entry.get("elapsed_seconds", 0.0)))
		])
	return _join_strings(lines, "\n")

func _format_recent_winners() -> String:
	if _leaderboard_store == null:
		return "Last 10 Winners\n-"

	var entries: Array = _leaderboard_store.get_recent_winners()
	if entries.is_empty():
		return "Last 10 Winners\n-"

	var lines: Array[String] = ["Last 10 Winners"]
	var max_entries: int = mini(entries.size(), 10)
	for index in range(max_entries):
		if typeof(entries[index]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entries[index]
		var display_name: String = "Streamer Base" if bool(entry.get("base_won", false)) else str(entry.get("display_name", "Zombie"))
		lines.append("%d. %s  %s" % [
			index + 1,
			display_name,
			_format_finish_time(float(entry.get("elapsed_seconds", 0.0)))
		])
	return _join_strings(lines, "\n")

func _format_queue_summary() -> String:
	if _queued_names.is_empty():
		return "Cage empty - waiting for !brains"
	return "%d zombies shaking the cage" % _queued_names.size()

func _format_lobby_names() -> String:
	if _queued_names.is_empty():
		return "-"

	var names: Array[String] = []
	var max_names: int = mini(_queued_names.size(), 8)
	for index in range(max_names):
		names.append(str(_queued_names[index]))
	if _queued_names.size() > max_names:
		names.append("+%d more" % (_queued_names.size() - max_names))
	return _join_strings(names, ", ")

func _refresh_ready_button() -> void:
	if _ready_button == null:
		return

	_ready_button.disabled = _state_text != "Joining" or _queued_names.is_empty()
	if _queued_names.is_empty():
		_ready_button.text = "Ready"
	else:
		_ready_button.text = "Ready (%d)" % _queued_names.size()
	if _settings_button != null:
		_settings_button.visible = _can_open_settings()
		_settings_button.disabled = not _can_open_settings()

func _join_strings(values: Array[String], separator: String) -> String:
	var result: String = ""
	for index in range(values.size()):
		if index > 0:
			result += separator
		result += values[index]
	return result

func _format_finish_time(seconds: float) -> String:
	return "%.2fs" % max(seconds, 0.0)

func _refresh_chat_status_from_source() -> void:
	if _twitch_join_source == null:
		_command_text = "Type !brains to join."
		return

	var status_text: String = _twitch_join_source.get_status_text()
	var detail_text: String = _twitch_join_source.get_status_detail()
	_on_chat_connection_status_changed(status_text, detail_text)

func _can_open_settings() -> bool:
	return feature_config != null and feature_config.can_use_streamer_settings()
