class_name LeaderboardMenuController
extends CanvasLayer

@export var leaderboard_store_path: NodePath

var _leaderboard_store: LeaderboardStore

@onready var _root: Control = get_node("Root") as Control
@onready var _fastest_label: Label = get_node("Root/Panel/Margin/VBox/FastestLabel") as Label
@onready var _close_button: Button = get_node("Root/Panel/Margin/VBox/ButtonRow/CloseButton") as Button
@onready var _dim: ColorRect = get_node("Root/Dim") as ColorRect

func _ready() -> void:
	_leaderboard_store = get_node_or_null(leaderboard_store_path) as LeaderboardStore
	_close_button.pressed.connect(close_menu)
	_dim.gui_input.connect(_on_dim_gui_input)
	if _leaderboard_store != null:
		_leaderboard_store.leaderboard_changed.connect(_on_leaderboard_changed)
	visible = false
	if _root != null:
		_root.visible = false

func open_menu() -> void:
	_refresh_fastest_times()
	visible = true
	if _root != null:
		_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_menu() -> void:
	visible = false
	if _root != null:
		_root.visible = false

func is_open() -> bool:
	return visible and _root != null and _root.visible

func _on_leaderboard_changed(_entries: Array) -> void:
	if is_open():
		_refresh_fastest_times()

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_menu()

func _refresh_fastest_times() -> void:
	if _fastest_label == null:
		return
	_fastest_label.text = _format_fastest_times()

func _format_fastest_times() -> String:
	if _leaderboard_store == null:
		return "—"

	var entries: Array = _leaderboard_store.get_entries()
	if entries.is_empty():
		return "—"

	var lines: Array[String] = [_board_column_header("TIME")]
	var max_entries: int = mini(entries.size(), 10)
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

func _format_finish_time(seconds: float) -> String:
	return "%.2fs" % max(seconds, 0.0)

func _join_strings(values: Array[String], separator: String) -> String:
	var result: String = ""
	for index in range(values.size()):
		if index > 0:
			result += separator
		result += values[index]
	return result
