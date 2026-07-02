class_name RacePresentationOverlay
extends CanvasLayer

@export var banner_hold_seconds: float = 0.9
@export var leader_change_hold_seconds: float = 0.85
@export var event_hold_seconds: float = 1.65

var _last_leader_name: String = ""
var _weapon_toast_cooldown: float = 0.0
var _banner_tween: Tween
var _toast_tween: Tween
var _leader_flash_tween: Tween

@onready var _leader_strip: PanelContainer = get_node("Root/LeaderStrip") as PanelContainer
@onready var _leader_name_label: Label = get_node("Root/LeaderStrip/Margin/VBox/LeaderRow/LeaderNameLabel") as Label
@onready var _leader_progress_label: Label = get_node("Root/LeaderStrip/Margin/VBox/LeaderRow/LeaderProgressLabel") as Label
@onready var _leader_progress_bar: ProgressBar = get_node("Root/LeaderStrip/Margin/VBox/LeaderProgressBar") as ProgressBar
@onready var _banner_panel: PanelContainer = get_node("Root/BannerPanel") as PanelContainer
@onready var _banner_title_label: Label = get_node("Root/BannerPanel/Margin/VBox/BannerTitleLabel") as Label
@onready var _banner_subtitle_label: Label = get_node("Root/BannerPanel/Margin/VBox/BannerSubtitleLabel") as Label
@onready var _toast_panel: PanelContainer = get_node("Root/EventToast") as PanelContainer
@onready var _toast_label: Label = get_node("Root/EventToast/Margin/ToastLabel") as Label

func _ready() -> void:
	GameEvents.round_state_changed.connect(_on_round_state_changed)
	GameEvents.round_countdown_changed.connect(_on_round_countdown_changed)
	GameEvents.round_started.connect(_on_round_started)
	GameEvents.round_ended.connect(_on_round_ended)
	GameEvents.round_reset.connect(_on_round_reset)
	GameEvents.participant_registered.connect(_on_participant_registered)
	GameEvents.leader_changed.connect(_on_leader_changed)
	GameEvents.zombie_died.connect(_on_zombie_died)
	GameEvents.zombie_became_crawler.connect(_on_zombie_became_crawler)
	GameEvents.zombie_reached_base.connect(_on_zombie_reached_base)
	GameEvents.mine_triggered.connect(_on_mine_triggered)
	GameEvents.boost_pad_triggered.connect(_on_boost_pad_triggered)
	GameEvents.human_defender_fired.connect(_on_human_defender_fired)
	GameEvents.minigun_fired.connect(_on_minigun_fired)

	_leader_strip.visible = false
	_banner_panel.visible = false
	_toast_panel.visible = false
	_leader_progress_bar.min_value = 0.0
	_leader_progress_bar.max_value = 100.0

func _process(delta: float) -> void:
	if _weapon_toast_cooldown > 0.0:
		_weapon_toast_cooldown = max(0.0, _weapon_toast_cooldown - delta)

func _on_round_state_changed(state_text: String) -> void:
	if state_text == "Running":
		_leader_strip.visible = true
	elif state_text == "Joining":
		_reset_overlay()

func _on_round_countdown_changed(seconds_remaining: int) -> void:
	if seconds_remaining <= 0:
		return

	var subtitle: String = "ZOMBIES LOCKED IN"
	if seconds_remaining <= 2:
		subtitle = "GET READY"
	_show_banner(str(seconds_remaining), subtitle, Color(1.0, 0.78, 0.16, 1.0), banner_hold_seconds)

func _on_round_started(round_number: int) -> void:
	_last_leader_name = ""
	_leader_strip.visible = true
	_show_banner("RELEASE THE HORDE", "ROUND %d IS LIVE" % round_number, Color(0.62, 1.0, 0.25, 1.0), 1.1)
	_show_toast("The lotto is running.")

func _on_round_ended(winner_name: String, base_won: bool) -> void:
	_leader_strip.visible = false
	if base_won:
		_show_banner("BASE HOLDS", "No zombie survived the run.", Color(0.62, 1.0, 0.25, 1.0), 1.25)
	else:
		_show_banner("%s WINS" % winner_name.to_upper(), "FIRST TO THE BASE", Color(1.0, 0.64, 0.12, 1.0), 1.25)

func _on_round_reset() -> void:
	_reset_overlay()

