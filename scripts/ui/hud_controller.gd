class_name HudController
extends CanvasLayer

const STANDINGS_REFRESH_SECONDS: float = 0.25
const STANDINGS_MAX_RESULTS: int = 10
const COMMAND_HINT_TEXT: String = "TYPE !BRAINS TO JOIN"

@export var round_manager_path: NodePath
@export var join_source_path: NodePath
@export var twitch_join_source_path: NodePath
@export var zombie_manager_path: NodePath

var _round_manager: RoundManager
var _twitch_join_source: TwitchJoinSource
var _zombie_manager: ZombieManager
var _queued_count: int = 0
var _living_count: int = 0
var _total_count: int = 0
var _state_text: String = "Joining"
var _chat_status_text: String = "Chat: Debug only"
var _last_visible_state: bool = false
var _refresh_timer: float = 0.0
var _queued_names: PackedStringArray = PackedStringArray()
var _feed_lines: Array[String] = []
var _last_stats: Dictionary = {}

@onready var _root: Control = get_node("Root") as Control
@onready var _status_header_label: Label = get_node("Root/TopLeft/HeaderLabel") as Label
@onready var _state_label: Label = get_node("Root/TopLeft/StateLabel") as Label
@onready var _count_label: Label = get_node("Root/TopLeft/CountLabel") as Label
@onready var _feed_header_label: Label = get_node("Root/TopRight/FeedHeaderLabel") as Label
@onready var _chat_status_label: Label = get_node("Root/BottomLeft/ChatStatusLabel") as Label
@onready var _command_label: Label = get_node("Root/BottomLeft/CommandLabel") as Label
@onready var _queue_label: Label = get_node("Root/TopRight/QueueLabel") as Label
@onready var _roster_label: Label = get_node("Root/TopRight/RosterLabel") as Label
@onready var _standings_header_label: Label = get_node("Root/BottomRight/StandingsHeaderLabel") as Label
@onready var _standings_label: Label = get_node("Root/BottomRight/StandingsLabel") as Label
@onready var _countdown_label: Label = get_node("Root/CountdownLabel") as Label
@onready var _results_overlay: RoundResultsOverlay = get_node("Root/RoundResultsOverlay") as RoundResultsOverlay

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_visual_style()

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
	GameEvents.chat_connection_status_changed.connect(_on_chat_connection_status_changed)
	if _results_overlay != null:
		_results_overlay.reset_requested.connect(_on_results_reset_requested)

	call_deferred("_finalize_setup")

func _finalize_setup() -> void:
	_force_resolve_managers()
	_sync_from_managers()
	_countdown_label.visible = false
	if _results_overlay != null:
		_results_overlay.hide_results(true)
	_refresh_chat_status_from_source()
	refresh_display()
	_last_visible_state = visible

func bind_managers(
	round_manager: RoundManager,
	zombie_manager: ZombieManager,
	twitch_join_source: TwitchJoinSource = null
) -> void:
	if round_manager != null:
		_round_manager = round_manager
	if zombie_manager != null:
		_zombie_manager = zombie_manager
	if twitch_join_source != null:
		_twitch_join_source = twitch_join_source

func refresh_display() -> void:
	_resolve_managers()
	_sync_from_managers()
	_refresh_all_labels()
	_sync_visibility()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			_resolve_managers()
			_sync_from_managers()
		_sync_visibility()
		_refresh_all_labels()

func _process(delta: float) -> void:
	if _last_visible_state != visible:
		_last_visible_state = visible
		if visible:
			_resolve_managers()
			_sync_from_managers()
		_sync_visibility()
		_refresh_all_labels()

	if not visible:
		return

	_refresh_timer += delta
	if _refresh_timer < STANDINGS_REFRESH_SECONDS:
		return
	_refresh_timer = 0.0
	_resolve_managers()
	_sync_from_managers()
	_refresh_all_labels()

func _resolve_managers() -> void:
	_force_resolve_managers()

func _force_resolve_managers() -> void:
	if _round_manager == null and not round_manager_path.is_empty():
		_round_manager = get_node_or_null(round_manager_path) as RoundManager
	if _zombie_manager == null and not zombie_manager_path.is_empty():
		_zombie_manager = get_node_or_null(zombie_manager_path) as ZombieManager
	if _twitch_join_source == null and not twitch_join_source_path.is_empty():
		_twitch_join_source = get_node_or_null(twitch_join_source_path) as TwitchJoinSource

	var systems: Node = _get_systems_node()
	if systems != null:
		if _round_manager == null:
			_round_manager = systems.get_node_or_null("RoundManager") as RoundManager
		if _zombie_manager == null:
			_zombie_manager = systems.get_node_or_null("ZombieManager") as ZombieManager
		if _twitch_join_source == null:
			_twitch_join_source = systems.get_node_or_null("TwitchJoinSource") as TwitchJoinSource

	if _round_manager == null:
		_round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
	if _zombie_manager == null:
		_zombie_manager = get_tree().get_first_node_in_group("zombie_manager") as ZombieManager

func _get_systems_node() -> Node:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return null
	return parent_node.get_node_or_null("Systems")

func _sync_from_managers() -> void:
	if _round_manager != null:
		_state_text = _round_manager.get_state_text()
		_queued_count = _round_manager.get_pending_count()
		_queued_names = _round_manager.get_pending_names()
	if _zombie_manager != null:
		_living_count = _zombie_manager.get_living_count()
		_total_count = _zombie_manager.get_total_count()

