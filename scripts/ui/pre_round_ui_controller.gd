class_name PreRoundUIController
extends CanvasLayer

signal ready_requested()
signal options_requested()
signal main_menu_requested()

const MAX_JOIN_FEED_LINES: int = 12

@export var round_manager_path: NodePath
@export var join_source_path: NodePath
@export var debug_join_source_path: NodePath
@export var twitch_join_source_path: NodePath
@export var leaderboard_store_path: NodePath
@export var feature_config: FeatureAccessConfig

var _round_manager: RoundManager
var _join_source: JoinSource
var _debug_join_source: DebugJoinSource
var _twitch_join_source: TwitchJoinSource
var _leaderboard_store: LeaderboardStore
var _queued_names: PackedStringArray = PackedStringArray()
var _join_feed_lines: Array[String] = []
const JOIN_COMMAND_TEXT := "!brains to join."
const BITS_CAGE_MINE_MESSAGE := "1 bit = Cage mine!!!"

var _command_text: String = JOIN_COMMAND_TEXT
var _state_text: String = "Joining"
var _chat_status_text: String = ""
var _chat_detail_text: String = ""

@onready var _root: Control = get_node("Root") as Control
@onready var _lobby_count_label: Label = get_node("Root/LobbyPanel/Margin/VBox/LobbyCountLabel") as Label
@onready var _lobby_names_scroll: ScrollContainer = get_node(
	"Root/LobbyPanel/Margin/VBox/LobbyNamesScroll"
) as ScrollContainer
@onready var _lobby_names_label: Label = get_node(
	"Root/LobbyPanel/Margin/VBox/LobbyNamesScroll/LobbyNamesLabel"
) as Label
@onready var _lobby_chat_label: Label = get_node("Root/LobbyPanel/Margin/VBox/LobbyChatLabel") as Label
@onready var _ready_button: Button = get_node("Root/LobbyPanel/Margin/VBox/ReadyButton") as Button
@onready var _map_option: OptionButton = get_node("Root/MapSelectPanel/Margin/VBox/MapOption") as OptionButton
@onready var _map_status_label: Label = get_node("Root/MapSelectPanel/Margin/VBox/MapStatusLabel") as Label
@onready var _map_briefing_label: Label = get_node("Root/MapSelectPanel/Margin/VBox/BriefingLabel") as Label
@onready var _map_meta_label: Label = get_node("Root/MapSelectPanel/Margin/VBox/MapMetaLabel") as Label
@onready var _dev_panel: PanelContainer = get_node("Root/DevPanel") as PanelContainer
@onready var _reset_button: HoldToConfirmButton = get_node("Root/DevPanel/Margin/VBox/SecondaryButtonRow/ResetButton") as HoldToConfirmButton
@onready var _lobby_join_button: Button = get_node("Root/DevPanel/Margin/VBox/SecondaryButtonRow/AddNpcButton") as Button
@onready var _auto_repeat_button: CheckButton = get_node("Root/DevPanel/Margin/VBox/SecondaryButtonRow/AutoRepeatButton") as CheckButton
@onready var _join_viewer_button: Button = get_node("Root/DevPanel/Margin/VBox/TestJoinSection/TestJoinRow/JoinViewerButton") as Button
@onready var _join_sub_button: Button = get_node("Root/DevPanel/Margin/VBox/TestJoinSection/TestJoinRow/JoinSubButton") as Button
@onready var _join_gift_button: Button = get_node("Root/DevPanel/Margin/VBox/TestJoinSection/TestJoinRow/JoinGiftButton") as Button
@onready var _join_bits_button: Button = get_node("Root/DevPanel/Margin/VBox/TestJoinSection/TestJoinRow/JoinBitsButton") as Button
@onready var _test_mine_button: Button = get_node("Root/DevPanel/Margin/VBox/TestJoinSection/TestMineButton") as Button
@onready var _screen_wash: ColorRect = get_node("Root/ScreenWash") as ColorRect
@onready var _options_button: Button = get_node("Root/OptionsButton") as Button
@onready var _main_menu_button: Button = get_node("Root/MainMenuButton") as Button
@onready var _recent_winners_label: Label = get_node("Root/ScoresPanel/Margin/VBox/RecentWinnersLabel") as Label
@onready var _fastest_times_button: Button = get_node("Root/ScoresPanel/Margin/VBox/FastestTimesButton") as Button
@onready var _leaderboard_menu: LeaderboardMenuController = get_node("LeaderboardMenu") as LeaderboardMenuController
@onready var _zombie_showcase: ZombieModelShowcaseMenu = get_node("Root/ZombieModelShowcase") as ZombieModelShowcaseMenu

