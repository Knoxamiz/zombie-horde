class_name PreRoundUIController
extends CanvasLayer

signal ready_requested()
signal options_requested()
signal main_menu_requested()

@export var round_manager_path: NodePath
@export var join_source_path: NodePath
@export var twitch_join_source_path: NodePath
@export var leaderboard_store_path: NodePath
@export var feature_config: FeatureAccessConfig
@export var world_lobby_board_path: NodePath
@export var world_scores_board_path: NodePath
@export var world_ready_button_path: NodePath
@export var world_reset_button_path: NodePath
@export var world_join_button_path: NodePath
@export var world_main_menu_button_path: NodePath
@export var world_boards_root_path: NodePath

var _round_manager: RoundManager
var _join_source: JoinSource
var _twitch_join_source: TwitchJoinSource
var _leaderboard_store: LeaderboardStore
var _world_lobby_board: WorldTextBoard
var _world_scores_board: WorldTextBoard
var _world_ready_button: MainMenu3DButton
var _world_reset_button: MainMenu3DButton
var _world_join_button: MainMenu3DButton
var _world_main_menu_button: MainMenu3DButton
var _world_boards_root: Node3D
var _queued_names: PackedStringArray = PackedStringArray()
var _command_text: String = "Type !brains to join."
var _state_text: String = "Joining"

@onready var _root: Control = get_node("Root") as Control
@onready var _lobby_count_label: Label = get_node("Root/LobbyPanel/Margin/VBox/LobbyCountLabel") as Label
@onready var _lobby_names_label: Label = get_node("Root/LobbyPanel/Margin/VBox/LobbyNamesLabel") as Label
@onready var _lobby_chat_label: Label = get_node("Root/LobbyPanel/Margin/VBox/LobbyChatLabel") as Label
@onready var _ready_button: Button = get_node("Root/LobbyPanel/Margin/VBox/ReadyButton") as Button
@onready var _reset_button: HoldToConfirmButton = get_node("Root/LobbyPanel/Margin/VBox/SecondaryButtonRow/ResetButton") as HoldToConfirmButton
@onready var _lobby_join_button: Button = get_node("Root/LobbyPanel/Margin/VBox/SecondaryButtonRow/AddNpcButton") as Button
@onready var _options_button: Button = get_node("Root/OptionsButton") as Button
@onready var _main_menu_button: Button = get_node("Root/MainMenuButton") as Button
@onready var _scores_panel: PanelContainer = get_node("Root/ScoresPanel") as PanelContainer
@onready var _fastest_label: Label = get_node("Root/ScoresPanel/Margin/VBox/FastestLabel") as Label
@onready var _recent_winners_label: Label = get_node("Root/ScoresPanel/Margin/VBox/RecentWinnersLabel") as Label