func _sync_visibility() -> void:
	if _root == null:
		return
	_root.visible = visible

func _refresh_all_labels() -> void:
	_refresh_command_hint()
	_refresh_static_labels()
	_refresh_roster()
	_refresh_standings()

func _apply_visual_style() -> void:
	BroadcastHudStyle.apply_header(_status_header_label, Color(0.94, 1, 0.58, 1))
	BroadcastHudStyle.apply_header(_feed_header_label, Color(1, 0.48, 0.34, 1))
	BroadcastHudStyle.apply_header(_standings_header_label, Color(0.94, 1, 0.58, 1))
	BroadcastHudStyle.apply_body(_state_label)
	BroadcastHudStyle.apply_body(_count_label)
	BroadcastHudStyle.apply_body(_queue_label)
	BroadcastHudStyle.apply_body(_roster_label, Color(0.92, 0.94, 0.86, 1))
	BroadcastHudStyle.apply_body(_standings_label, Color(0.92, 0.94, 0.86, 1))
	BroadcastHudStyle.apply_body(_chat_status_label, Color(0.82, 0.86, 0.76, 1))
	BroadcastHudStyle.apply_command(_command_label)
	BroadcastHudStyle.apply_countdown(_countdown_label)

func _on_round_state_changed(state_text: String) -> void:
	_state_text = state_text
	_sync_from_managers()
	_refresh_static_labels()
	_refresh_standings()

func _on_round_started(round_number: int) -> void:
	if _results_overlay != null:
		_results_overlay.hide_results()
	_state_text = "Running"
	if _state_label != null:
		_state_label.text = "Round %d | Running" % round_number
	_sync_from_managers()
	_refresh_static_labels()
	_refresh_standings()

func _on_round_reset() -> void:
	_queued_count = 0
	_queued_names = PackedStringArray()
	_feed_lines.clear()
	_last_stats.clear()
	_state_text = "Joining"
	_living_count = 0
	_total_count = 0
	_refresh_timer = 0.0
	_countdown_label.visible = false
	if _results_overlay != null:
		_results_overlay.hide_results()
	_sync_from_managers()
	_refresh_command_hint()
	_refresh_static_labels()
	_refresh_roster()
	_refresh_standings()

func _on_round_ended(winner_name: String, base_won: bool) -> void:
	_sync_from_managers()
	_refresh_standings()
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
	_refresh_standings()

func _on_zombie_died(zombie_node: Node, cause: String) -> void:
	_record_feed("%s - %s" % [_get_zombie_display_name(zombie_node), _format_kill_cause(cause)])
	_sync_from_managers()
	_refresh_standings()

func _on_leader_changed(_leader_name: String, _progress: float) -> void:
	_refresh_standings()

func _on_chat_connection_status_changed(status_text: String, detail_text: String) -> void:
	if detail_text.is_empty():
		_chat_status_text = "Chat: %s" % status_text
	else:
		_chat_status_text = "Chat: %s (%s)" % [status_text, detail_text]
	if _chat_status_label != null:
		_chat_status_label.text = _chat_status_text

func _on_round_countdown_changed(seconds_remaining: int) -> void:
	if _countdown_label == null:
		return
	_countdown_label.visible = seconds_remaining > 0
	if seconds_remaining > 0:
		_countdown_label.text = str(seconds_remaining)

func _on_round_stats_changed(stats: Dictionary) -> void:
	_last_stats = stats
	if _results_overlay != null and _results_overlay.is_showing_results():
		_results_overlay.update_stats(stats)

func _on_results_reset_requested() -> void:
	if _round_manager != null:
		_round_manager.reset_round()

func _refresh_static_labels() -> void:
	if _state_label != null:
		_state_label.text = "%s | Queued: %d" % [_state_text, _queued_count]
	if _count_label != null:
		_count_label.text = "%d alive / %d total" % [_living_count, _total_count]

func _refresh_roster() -> void:
	if _queue_label != null:
		_queue_label.text = _format_queue_text()
	if _roster_label != null:
		_roster_label.text = _format_roster_text()

func _refresh_standings() -> void:
	if _standings_label == null:
		return
	_resolve_managers()
	if _zombie_manager == null:
		_standings_label.text = "-"
		return

	var results: Array[Dictionary] = _zombie_manager.get_ranked_results(STANDINGS_MAX_RESULTS)
	if results.is_empty():
		_standings_label.text = "-"
		return

	var lines: Array[String] = []
	var max_lines: int = mini(results.size(), STANDINGS_MAX_RESULTS)
	for index in range(max_lines):
		var result: Dictionary = results[index]
		var display_name: String = str(result.get("display_name", "Zombie"))
		var progress_percent: int = int(round(float(result.get("progress", 0.0)) * 100.0))
		var alive: bool = bool(result.get("alive", false))
		var status_suffix: String = "" if alive else "  down"
		lines.append("%d. %s  %d%%%s" % [index + 1, display_name, progress_percent, status_suffix])
	_standings_label.text = _join_strings(lines, "\n")

func _refresh_command_hint() -> void:
	if _command_label != null:
		_command_label.text = COMMAND_HINT_TEXT

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