func _ready() -> void:
	_round_manager = get_node_or_null(round_manager_path) as RoundManager
	_join_source = get_node_or_null(join_source_path) as JoinSource
	_debug_join_source = get_node_or_null(debug_join_source_path) as DebugJoinSource
	_twitch_join_source = get_node_or_null(twitch_join_source_path) as TwitchJoinSource
	_leaderboard_store = get_node_or_null(leaderboard_store_path) as LeaderboardStore

	_lobby_join_button.pressed.connect(_on_add_npc_pressed)
	if _auto_repeat_button != null:
		_auto_repeat_button.toggled.connect(_on_auto_repeat_toggled)
		if _round_manager != null:
			_auto_repeat_button.button_pressed = _round_manager.is_auto_repeat_enabled()
	_join_viewer_button.pressed.connect(_on_join_viewer_pressed)
	_join_sub_button.pressed.connect(_on_join_sub_pressed)
	_join_gift_button.pressed.connect(_on_join_gift_pressed)
	_join_bits_button.pressed.connect(_on_join_bits_pressed)
	_test_mine_button.pressed.connect(_on_test_mine_pressed)
	_ready_button.pressed.connect(_on_ready_pressed)
	_reset_button.hold_confirmed.connect(_on_reset_confirmed)
	_map_option.item_selected.connect(_on_map_option_selected)
	_options_button.pressed.connect(_on_options_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_fastest_times_button.pressed.connect(_on_fastest_times_pressed)

	GameEvents.participant_registered.connect(_on_participant_registered)
	GameEvents.participant_queue_changed.connect(_on_participant_queue_changed)
	GameEvents.join_rejected.connect(_on_join_rejected)
	GameEvents.join_accepted_late.connect(_on_join_accepted_late)
	GameEvents.bits_cheer_received.connect(_on_bits_cheer_received)
	GameEvents.command_text_changed.connect(_on_command_text_changed)
	GameEvents.chat_connection_status_changed.connect(_on_chat_connection_status_changed)
	GameEvents.round_state_changed.connect(_on_round_state_changed)
	GameEvents.round_reset.connect(_on_round_reset)
	if _leaderboard_store != null:
		_leaderboard_store.leaderboard_changed.connect(_on_leaderboard_changed)
	var streamer_menu: StreamerMenuController = get_parent().get_node_or_null("StreamerMenu") as StreamerMenuController
	if streamer_menu != null and not streamer_menu.menu_closed.is_connected(refresh_map_selection):
		streamer_menu.menu_closed.connect(refresh_map_selection)

	if _round_manager != null:
		_queued_names = _round_manager.get_pending_names()
		_state_text = _round_manager.get_state_text()
	_refresh_chat_status_from_source()
	_refresh_labels()
	_refresh_scoreboards()
	_update_title_from_command(_command_text)
	_populate_map_options()
	refresh_map_selection()
	apply_stream_capture_visuals()
	_command_text = TwitchConfigResolver.get_join_command_text()

func apply_stream_capture_visuals() -> void:
	if _dev_panel != null:
		# The complete developer control panel owns F3. Keep this legacy lobby
		# test-control cluster hidden so it never competes with release UI.
		_dev_panel.visible = false
	var game_settings: GameSettingsController = get_node_or_null("/root/GameSettings") as GameSettingsController
	if game_settings == null:
		return

	if _screen_wash != null:
		_screen_wash.visible = not game_settings.should_hide_screen_wash()

func refresh_map_selection() -> void:
	if _map_status_label == null or _map_option == null:
		return
	var streamer_menu: StreamerMenuController = get_parent().get_node_or_null("StreamerMenu") as StreamerMenuController
	if streamer_menu == null:
		_map_status_label.text = "Course selection unavailable."
		return
	var selected_settings_index: int = streamer_menu.get_selected_settings_map_index()
	for option_index in range(_map_option.item_count):
		if _map_option.get_item_id(option_index) == selected_settings_index:
			_map_option.select(option_index)
			break
	var map_definition: RaceMapDefinition = streamer_menu.get_selected_map_definition()
	_map_status_label.text = "CURRENT COURSE: %s" % streamer_menu.get_selected_map_name().to_upper()
	if map_definition == null:
		if _map_briefing_label != null:
			_map_briefing_label.text = "Course briefing unavailable."
		if _map_meta_label != null:
			_map_meta_label.text = ""
		return
	if _map_briefing_label != null:
		_map_briefing_label.text = map_definition.lobby_summary
	if _map_meta_label != null:
		_map_meta_label.text = _format_map_meta(map_definition)

func _populate_map_options() -> void:
	if _map_option == null:
		return
	_map_option.clear()
	var streamer_menu: StreamerMenuController = get_parent().get_node_or_null("StreamerMenu") as StreamerMenuController
	if streamer_menu == null:
		_map_option.add_item("Loading courses...")
		_map_option.disabled = true
		return
	for entry in streamer_menu.get_lobby_map_entries():
		_map_option.add_item(str(entry.get("display_name", "Race Map")), int(entry.get("settings_index", 0)))
	_map_option.disabled = _map_option.item_count <= 1

func _on_map_option_selected(option_index: int) -> void:
	if _map_option == null:
		return
	var streamer_menu: StreamerMenuController = get_parent().get_node_or_null("StreamerMenu") as StreamerMenuController
	if streamer_menu == null:
		return
	streamer_menu.select_map_from_lobby(int(_map_option.get_item_id(option_index)))
	refresh_map_selection()


func _format_map_meta(map_definition: RaceMapDefinition) -> String:
	var feature_labels: Array[String] = []
	for tag in map_definition.lobby_hazard_tags:
		feature_labels.append(str(tag).to_upper())
	var feature_text: String = _join_strings(feature_labels, "  |  ")
	if feature_text.is_empty():
		feature_text = "NO SPECIAL HAZARDS"
	return "DIFFICULTY: %s  |  %s" % [map_definition.lobby_difficulty.to_upper(), feature_text]

func set_screen_mode(mode: String) -> void:
	var should_show: bool = mode != "hidden"
	visible = true
	if _root != null:
		_root.visible = should_show
	if _zombie_showcase != null:
		_zombie_showcase.visible = should_show
	if should_show:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	apply_stream_capture_visuals()

func _on_ready_pressed() -> void:
	ready_requested.emit()

func _on_reset_confirmed() -> void:
	if _round_manager != null:
		_round_manager.reset_round()


func _on_auto_repeat_toggled(enabled: bool) -> void:
	if _round_manager == null:
		return
	_round_manager.set_auto_repeat_enabled(enabled)

func _on_add_npc_pressed() -> void:
	var debug_source: DebugJoinSource = _get_debug_join_source()
	if debug_source != null:
		debug_source.request_random_join()

func _on_join_viewer_pressed() -> void:
	_request_test_tier_join(ParticipantJoinInfo.SupporterTier.NONE)

func _on_join_sub_pressed() -> void:
	_request_test_tier_join(ParticipantJoinInfo.SupporterTier.SUBSCRIBER)

func _on_join_gift_pressed() -> void:
	_request_test_tier_join(ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT)

func _on_join_bits_pressed() -> void:
	_request_test_tier_join(ParticipantJoinInfo.SupporterTier.BITS_DONOR)

func _on_test_mine_pressed() -> void:
	var debug_source: DebugJoinSource = _get_debug_join_source()
	if debug_source != null:
		debug_source.request_test_bits_cheer()

func _on_bits_cheer_received(display_name: String, bits_amount: int) -> void:
	if bits_amount <= 0:
		return

	var cheer_name: String = display_name.strip_edges()
	if cheer_name.is_empty():
		cheer_name = "Cheerer"
	_join_feed_lines.append("%s cheered %d bit%s — %s" % [
		cheer_name,
		bits_amount,
		"s" if bits_amount != 1 else "",
		BITS_CAGE_MINE_MESSAGE,
	])
	while _join_feed_lines.size() > MAX_JOIN_FEED_LINES:
		_join_feed_lines.remove_at(0)
	_refresh_labels()

func _request_test_tier_join(tier: ParticipantJoinInfo.SupporterTier) -> void:
	var debug_source: DebugJoinSource = _get_debug_join_source()
	if debug_source != null:
		debug_source.request_test_tier_join(tier)

func _get_debug_join_source() -> DebugJoinSource:
	if _debug_join_source != null:
		return _debug_join_source
	return _join_source as DebugJoinSource

func _on_options_pressed() -> void:
	options_requested.emit()

func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()

func _on_fastest_times_pressed() -> void:
	if _leaderboard_menu != null:
		_leaderboard_menu.open_menu()

func _on_participant_registered(join_info: ParticipantJoinInfo, _queued_count: int) -> void:
	var clean_name: String = join_info.display_name.strip_edges()
	if clean_name.is_empty():
		return

	_join_feed_lines.append("%s joined the queue.%s" % [clean_name, join_info.get_join_feed_suffix()])
	while _join_feed_lines.size() > MAX_JOIN_FEED_LINES:
		_join_feed_lines.remove_at(0)
	_refresh_labels()


func _on_join_rejected(display_name: String, reason: String) -> void:
	_join_feed_lines.append(StreamerFeedbackMessages.format_join_rejected(display_name, reason))
	while _join_feed_lines.size() > MAX_JOIN_FEED_LINES:
		_join_feed_lines.remove_at(0)
	_refresh_labels()


func _on_join_accepted_late(display_name: String) -> void:
	_join_feed_lines.append(StreamerFeedbackMessages.format_join_accepted_late(display_name))
	while _join_feed_lines.size() > MAX_JOIN_FEED_LINES:
		_join_feed_lines.remove_at(0)
	_refresh_labels()

func _on_participant_queue_changed(display_names: PackedStringArray) -> void:
	_queued_names = display_names
	_refresh_labels()

func _on_round_reset() -> void:
	_join_feed_lines.clear()
	_queued_names = PackedStringArray()
	_refresh_labels()

func _on_command_text_changed(text: String) -> void:
	_command_text = text
	_update_title_from_command(text)
	_refresh_labels()


func _update_title_from_command(command_text: String) -> void:
	var title_label: Label = get_node_or_null("Root/LobbyPanel/Margin/VBox/TitleLabel") as Label
	if title_label == null:
		return

	var title_text: String = command_text.strip_edges()
	if title_text.begins_with("Type "):
		title_text = title_text.substr(5)
	title_label.text = title_text

func _on_chat_connection_status_changed(status_text: String, detail_text: String) -> void:
	_chat_status_text = status_text.strip_edges()
	_chat_detail_text = detail_text.strip_edges()
	_refresh_labels()

func _on_round_state_changed(state_text: String) -> void:
	_state_text = state_text
	_refresh_labels()

func _on_leaderboard_changed(_entries: Array) -> void:
	_refresh_scoreboards()

func _refresh_labels() -> void:
	if _lobby_count_label != null:
		_lobby_count_label.text = _format_queue_summary()
	if _lobby_names_label != null:
		_lobby_names_label.text = _format_lobby_body()
		_scroll_join_list_to_bottom()
	if _lobby_chat_label != null:
		var chat_text: String = _format_chat_status()
		if _should_show_chat_status(chat_text):
			_lobby_chat_label.visible = true
			_lobby_chat_label.text = chat_text
		else:
			_lobby_chat_label.visible = false
	_refresh_ready_button()

func _scroll_join_list_to_bottom() -> void:
	if _lobby_names_scroll == null:
		return
	call_deferred("_apply_join_list_scroll")

func _apply_join_list_scroll() -> void:
	if _lobby_names_scroll == null:
		return
	var scroll_bar: VScrollBar = _lobby_names_scroll.get_v_scroll_bar()
	if scroll_bar == null:
		return
	scroll_bar.value = scroll_bar.max_value

func _refresh_scoreboards() -> void:
	if _recent_winners_label != null:
		_recent_winners_label.text = _format_recent_winners()

func _format_recent_winners() -> String:
	if _leaderboard_store == null:
		return "—"

	var entries: Array = _leaderboard_store.get_recent_winners()
	if entries.is_empty():
		return "—"

	var lines: Array[String] = [_board_column_header("ROUND")]
	var max_entries: int = mini(entries.size(), 10)
	for index in range(max_entries):
		if typeof(entries[index]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entries[index]
		var display_name: String = "Streamer Base" if bool(entry.get("base_won", false)) else str(entry.get("display_name", "Zombie"))
		lines.append(_format_board_row(
			index + 1,
			display_name,
			"#%d" % int(entry.get("round_number", 0))
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
		return "READY PLAYERS: 0  |  ROUND: WAITING FOR VIEWERS"
	return "READY PLAYERS: %d  |  ROUND: READY TO STAGE" % _queued_names.size()


func _should_show_chat_status(chat_text: String) -> bool:
	if chat_text.is_empty():
		return false
	return TwitchStatusFormatter.should_show_status(_chat_status_text)

func _format_lobby_body() -> String:
	var sections: Array[String] = []
	var roster_text: String = _format_joining_roster()
	if not roster_text.is_empty():
		sections.append(roster_text)
	var feed_text: String = _format_join_feed()
	if not feed_text.is_empty():
		sections.append(feed_text)
	if sections.is_empty():
		return "—"
	return _join_strings(sections, "\n\n")

func _format_joining_roster() -> String:
	if _queued_names.is_empty():
		return ""
	var lines: Array[String] = []
	for display_name in _queued_names:
		var clean_name: String = str(display_name).strip_edges()
		if clean_name.is_empty():
			continue
		lines.append("• %s" % clean_name)
	return _join_strings(lines, "\n")

func _format_join_feed() -> String:
	if _join_feed_lines.is_empty():
		return ""
	return _join_strings(_join_feed_lines, "\n")

func _format_chat_status() -> String:
	if _chat_status_text.is_empty():
		return ""
	var detail_text: String = TwitchStatusFormatter.shorten_detail(_chat_detail_text)
	if detail_text.is_empty():
		return "Chat: %s" % TwitchStatusFormatter.format_headline(_chat_status_text)
	return "Chat: %s\n%s" % [
		TwitchStatusFormatter.format_headline(_chat_status_text),
		detail_text,
	]

func _refresh_ready_button() -> void:
	if _ready_button == null:
		return

	var can_ready: bool = _state_text == "Joining" and not _queued_names.is_empty()
	_ready_button.disabled = not can_ready
	if _queued_names.is_empty():
		_ready_button.text = "STAGE RACE - WAITING FOR PLAYERS"
	else:
		_ready_button.text = "STAGE RACE - %d READY" % _queued_names.size()
	if _main_menu_button != null:
		_main_menu_button.disabled = _state_text != "Joining"
	if _auto_repeat_button != null and _round_manager != null:
		_auto_repeat_button.set_pressed_no_signal(_round_manager.is_auto_repeat_enabled())

func _join_strings(values: Array[String], separator: String) -> String:
	var result: String = ""
	for index in range(values.size()):
		if index > 0:
			result += separator
		result += values[index]
	return result

func _refresh_chat_status_from_source() -> void:
	if _twitch_join_source == null:
		_chat_status_text = ""
		_chat_detail_text = ""
		_command_text = TwitchConfigResolver.get_join_command_text()
		return

	var status_text: String = _twitch_join_source.get_status_text()
	var detail_text: String = _twitch_join_source.get_status_detail()
	_on_chat_connection_status_changed(status_text, detail_text)