func _ready() -> void:
	_round_manager = get_node_or_null(round_manager_path) as RoundManager
	_join_source = get_node_or_null(join_source_path) as JoinSource
	_twitch_join_source = get_node_or_null(twitch_join_source_path) as TwitchJoinSource
	_leaderboard_store = get_node_or_null(leaderboard_store_path) as LeaderboardStore
	_world_lobby_board = get_node_or_null(world_lobby_board_path) as WorldTextBoard
	_world_scores_board = get_node_or_null(world_scores_board_path) as WorldTextBoard
	_world_ready_button = get_node_or_null(world_ready_button_path) as MainMenu3DButton
	_world_reset_button = get_node_or_null(world_reset_button_path) as MainMenu3DButton
	_world_join_button = get_node_or_null(world_join_button_path) as MainMenu3DButton
	_world_main_menu_button = get_node_or_null(world_main_menu_button_path) as MainMenu3DButton
	_world_boards_root = get_node_or_null(world_boards_root_path) as Node3D

	_lobby_join_button.pressed.connect(_on_add_npc_pressed)
	_ready_button.pressed.connect(_on_ready_pressed)
	_reset_button.hold_confirmed.connect(_on_reset_confirmed)
	_options_button.pressed.connect(_on_options_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_connect_world_button(_world_ready_button)
	_connect_world_button(_world_reset_button)
	_connect_world_button(_world_join_button)
	_connect_world_button(_world_main_menu_button)

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
	visible = true
	if _root != null:
		_root.visible = should_show
	_set_world_visible(false)
	if should_show:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_ready_pressed() -> void:
	ready_requested.emit()

func _on_reset_confirmed() -> void:
	if _round_manager != null:
		_round_manager.reset_round()

func _on_add_npc_pressed() -> void:
	var debug_source: DebugJoinSource = _join_source as DebugJoinSource
	if debug_source != null:
		debug_source.request_random_join()

func _on_options_pressed() -> void:
	options_requested.emit()

func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()

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
	if _world_lobby_board != null:
		_world_lobby_board.set_board_text("LOBBY", _format_world_lobby_body(queue_summary, command_text))
	_refresh_ready_button()

func _refresh_scoreboards() -> void:
	var fastest_text: String = _format_fastest_times()
	var recent_text: String = _format_recent_winners()
	if _fastest_label != null:
		_fastest_label.text = fastest_text
	if _recent_winners_label != null:
		_recent_winners_label.text = recent_text
	if _world_scores_board != null:
		_world_scores_board.set_board_text("SCORES", "%s\n\n%s" % [_format_world_fastest_times(), _format_world_recent_winners()])

func _format_fastest_times() -> String:
	if _leaderboard_store == null:
		return "FASTEST RUNS\n—"

	var entries: Array = _leaderboard_store.get_entries()
	if entries.is_empty():
		return "FASTEST RUNS\n—"

	var lines: Array[String] = ["FASTEST RUNS", _board_column_header("TIME")]
	var max_entries: int = mini(entries.size(), 8)
	for index in range(max_entries):
		if typeof(entries[index]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entries[index]
		lines.append(_format_board_row(
			index + 1,
			str(entry.get("display_name", "Zombie")),
			_format_finish_time(float(entry.get("elapsed_seconds", 0.0)))
		))
	return _join_strings(lines, "\n")

func _format_recent_winners() -> String:
	if _leaderboard_store == null:
		return "RECENT WINNERS\n—"

	var entries: Array = _leaderboard_store.get_recent_winners()
	if entries.is_empty():
		return "RECENT WINNERS\n—"

	var lines: Array[String] = ["RECENT WINNERS", _board_column_header("TIME")]
	var max_entries: int = mini(entries.size(), 8)
	for index in range(max_entries):
		if typeof(entries[index]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entries[index]
		var display_name: String = "Streamer Base" if bool(entry.get("base_won", false)) else str(entry.get("display_name", "Zombie"))
		lines.append(_format_board_row(
			index + 1,
			display_name,
			_format_finish_time(float(entry.get("elapsed_seconds", 0.0)))
		))
	return _join_strings(lines, "\n")

func _board_column_header(value_label: String) -> String:
	var name_text: String = "RUNNER"
	while name_text.length() < 15:
		name_text += " "
	return "  #  %s %s" % [name_text, value_label]

func _format_board_row(rank: int, display_name: String, value_text: String) -> String:
	var name_text: String = display_name
	if name_text.length() > 14:
		name_text = "%s…" % name_text.substr(0, 13)
	while name_text.length() < 15:
		name_text += " "
	return "%2d.  %s %s" % [rank, name_text, value_text]

func _format_queue_summary() -> String:
	if _queued_names.is_empty():
		return "Waiting for players — type !brains in chat"
	return "%d player(s) in lobby" % _queued_names.size()

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

	var can_ready: bool = _state_text == "Joining" and not _queued_names.is_empty()
	_ready_button.disabled = not can_ready
	if _queued_names.is_empty():
		_ready_button.text = "Ready"
	else:
		_ready_button.text = "Ready (%d)" % _queued_names.size()
	if _world_ready_button != null:
		_world_ready_button.set_button_text(_ready_button.text.to_upper())
		_world_ready_button.set_interactable(can_ready)
	if _main_menu_button != null:
		_main_menu_button.disabled = _state_text != "Joining"
	if _world_main_menu_button != null:
		_world_main_menu_button.set_interactable(_state_text == "Joining")
	if _world_reset_button != null:
		_world_reset_button.set_interactable(true)
	if _world_join_button != null:
		_world_join_button.set_interactable(true)

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

func _connect_world_button(button: MainMenu3DButton) -> void:
	if button == null:
		return
	if not button.pressed.is_connected(_on_world_button_pressed):
		button.pressed.connect(_on_world_button_pressed)

func _on_world_button_pressed(action_id: StringName) -> void:
	match action_id:
		&"ready":
			_on_ready_pressed()
		&"reset":
			_on_reset_confirmed()
		&"add_join":
			_on_add_npc_pressed()
		&"main_menu":
			_on_main_menu_pressed()

func _set_world_visible(should_show: bool) -> void:
	if _world_boards_root != null:
		_world_boards_root.visible = should_show
	_set_world_buttons_interactable(should_show)
	if should_show:
		_refresh_labels()
		_refresh_scoreboards()

func _set_world_buttons_interactable(enabled: bool) -> void:
	var buttons: Array[MainMenu3DButton] = [
		_world_ready_button,
		_world_reset_button,
		_world_join_button,
		_world_main_menu_button,
	]
	for button in buttons:
		if button != null:
			button.set_interactable(enabled)

func _format_world_lobby_body(queue_summary: String, command_text: String) -> String:
	var names_text: String = _format_world_lobby_names()
	if names_text == "-":
		names_text = "No players yet."
	return "%s\n\n%s\n\n%s" % [queue_summary, names_text, command_text]

func _format_world_lobby_names() -> String:
	if _queued_names.is_empty():
		return "-"

	var lines: Array[String] = []
	var max_names: int = mini(_queued_names.size(), 8)
	for index in range(0, max_names, 2):
		var line_names: Array[String] = [str(_queued_names[index])]
		if index + 1 < max_names:
			line_names.append(str(_queued_names[index + 1]))
		lines.append(_join_strings(line_names, ", "))
	if _queued_names.size() > max_names:
		lines.append("+%d more" % (_queued_names.size() - max_names))
	return _join_strings(lines, "\n")

func _format_world_fastest_times() -> String:
	if _leaderboard_store == null:
		return "Fastest Times\n-"

	var entries: Array = _leaderboard_store.get_entries()
	if entries.is_empty():
		return "Fastest Times\n-"

	var lines: Array[String] = ["Fastest Times"]
	var max_entries: int = mini(entries.size(), 5)
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

func _format_world_recent_winners() -> String:
	if _leaderboard_store == null:
		return "Recent Winners\n-"

	var entries: Array = _leaderboard_store.get_recent_winners()
	if entries.is_empty():
		return "Recent Winners\n-"

	var lines: Array[String] = ["Recent Winners"]
	var max_entries: int = mini(entries.size(), 5)
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
