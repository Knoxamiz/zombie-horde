class_name MainLobbyScreen
extends CanvasLayer

signal action_requested(action_id: StringName)

var _logo_texture: Texture2D
var _root: Control
var _logo_rect: TextureRect
var _actions_box: VBoxContainer
var _lobby_panel: InfoPanel
var _records_panel: RecordsPanel
var _chat_panel: ChatActivityPanel
var _bottom_bar: BottomStatusBar
var _action_buttons: Dictionary = {}

func _ready() -> void:
	layer = 60
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.0, 0.0, 0.0, 0.28)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(wash)

	var safe := MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 34)
	safe.add_theme_constant_override("margin_top", 22)
	safe.add_theme_constant_override("margin_right", 34)
	safe.add_theme_constant_override("margin_bottom", 22)
	_root.add_child(safe)

	var main_box := VBoxContainer.new()
	main_box.add_theme_constant_override("separation", ControlRoomTheme.GAP_LARGE)
	safe.add_child(main_box)

	var top_area := Control.new()
	top_area.custom_minimum_size = Vector2(0, 170)
	main_box.add_child(top_area)

	_logo_rect = TextureRect.new()
	_logo_rect.custom_minimum_size = Vector2(560, 166)
	_logo_rect.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_logo_rect.offset_left = -280
	_logo_rect.offset_top = 0
	_logo_rect.offset_right = 280
	_logo_rect.offset_bottom = 166
	_logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_rect.texture = _logo_texture
	top_area.add_child(_logo_rect)

	_chat_panel = ChatActivityPanel.new()
	_chat_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_chat_panel.offset_left = -366
	_chat_panel.offset_top = 8
	_chat_panel.offset_right = -6
	_chat_panel.offset_bottom = 158
	top_area.add_child(_chat_panel)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", ControlRoomTheme.GAP_LARGE)
	main_box.add_child(content)

	_actions_box = VBoxContainer.new()
	_actions_box.custom_minimum_size = Vector2(ControlRoomTheme.BUTTON_WIDTH, 0)
	_actions_box.add_theme_constant_override("separation", 12)
	content.add_child(_actions_box)

	var panels := HBoxContainer.new()
	panels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panels.add_theme_constant_override("separation", 20)
	content.add_child(panels)

	_lobby_panel = InfoPanel.new()
	_lobby_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lobby_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels.add_child(_lobby_panel)
	_lobby_panel.set_panel_text("LOTTO CAGE", "Cage empty - waiting for !brains")

	_records_panel = RecordsPanel.new()
	_records_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_records_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels.add_child(_records_panel)
	_records_panel.set_records("Fastest Times\n-", "Last Winners\n-")

	_bottom_bar = BottomStatusBar.new()
	main_box.add_child(_bottom_bar)

func set_logo_texture(texture: Texture2D) -> void:
	_logo_texture = texture
	if _logo_rect != null:
		_logo_rect.texture = texture

func set_actions(actions: Array[Dictionary]) -> void:
	if _actions_box == null:
		return
	for child in _actions_box.get_children():
		child.queue_free()
	_action_buttons.clear()
	for action in actions:
		var button := ActionButton.new()
		var action_id := StringName(str(action.get("id", "")))
		button.configure(
			action_id,
			str(action.get("icon", ">")),
			str(action.get("label", "ACTION")),
			bool(action.get("primary", false)),
			bool(action.get("enabled", true))
		)
		button.pressed.connect(_on_action_button_pressed.bind(action_id))
		_actions_box.add_child(button)
		_action_buttons[action_id] = button

func set_action_enabled(action_id: StringName, enabled: bool) -> void:
	var button: ActionButton = _action_buttons.get(action_id) as ActionButton
	if button != null:
		button.disabled = not enabled

func set_action_label(action_id: StringName, label_text: String) -> void:
	var button: ActionButton = _action_buttons.get(action_id) as ActionButton
	if button != null:
		button.set_action_label(label_text)

func set_lobby_status(summary: String, player_lines: String, chat_status: String, round_status: String) -> void:
	var player_text := player_lines
	if player_text.strip_edges().is_empty() or player_text == "-":
		player_text = "No runners in the cage yet."
	var body := "%s\n\nPLAYERS\n%s\n\nCHAT\n%s\n\nROUND\n%s" % [summary, player_text, chat_status, round_status]
	_lobby_panel.set_panel_text("LOTTO CAGE", body)

func set_records(fastest: String, recent: String) -> void:
	_records_panel.set_records(fastest, recent)

func set_chat_activity(lines: PackedStringArray) -> void:
	_chat_panel.set_activity(lines)

func set_bottom_items(items: Array[Dictionary]) -> void:
	_bottom_bar.set_items(items)

func _on_action_button_pressed(action_id: StringName) -> void:
	action_requested.emit(action_id)
