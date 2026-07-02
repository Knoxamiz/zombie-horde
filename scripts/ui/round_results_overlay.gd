class_name RoundResultsOverlay
extends Control

signal reset_requested()

var _current_winner_name: String = ""
var _current_base_won: bool = false
var _current_stats: Dictionary = {}
var _tween: Tween

@onready var _card: PanelContainer = get_node("ResultCard") as PanelContainer
@onready var _accent_bar: ColorRect = get_node("ResultCard/Margin/VBox/AccentBar") as ColorRect
@onready var _title_label: Label = get_node("ResultCard/Margin/VBox/TitleLabel") as Label
@onready var _winner_label: Label = get_node("ResultCard/Margin/VBox/WinnerLabel") as Label
@onready var _summary_label: Label = get_node("ResultCard/Margin/VBox/SummaryLabel") as Label
@onready var _runner_ups_label: Label = get_node("ResultCard/Margin/VBox/Columns/RunnerUpsPanel/Margin/RunnerUpsLabel") as Label
@onready var _stats_label: Label = get_node("ResultCard/Margin/VBox/Columns/StatsPanel/Margin/StatsLabel") as Label
@onready var _return_button: Button = get_node("ResultCard/Margin/VBox/ButtonRow/ReturnLobbyButton") as Button

func _ready() -> void:
	_return_button.pressed.connect(_on_return_lobby_pressed)
	hide_results(true)

func show_results(winner_name: String, base_won: bool, stats: Dictionary) -> void:
	_current_winner_name = winner_name
	_current_base_won = base_won
	_current_stats = stats.duplicate(true)
	_refresh()

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_card.scale = Vector2(0.97, 0.97)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_results(immediate: bool = false) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	if immediate:
		visible = false
		modulate.a = 0.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_tween.tween_callback(_finish_hide)

func is_showing_results() -> bool:
	return visible

func update_stats(stats: Dictionary) -> void:
	if not visible:
		return

	_current_stats = stats.duplicate(true)
	_refresh()

func _finish_hide() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh() -> void:
	var elapsed_seconds: float = float(_current_stats.get("elapsed_seconds", 0.0))
	var participant_count: int = int(_current_stats.get("participants_started", 0))
	var living_count: int = int(_current_stats.get("living_count", 0))
	var title: String = "BASE HOLDS!" if _current_base_won else "ZOMBIE WINS!"
	var winner_name: String = "Streamer Base" if _current_base_won else _current_winner_name
	var accent_color: Color = Color(0.54, 1.0, 0.28, 1.0) if _current_base_won else Color(1.0, 0.62, 0.12, 1.0)

	_accent_bar.color = accent_color
	_title_label.text = title
	_title_label.add_theme_color_override("font_color", accent_color)
	_winner_label.text = winner_name
	_summary_label.text = "%d entered | %d survived | %s" % [
		participant_count,
		living_count,
		_format_finish_time(elapsed_seconds)
	]
	_runner_ups_label.text = _format_runner_ups(_current_stats.get("runner_up_results", []), _current_base_won)
	_stats_label.text = _format_stats()

func _format_runner_ups(raw_results: Variant, base_won: bool) -> String:
	var heading: String = "Closest Zombies" if base_won else "Runner-Ups"
	if typeof(raw_results) != TYPE_ARRAY:
		return "%s\n-" % heading

	var results: Array = raw_results
	if results.is_empty():
		return "%s\n-" % heading

	var lines: Array[String] = [heading]
	var max_results: int = mini(results.size(), 4)
	for index in range(max_results):
		if typeof(results[index]) != TYPE_DICTIONARY:
			continue

		var result: Dictionary = results[index]
		var display_name: String = str(result.get("display_name", "Zombie"))
		var progress_percent: int = int(round(float(result.get("progress", 0.0)) * 100.0))
		var state_suffix: String = "alive" if bool(result.get("alive", false)) else "down"
		lines.append("%d. %s  %d%%  %s" % [index + 1, display_name, progress_percent, state_suffix])
	return _join_strings(lines, "\n")

func _format_stats() -> String:
	var mine_triggers: int = int(_current_stats.get("mine_triggers", 0))
	var mine_kills: int = int(_current_stats.get("mine_kills", 0))
	var minigun_shots: int = int(_current_stats.get("minigun_shots", 0))
	var minigun_hits: int = int(_current_stats.get("minigun_hits", 0))
	var crawlers: int = int(_current_stats.get("crawlers_created", 0))
	var kill_causes: String = _format_kill_causes(_current_stats.get("kill_causes", {}))

	return "Round Damage\nKills by source:\n%s\n\nMines: %d launches, %d kills\nMinigun: %d/%d hits\nCrawlers made: %d" % [
		kill_causes,
		mine_triggers,
		mine_kills,
		minigun_hits,
		minigun_shots,
		crawlers
	]

func _format_kill_causes(raw_causes: Variant) -> String:
	if typeof(raw_causes) != TYPE_DICTIONARY:
		return "-"

	var causes: Dictionary = raw_causes
	if causes.is_empty():
		return "-"

	var entries: Array[String] = []
	for cause in causes.keys():
		entries.append("%s: %d" % [_format_cause(str(cause)), int(causes[cause])])
	entries.sort()
	return _join_strings(entries, "\n")

func _format_cause(cause: String) -> String:
	match cause:
		"mine":
			return "Mine"
		"minigun":
			return "Minigun"
		"base":
			return "Base"
		"defender":
			return "Defender"
		"sewer":
			return "Sewer"
		"out_of_bounds":
			return "Out of Bounds"
		"obstacle":
			return "Obstacle"
		"unknown":
			return "Unknown"
	return cause.capitalize()

func _format_finish_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--.--s"
	return "%.2fs" % seconds

func _join_strings(values: Array[String], separator: String) -> String:
	var result: String = ""
	for index in range(values.size()):
		if index > 0:
			result += separator
		result += values[index]
	return result

func _on_return_lobby_pressed() -> void:
	reset_requested.emit()