func _on_participant_registered(display_name: String, queued_count: int) -> void:
	if queued_count <= 1:
		_show_toast("%s entered the cage." % display_name)
	elif queued_count % 10 == 0:
		_show_toast("%d zombies in the lotto." % queued_count)

func _on_leader_changed(leader_name: String, progress: float) -> void:
	if leader_name.is_empty():
		_leader_name_label.text = "NO LEADER"
		_leader_progress_label.text = "0%"
		_leader_progress_bar.value = 0.0
		return

	var progress_percent: int = int(round(progress * 100.0))
	_leader_name_label.text = leader_name
	_leader_progress_label.text = "%d%%" % progress_percent
	_leader_progress_bar.value = float(progress_percent)
	_leader_strip.visible = true

	if leader_name != _last_leader_name:
		_last_leader_name = leader_name
		_flash_leader_strip()
		_show_toast("%s takes the lead." % leader_name, leader_change_hold_seconds)

func _on_zombie_died(zombie_node: Node, cause: String) -> void:
	var zombie: Zombie = zombie_node as Zombie
	var display_name: String = zombie.display_name if zombie != null else "Zombie"
	_show_toast("%s dropped: %s" % [display_name, _format_cause(cause)])

func _on_zombie_became_crawler(zombie_node: Node, _cause: String) -> void:
	var zombie: Zombie = zombie_node as Zombie
	if zombie != null:
		_show_toast("%s is still crawling." % zombie.display_name)

func _on_zombie_reached_base(zombie_node: Node) -> void:
	var zombie: Zombie = zombie_node as Zombie
	if zombie != null:
		_show_toast("%s breached the base." % zombie.display_name)

func _on_mine_triggered(target_name: String, _world_position: Vector3) -> void:
	_show_toast("%s hit a mine." % target_name, 1.0)

func _on_boost_pad_triggered(target_name: String, _world_position: Vector3) -> void:
	_show_toast("%s found a boost." % target_name, 1.0)

func _on_human_defender_fired(_defender_name: String, target_name: String, hit: bool) -> void:
	if hit and _weapon_toast_cooldown <= 0.0:
		_show_toast("Defender tagged %s." % target_name, 0.9)
		_weapon_toast_cooldown = 1.2

func _on_minigun_fired(target_name: String, hit: bool) -> void:
	if hit and _weapon_toast_cooldown <= 0.0:
		_show_toast("Minigun tagged %s." % target_name, 0.9)
		_weapon_toast_cooldown = 1.2

func _show_banner(title: String, subtitle: String, accent_color: Color, hold_seconds: float) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()

	_banner_title_label.text = title
	_banner_subtitle_label.text = subtitle
	_banner_title_label.add_theme_color_override("font_color", accent_color)
	_banner_panel.visible = true
	_banner_panel.modulate.a = 0.0
	_banner_panel.scale = Vector2(0.9, 0.9)

	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_panel, "modulate:a", 1.0, 0.12)
	_banner_tween.parallel().tween_property(_banner_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(max(hold_seconds, 0.05))
	_banner_tween.tween_property(_banner_panel, "modulate:a", 0.0, 0.18)
	_banner_tween.tween_callback(_hide_banner)

func _show_toast(text: String, hold_seconds: float = -1.0) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0
	_toast_panel.position.x = 18.0

	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.12)
	_toast_tween.parallel().tween_property(_toast_panel, "position:x", 32.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(event_hold_seconds if hold_seconds < 0.0 else hold_seconds)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.18)
	_toast_tween.tween_callback(_hide_toast)

func _flash_leader_strip() -> void:
	if _leader_flash_tween != null and _leader_flash_tween.is_valid():
		_leader_flash_tween.kill()

	_leader_strip.scale = Vector2(1.02, 1.02)
	_leader_flash_tween = create_tween()
	_leader_flash_tween.tween_property(_leader_strip, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_banner() -> void:
	_banner_panel.visible = false

func _hide_toast() -> void:
	_toast_panel.visible = false

func _reset_overlay() -> void:
	_last_leader_name = ""
	_leader_strip.visible = false
	_banner_panel.visible = false
	_toast_panel.visible = false

func _format_cause(cause: String) -> String:
	match cause:
		"mine":
			return "Mine"
		"minigun":
			return "Minigun"
		"defender":
			return "Defender"
		"sewer":
			return "Sewer"
		"out_of_bounds":
			return "Out of Bounds"
	return cause.capitalize()
