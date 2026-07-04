class_name PodiumOverlay
extends Control

signal continue_requested()
signal reset_requested()

var _tween: Tween

@onready var _card: PanelContainer = get_node("PodiumCard") as PanelContainer
@onready var _accent_bar: ColorRect = get_node("PodiumCard/Margin/VBox/AccentBar") as ColorRect
@onready var _title_label: Label = get_node("PodiumCard/Margin/VBox/TitleLabel") as Label
@onready var _subtitle_label: Label = get_node("PodiumCard/Margin/VBox/SubtitleLabel") as Label
@onready var _podium_row: HBoxContainer = get_node("PodiumCard/Margin/VBox/PodiumRow") as HBoxContainer
@onready var _empty_label: Label = get_node("PodiumCard/Margin/VBox/EmptyLabel") as Label
@onready var _stats_button: Button = get_node("PodiumCard/Margin/VBox/ButtonRow/ViewStatsButton") as Button
@onready var _return_button: Button = get_node("PodiumCard/Margin/VBox/ButtonRow/ReturnLobbyButton") as Button


func _ready() -> void:
	_stats_button.pressed.connect(_on_view_stats_pressed)
	_return_button.pressed.connect(_on_return_lobby_pressed)
	hide_podium(true)


func show_podium(winner_name: String, base_won: bool, stats: Dictionary, zombie_manager: ZombieManager = null) -> void:
	_refresh(winner_name, base_won, stats, zombie_manager)

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_card.scale = Vector2(0.95, 0.95)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_podium(immediate: bool = false) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	if immediate:
		visible = false
		modulate.a = 0.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.14)
	_tween.tween_callback(_finish_hide)


func is_showing_podium() -> bool:
	return visible


func _finish_hide() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh(
	winner_name: String,
	base_won: bool,
	stats: Dictionary,
	zombie_manager: ZombieManager
) -> void:
	for child in _podium_row.get_children():
		child.queue_free()

	var accent_color: Color = Color(0.54, 1.0, 0.28, 1.0) if base_won else Color(1.0, 0.62, 0.12, 1.0)
	_accent_bar.color = accent_color
	_title_label.text = "BASE HOLDS!" if base_won else "ZOMBIE WINS!"
	_title_label.add_theme_color_override("font_color", accent_color)

	var elapsed_seconds: float = float(stats.get("elapsed_seconds", 0.0))
	if base_won:
		_subtitle_label.text = "Top 3 closest zombies  |  %s" % _format_finish_time(elapsed_seconds)
	else:
		_subtitle_label.text = "%s takes the base  |  %s" % [winner_name, _format_finish_time(elapsed_seconds)]

	var podium_entries: Array[Dictionary] = PodiumResultsBuilder.build_top_three(
		winner_name,
		base_won,
		stats,
		zombie_manager
	)
	var display_order: Array[Dictionary] = PodiumResultsBuilder.get_podium_display_order(podium_entries)
	_empty_label.visible = display_order.is_empty()

	for entry in display_order:
		var slot: PodiumSlot = PodiumSlot.new()
		slot.setup(entry)
		_podium_row.add_child(slot)


func _format_finish_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--.--s"
	return "%.2fs" % seconds


func _on_view_stats_pressed() -> void:
	continue_requested.emit()


func _on_return_lobby_pressed() -> void:
	reset_requested.emit()
