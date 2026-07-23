class_name StreamerMenuController
extends CanvasLayer

signal menu_closed()

const SETTINGS_MODAL_SCRIPT: Script = preload("res://scripts/ui/settings_modal.gd")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")

@export var hazard_config: HazardConfig
@export var zombie_config: ZombieConfig
@export var minigun_config: MinigunConfig
@export var powerup_config: PowerupConfig
@export var human_defender_config: HumanDefenderConfig
@export var visual_config: StreamerVisualConfig
@export var feature_config: FeatureAccessConfig
@export var round_manager_path: NodePath
@export var hazard_manager_path: NodePath
@export var powerup_manager_path: NodePath
@export var race_map_controller_path: NodePath
@export var visual_settings_controller_path: NodePath
@export var world_menu_root_path: NodePath
@export var world_summary_board_path: NodePath
@export var world_close_button_path: NodePath
@export var world_map_button_path: NodePath
@export var world_balance_down_button_path: NodePath
@export var world_balance_up_button_path: NodePath
@export var world_lighting_button_path: NodePath
@export var world_backdrop_button_path: NodePath
@export var world_avatar_button_path: NodePath
@export var world_reroll_button_path: NodePath
@export var world_save_button_path: NodePath
@export var world_preset_1_button_path: NodePath
@export var world_preset_2_button_path: NodePath
@export var world_preset_3_button_path: NodePath
@export var world_preset_4_button_path: NodePath
@export var world_reset_button_path: NodePath
@export var hud_controller_path: NodePath
@export var expanded_modal: bool = false

var _round_manager: RoundManager
var _hazard_manager: HazardManager
var _powerup_manager: PowerupManager
var _race_map_controller: RaceMapController
var _visual_settings_controller: VisualSettingsController
var _world_menu_root: Node3D
var _world_summary_board: WorldTextBoard
var _world_close_button: MainMenu3DButton
var _world_map_button: MainMenu3DButton
var _world_balance_down_button: MainMenu3DButton
var _world_balance_up_button: MainMenu3DButton
var _world_lighting_button: MainMenu3DButton
var _world_backdrop_button: MainMenu3DButton
var _world_avatar_button: MainMenu3DButton
var _world_reroll_button: MainMenu3DButton
var _world_save_button: MainMenu3DButton
var _world_preset_1_button: MainMenu3DButton
var _world_preset_2_button: MainMenu3DButton
var _world_preset_3_button: MainMenu3DButton
var _world_preset_4_button: MainMenu3DButton
var _world_reset_button: MainMenu3DButton
var _hidden_world_roots: Dictionary = {}
var _settings_modal: SettingsModal
var _profile: StreamerSettingsProfile = StreamerSettingsProfile.new()
var _is_refreshing: bool = false
var _active_preset_slot: int = 0
var _status_text: String = "Settings loaded"

@onready var _root: Control = get_node("Root") as Control
@onready var _toggle_button: Button = get_node("Root/ToggleButton") as Button
@onready var _menu_panel: PanelContainer = get_node("Root/MenuPanel") as PanelContainer
@onready var _edition_value_label: Label = get_node("Root/MenuPanel/Margin/VBox/MenuTierRow/EditionValueLabel") as Label
@onready var _menu_tier_detail_label: Label = get_node("Root/MenuPanel/Margin/VBox/MenuTierDetailLabel") as Label
@onready var _map_row: HBoxContainer = get_node("Root/MenuPanel/Margin/VBox/MapRow") as HBoxContainer
@onready var _map_option: OptionButton = get_node("Root/MenuPanel/Margin/VBox/MapRow/MapOption") as OptionButton
@onready var _preset_button_1: Button = get_node("Root/MenuPanel/Margin/VBox/PresetBlock/PresetRow/PresetButton1") as Button
@onready var _preset_button_2: Button = get_node("Root/MenuPanel/Margin/VBox/PresetBlock/PresetRow/PresetButton2") as Button
@onready var _preset_button_3: Button = get_node("Root/MenuPanel/Margin/VBox/PresetBlock/PresetRow/PresetButton3") as Button
@onready var _preset_button_4: Button = get_node("Root/MenuPanel/Margin/VBox/PresetBlock/PresetRow/PresetButton4") as Button
@onready var _save_preset_button: Button = get_node("Root/MenuPanel/Margin/VBox/PresetBlock/PresetActionRow/SavePresetButton") as Button
@onready var _reset_defaults_button: Button = get_node("Root/MenuPanel/Margin/VBox/PresetBlock/PresetActionRow/ResetDefaultsButton") as Button
@onready var _balance_slider: HSlider = get_node("Root/MenuPanel/Margin/VBox/BalanceBlock/BalanceSlider") as HSlider
@onready var _balance_value_label: Label = get_node("Root/MenuPanel/Margin/VBox/BalanceBlock/BalanceValueLabel") as Label
@onready var _balance_detail_label: Label = get_node("Root/MenuPanel/Margin/VBox/BalanceBlock/BalanceDetailLabel") as Label
@onready var _streamer_name_edit: LineEdit = get_node("Root/MenuPanel/Margin/VBox/StreamerNameRow/StreamerNameEdit") as LineEdit
@onready var _time_of_day_option: OptionButton = get_node("Root/MenuPanel/Margin/VBox/TimeOfDayRow/TimeOfDayOption") as OptionButton
@onready var _backdrop_option: OptionButton = get_node("Root/MenuPanel/Margin/VBox/BackdropRow/BackdropOption") as OptionButton
@onready var _avatar_value_label: Label = get_node("Root/MenuPanel/Margin/VBox/AvatarRow/AvatarValueLabel") as Label
@onready var _choose_character_button: Button = get_node("Root/MenuPanel/Margin/VBox/AvatarRow/ChooseCharacterButton") as Button
@onready var _tower_gun_row: HBoxContainer = get_node("Root/MenuPanel/Margin/VBox/TowerGunRow") as HBoxContainer
@onready var _tower_gun_option: OptionButton = get_node("Root/MenuPanel/Margin/VBox/TowerGunRow/TowerGunOption") as OptionButton
@onready var _tower_weapon_row: HBoxContainer = get_node("Root/MenuPanel/Margin/VBox/TowerWeaponRow") as HBoxContainer
var _tower_weapon_check: CheckBox
var _auto_repeat_toggle: ToggleControl
var _premium_controls: VBoxContainer
var _mine_spin: SliderControl
var _street_prop_spin: SliderControl
var _boost_pad_spin: SliderControl
var _sewer_spin: SliderControl
var _defender_spin: SliderControl
var _vehicle_weight_spin: SliderControl
var _cone_weight_spin: SliderControl
var _barrier_weight_spin: SliderControl
var _mine_meter_label: Label
var _street_prop_meter_label: Label
var _boost_pad_meter_label: Label
var _sewer_meter_label: Label
var _defender_meter_label: Label
var _vehicle_weight_meter_label: Label
var _cone_weight_meter_label: Label
var _barrier_weight_meter_label: Label
var _edit_hud_layout_button: Button
var _layout_preview_hud: HudController
@onready var _status_label: Label = get_node("Root/MenuPanel/Margin/VBox/StatusLabel") as Label
@onready var _reroll_button: Button = get_node("Root/MenuPanel/Margin/VBox/RerollButton") as Button
@onready var _character_overlay_wash: ColorRect = get_node("Root/CharacterOverlayWash") as ColorRect
@onready var _character_select_panel: PanelContainer = get_node("Root/CharacterSelectPanel") as PanelContainer
@onready var _character_close_button: Button = get_node("Root/CharacterSelectPanel/Margin/VBox/Header/CloseButton") as Button
@onready var _matt_button: Button = get_node("Root/CharacterSelectPanel/Margin/VBox/CharacterGrid/MattCard/Margin/VBox/SelectButton") as Button
@onready var _lis_button: Button = get_node("Root/CharacterSelectPanel/Margin/VBox/CharacterGrid/LisCard/Margin/VBox/SelectButton") as Button
@onready var _sam_button: Button = get_node("Root/CharacterSelectPanel/Margin/VBox/CharacterGrid/SamCard/Margin/VBox/SelectButton") as Button
@onready var _shaun_button: Button = get_node("Root/CharacterSelectPanel/Margin/VBox/CharacterGrid/ShaunCard/Margin/VBox/SelectButton") as Button

func _ready() -> void:
	_round_manager = get_node_or_null(round_manager_path) as RoundManager
	_hazard_manager = get_node_or_null(hazard_manager_path) as HazardManager
	_powerup_manager = get_node_or_null(powerup_manager_path) as PowerupManager
	_race_map_controller = get_node_or_null(race_map_controller_path) as RaceMapController
	_visual_settings_controller = get_node_or_null(visual_settings_controller_path) as VisualSettingsController
	_world_menu_root = get_node_or_null(world_menu_root_path) as Node3D
	_world_summary_board = get_node_or_null(world_summary_board_path) as WorldTextBoard
	_world_close_button = get_node_or_null(world_close_button_path) as MainMenu3DButton
	_world_map_button = get_node_or_null(world_map_button_path) as MainMenu3DButton
	_world_balance_down_button = get_node_or_null(world_balance_down_button_path) as MainMenu3DButton
	_world_balance_up_button = get_node_or_null(world_balance_up_button_path) as MainMenu3DButton
	_world_lighting_button = get_node_or_null(world_lighting_button_path) as MainMenu3DButton
	_world_backdrop_button = get_node_or_null(world_backdrop_button_path) as MainMenu3DButton
	_world_avatar_button = get_node_or_null(world_avatar_button_path) as MainMenu3DButton
	_world_reroll_button = get_node_or_null(world_reroll_button_path) as MainMenu3DButton
	_world_save_button = get_node_or_null(world_save_button_path) as MainMenu3DButton
	_world_preset_1_button = get_node_or_null(world_preset_1_button_path) as MainMenu3DButton
	_world_preset_2_button = get_node_or_null(world_preset_2_button_path) as MainMenu3DButton
	_world_preset_3_button = get_node_or_null(world_preset_3_button_path) as MainMenu3DButton
	_world_preset_4_button = get_node_or_null(world_preset_4_button_path) as MainMenu3DButton
	_world_reset_button = get_node_or_null(world_reset_button_path) as MainMenu3DButton
	if _root != null:
		_root.visible = false

	_build_control_room_streamer_modal()
	_profile = StreamerSettingsProfile.load_from_disk()
	_populate_options()
	_apply_profile_to_game(false)

	_toggle_button.pressed.connect(_on_toggle_pressed)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_map_option.item_selected.connect(_on_map_selected)
	_preset_button_1.pressed.connect(_on_preset_button_pressed.bind(0))
	_preset_button_2.pressed.connect(_on_preset_button_pressed.bind(1))
	_preset_button_3.pressed.connect(_on_preset_button_pressed.bind(2))
	_preset_button_4.pressed.connect(_on_preset_button_pressed.bind(3))
	_save_preset_button.pressed.connect(_on_save_preset_pressed)
	_reset_defaults_button.pressed.connect(_on_reset_defaults_pressed)
	_streamer_name_edit.text_submitted.connect(_on_streamer_name_submitted)
	_streamer_name_edit.focus_exited.connect(_on_streamer_name_focus_exited)
	_balance_slider.value_changed.connect(_on_balance_changed)
	_time_of_day_option.item_selected.connect(_on_time_of_day_selected)
	_backdrop_option.item_selected.connect(_on_backdrop_selected)
	_choose_character_button.pressed.connect(_on_choose_character_pressed)
	_character_close_button.pressed.connect(_on_character_close_pressed)
	_matt_button.pressed.connect(_on_character_button_pressed.bind(0))
	_lis_button.pressed.connect(_on_character_button_pressed.bind(1))
	_sam_button.pressed.connect(_on_character_button_pressed.bind(2))
	_shaun_button.pressed.connect(_on_character_button_pressed.bind(3))
	_tower_gun_option.item_selected.connect(_on_tower_gun_selected)
	_tower_weapon_check.toggled.connect(_on_tower_weapon_toggled)
	GameEvents.round_ended.connect(_on_round_ended)
	_connect_world_button(_world_close_button)
	_connect_world_button(_world_map_button)
	_connect_world_button(_world_balance_down_button)
	_connect_world_button(_world_balance_up_button)
	_connect_world_button(_world_lighting_button)
	_connect_world_button(_world_backdrop_button)
	_connect_world_button(_world_avatar_button)
	_connect_world_button(_world_reroll_button)
	_connect_world_button(_world_save_button)
	_connect_world_button(_world_preset_1_button)
	_connect_world_button(_world_preset_2_button)
	_connect_world_button(_world_preset_3_button)
	_connect_world_button(_world_preset_4_button)
	_connect_world_button(_world_reset_button)

	_sanitize_character_previews()
	_sanitize_standalone_controls()
	_refresh_controls()
	_set_menu_open(false)
	_set_character_select_open(false)
	_set_status("Settings loaded")
	call_deferred("_connect_hud_layout_signal")

func _connect_hud_layout_signal() -> void:
	var hud_controller: HudController = get_node_or_null(hud_controller_path) as HudController
	if hud_controller == null:
		return
	if not hud_controller.layout_edit_finished.is_connected(_on_hud_layout_edit_finished):
		hud_controller.layout_edit_finished.connect(_on_hud_layout_edit_finished)

func _build_control_room_streamer_modal() -> void:
	_settings_modal = SETTINGS_MODAL_SCRIPT.new() as SettingsModal
	if _settings_modal == null:
		return
	_settings_modal.name = "ControlRoomStreamerModal"
	add_child(_settings_modal)
	_settings_modal.set_title("Streamer Settings")
	_settings_modal.close_pressed.connect(close_menu)
	_settings_modal.done_pressed.connect(close_menu)
	_settings_modal.reset_pressed.connect(_on_reset_defaults_pressed)
	_settings_modal.clear_groups()

	var hud_group: VBoxContainer = _settings_modal.add_group("HUD Layout", 0)
	var hud_hint := Label.new()
	hud_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_hint.text = "Drag race overlay panels into place for your stream layout."
	ControlRoomTheme.apply_label(hud_hint, 16, ControlRoomTheme.COLOR_MUTED)
	hud_group.add_child(hud_hint)
	_edit_hud_layout_button = _make_modal_button("CUSTOMIZE HUD LAYOUT", ControlRoomTheme.COLOR_GREEN)
	_edit_hud_layout_button.pressed.connect(_on_edit_hud_layout_pressed)
	_settings_modal.add_footer_button(_edit_hud_layout_button)

	var overview_group: VBoxContainer = _settings_modal.add_group("Streamer", 0)
	_edition_value_label = Label.new()
	ControlRoomTheme.apply_label(_edition_value_label, 20, ControlRoomTheme.COLOR_GREEN)
	_settings_modal.add_row(overview_group, "Edition", _edition_value_label)
	_menu_tier_detail_label = Label.new()
	_menu_tier_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ControlRoomTheme.apply_label(_menu_tier_detail_label, 16, ControlRoomTheme.COLOR_MUTED)
	overview_group.add_child(_menu_tier_detail_label)
	_streamer_name_edit = LineEdit.new()
	_streamer_name_edit.custom_minimum_size = Vector2(0, 42)
	_settings_modal.add_row(overview_group, "Streamer Name", _streamer_name_edit)
	_avatar_value_label = Label.new()
	ControlRoomTheme.apply_label(_avatar_value_label, 19, ControlRoomTheme.COLOR_TEXT)
	var avatar_box := HBoxContainer.new()
	avatar_box.add_theme_constant_override("separation", 10)
	avatar_box.add_child(_avatar_value_label)
	_choose_character_button = _make_modal_button("CHOOSE NPC", ControlRoomTheme.COLOR_PURPLE)
	avatar_box.add_child(_choose_character_button)
	_settings_modal.add_row(overview_group, "NPC Character", avatar_box)

	var gameplay_group: VBoxContainer = _settings_modal.add_group("Gameplay", 1)
	_map_option = _make_modal_option()
	_map_row = _settings_modal.add_row(gameplay_group, "Level", _map_option)
	_auto_repeat_toggle = ToggleControl.new()
	_auto_repeat_toggle.text = "AUTO REPEAT"
	_settings_modal.add_row(gameplay_group, "Auto Repeat", _auto_repeat_toggle)
	_auto_repeat_toggle.toggled.connect(_on_auto_repeat_toggled)
	_balance_value_label = Label.new()
	ControlRoomTheme.apply_label(_balance_value_label, 19, ControlRoomTheme.COLOR_GREEN)
	_balance_detail_label = Label.new()
	_balance_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ControlRoomTheme.apply_label(_balance_detail_label, 16, ControlRoomTheme.COLOR_MUTED)
	var balance_pair: Dictionary = _make_slider_value_pair(_balance_value_label)
	_balance_slider = balance_pair["slider"] as HSlider
	_settings_modal.add_row(gameplay_group, "Round Balance", balance_pair["root"] as Control)
	gameplay_group.add_child(_balance_detail_label)
	_time_of_day_option = _make_modal_option()
	_settings_modal.add_row(gameplay_group, "Lighting", _time_of_day_option)
	_backdrop_option = _make_modal_option()
	_settings_modal.add_row(gameplay_group, "Backdrop", _backdrop_option)
	_tower_gun_option = _make_modal_option()
	_tower_gun_row = _settings_modal.add_row(gameplay_group, "NPC Loadout", _tower_gun_option)
	_tower_weapon_check = ToggleControl.new()
	_tower_weapon_check.text = "SHOW WEAPON PROPS"
	_tower_weapon_row = _settings_modal.add_row(gameplay_group, "Weapon Props", _tower_weapon_check)

	var preset_group: VBoxContainer = _settings_modal.add_group("Presets", 0)
	var preset_grid := GridContainer.new()
	preset_grid.columns = 2
	preset_grid.add_theme_constant_override("h_separation", 10)
	preset_grid.add_theme_constant_override("v_separation", 10)
	_preset_button_1 = _make_modal_button("PRESET 1", ControlRoomTheme.COLOR_PURPLE)
	_preset_button_2 = _make_modal_button("PRESET 2", ControlRoomTheme.COLOR_PURPLE)
	_preset_button_3 = _make_modal_button("PRESET 3", ControlRoomTheme.COLOR_PURPLE)
	_preset_button_4 = _make_modal_button("PRESET 4", ControlRoomTheme.COLOR_PURPLE)
	preset_grid.add_child(_preset_button_1)
	preset_grid.add_child(_preset_button_2)
	preset_grid.add_child(_preset_button_3)
	preset_grid.add_child(_preset_button_4)
	preset_group.add_child(preset_grid)
	var preset_actions := HBoxContainer.new()
	preset_actions.add_theme_constant_override("separation", 10)
	_save_preset_button = _make_modal_button("SAVE PRESET", ControlRoomTheme.COLOR_GREEN)
	_reset_defaults_button = _make_modal_button("DEFAULTS", ControlRoomTheme.COLOR_ORANGE)
	preset_actions.add_child(_save_preset_button)
	preset_actions.add_child(_reset_defaults_button)
	preset_group.add_child(preset_actions)

	_premium_controls = VBoxContainer.new()
	_premium_controls.add_theme_constant_override("separation", 4)
	var premium_group: VBoxContainer = _settings_modal.add_group("Chaos Controls", 1)
	premium_group.add_child(_premium_controls)
	var mine_meter: Dictionary = _create_modal_meter(_premium_controls, "Mines", 0, 96)
	_mine_spin = mine_meter["slider"] as SliderControl
	_mine_meter_label = mine_meter["label"] as Label
	var street_meter: Dictionary = _create_modal_meter(_premium_controls, "Street Props", 0, 96)
	_street_prop_spin = street_meter["slider"] as SliderControl
	_street_prop_meter_label = street_meter["label"] as Label
	var boost_meter: Dictionary = _create_modal_meter(_premium_controls, "Boost Pads", 0, 32)
	_boost_pad_spin = boost_meter["slider"] as SliderControl
	_boost_pad_meter_label = boost_meter["label"] as Label
	var sewer_meter: Dictionary = _create_modal_meter(_premium_controls, "Sewer Holes", 0, 32)
	_sewer_spin = sewer_meter["slider"] as SliderControl
	_sewer_meter_label = sewer_meter["label"] as Label
	var defender_meter: Dictionary = _create_modal_meter(_premium_controls, "NPC Towers", 0, 12)
	_defender_spin = defender_meter["slider"] as SliderControl
	_defender_meter_label = defender_meter["label"] as Label
	var vehicle_meter: Dictionary = _create_modal_meter(_premium_controls, "Vehicle Weight", 0, 100)
	_vehicle_weight_spin = vehicle_meter["slider"] as SliderControl
	_vehicle_weight_meter_label = vehicle_meter["label"] as Label
	var cone_meter: Dictionary = _create_modal_meter(_premium_controls, "Cone Weight", 0, 100)
	_cone_weight_spin = cone_meter["slider"] as SliderControl
	_cone_weight_meter_label = cone_meter["label"] as Label
	var barrier_meter: Dictionary = _create_modal_meter(_premium_controls, "Barrier Weight", 0, 100)
	_barrier_weight_spin = barrier_meter["slider"] as SliderControl
	_barrier_weight_meter_label = barrier_meter["label"] as Label

	_reroll_button = _make_modal_button("REROLL STREET PREVIEW", ControlRoomTheme.COLOR_BLUE)
	premium_group.add_child(_reroll_button)
	_status_label = Label.new()
	ControlRoomTheme.apply_label(_status_label, 17, ControlRoomTheme.COLOR_GREEN)
	premium_group.add_child(_status_label)

	_settings_modal.set_two_column_layout(true)

func _make_slider_value_pair(value_label: Label) -> Dictionary:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var slider := SliderControl.new()
	box.add_child(slider)
	value_label.custom_minimum_size = Vector2(180, 0)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(value_label)
	return {"root": box, "slider": slider}

func _create_modal_meter(parent: VBoxContainer, label_text: String, minimum: int, maximum: int) -> Dictionary:
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(52, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ControlRoomTheme.apply_label(value_label, 18, ControlRoomTheme.COLOR_TEXT)
	var pair: Dictionary = _make_slider_value_pair(value_label)
	var slider: SliderControl = pair["slider"] as SliderControl
	slider.min_value = float(minimum)
	slider.max_value = float(maximum)
	slider.step = 1.0
	slider.value_changed.connect(_on_premium_control_changed)
	_settings_modal.add_row(parent, label_text, pair["root"] as Control)
	return {"slider": slider, "label": value_label}

func _make_modal_button(label: String, accent: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(130, 42)
	button.text = label
	ControlRoomTheme.apply_button(button, Color(0.075, 0.09, 0.078, 0.98), Color(0.13, 0.16, 0.13, 1.0), accent, 16)
	return button

func _make_modal_option() -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(220, 42)
	ControlRoomTheme.apply_button(option, Color(0.075, 0.09, 0.078, 0.98), Color(0.13, 0.16, 0.13, 1.0), ControlRoomTheme.COLOR_BLUE, 16)
	return option

func _make_modal_spin(minimum: int, maximum: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.custom_minimum_size = Vector2(160, 34)
	spin.min_value = float(minimum)
	spin.max_value = float(maximum)
	spin.step = 1.0
	return spin

func _on_toggle_pressed() -> void:
	_set_menu_open(not _menu_panel.visible)

func open_menu() -> void:
	if not _has_premium_access():
		_set_menu_open(false)
		return

	_profile = StreamerSettingsProfile.load_from_disk()
	_refresh_controls()
	_set_menu_open(true)

func can_open_menu() -> bool:
	return _has_premium_access()

func close_menu() -> void:
	_set_menu_open(false)

func _on_edit_hud_layout_pressed() -> void:
	var hud_controller: HudController = _ensure_layout_preview_hud()
	if hud_controller == null:
		_set_status("HUD not found")
		return
	close_menu()
	hud_controller.begin_layout_edit()
	_set_status("Editing HUD layout")

func _ensure_layout_preview_hud() -> HudController:
	var hud_controller: HudController = get_node_or_null(hud_controller_path) as HudController
	if hud_controller != null:
		return hud_controller
	if _layout_preview_hud != null and is_instance_valid(_layout_preview_hud):
		return _layout_preview_hud
	if HUD_SCENE == null:
		return null
	_layout_preview_hud = HUD_SCENE.instantiate() as HudController
	if _layout_preview_hud == null:
		return null
	_layout_preview_hud.name = "LayoutPreviewHUD"
	_layout_preview_hud.visible = false
	var host: Node = get_parent()
	if host == null:
		host = self
	host.add_child(_layout_preview_hud)
	if not _layout_preview_hud.layout_edit_finished.is_connected(_on_hud_layout_edit_finished):
		_layout_preview_hud.layout_edit_finished.connect(_on_hud_layout_edit_finished)
	return _layout_preview_hud

func _on_hud_layout_edit_finished(_save_changes: bool) -> void:
	open_menu()

func _set_menu_open(open: bool) -> void:
	if _root != null:
		_root.visible = open
	_menu_panel.visible = false
	_toggle_button.visible = false
	_toggle_button.text = "Close"
	_set_world_menu_visible(false)
	if _settings_modal != null:
		if open:
			_settings_modal.set_two_column_layout(true)
			_settings_modal.set_expanded_layout(expanded_modal)
			_settings_modal.show_modal()
		else:
			_settings_modal.hide_modal()
	if not open:
		_set_character_select_open(false)
		menu_closed.emit()

func _sanitize_standalone_controls() -> void:
	var has_street_preview: bool = get_node_or_null(hazard_manager_path) != null
	if _reroll_button != null:
		_reroll_button.visible = has_street_preview

func _refresh_controls() -> void:
	_is_refreshing = true
	_balance_slider.value = _profile.audience_balance
	_streamer_name_edit.text = _profile.get_clean_streamer_name()
	_time_of_day_option.select(_clamped_option_index(_time_of_day_option, _profile.time_of_day))
	_backdrop_option.select(_clamped_option_index(_backdrop_option, _profile.backdrop_style))
	_select_map_option_by_settings_index(_profile.get_selected_settings_map_index())
	_tower_gun_option.select(_clamped_option_index(_tower_gun_option, _profile.tower_gun))
	_tower_weapon_check.button_pressed = _profile.show_tower_weapons
	if _auto_repeat_toggle != null and _round_manager != null:
		_auto_repeat_toggle.set_pressed_no_signal(_round_manager.is_auto_repeat_enabled())
	_mine_spin.value = _profile.premium_mine_count
	_street_prop_spin.value = _profile.premium_obstacle_count
	_boost_pad_spin.value = _profile.premium_boost_pad_count
	_sewer_spin.value = _profile.premium_sewer_hole_count
	_defender_spin.value = _profile.premium_defender_count
	_vehicle_weight_spin.value = _profile.premium_vehicle_weight
	_cone_weight_spin.value = _profile.premium_cone_weight
	_barrier_weight_spin.value = _profile.premium_barrier_weight
	if _mine_spin != null:
		_refresh_chaos_meter_labels()
	_refresh_menu_tier_controls()
	_refresh_balance_labels()
	_refresh_avatar_labels()
	_refresh_preset_buttons()
	_is_refreshing = false
	_refresh_world_menu()

func _on_balance_changed(value: float) -> void:
	if _is_refreshing:
		return

	_profile.audience_balance = int(round(value))
	_apply_profile_to_game(true)
	_refresh_balance_labels()
	_save_profile("Saved: %s" % _profile.get_balance_name())

func _on_time_of_day_selected(index: int) -> void:
	if _is_refreshing:
		return

	_profile.time_of_day = int(clamp(index, 0, 1))
	_apply_profile_to_game(false)
	_save_profile("Saved: %s lighting" % _profile.get_time_of_day_name())

func _on_backdrop_selected(index: int) -> void:
	if _is_refreshing:
		return

	_profile.backdrop_style = int(clamp(index, 0, 2))
	_apply_profile_to_game(false)
	_save_profile("Saved backdrop")

func _on_map_selected(option_index: int) -> void:
	if _is_refreshing:
		return
	if _is_map_change_locked():
		_refresh_controls()
		_set_status("Map locked during round")
		return
	if _round_manager != null and _round_manager.state == RoundManager.RoundState.ENDED:
		_round_manager.reset_round()

	_profile.set_selected_settings_map_index(_get_settings_map_index_for_option(option_index))
	_apply_profile_to_game(true)
	_refresh_controls()
	_save_profile("Saved map: %s" % _get_selected_map_name())


func _on_auto_repeat_toggled(enabled: bool) -> void:
	if _is_refreshing:
		return
	if _round_manager != null:
		_round_manager.set_auto_repeat_enabled(enabled)
	_set_status("Auto repeat %s" % ("on" if enabled else "off"))

func _on_preset_button_pressed(slot_index: int) -> void:
	if _is_refreshing:
		return

	_active_preset_slot = int(clamp(slot_index, 0, StreamerSettingsProfile.PRESET_COUNT - 1))
	var preset: StreamerSettingsProfile = StreamerSettingsProfile.load_preset_from_disk(_active_preset_slot)
	_profile.apply_preset_values(preset)
	_apply_profile_to_game(true)
	_refresh_controls()
	_save_profile("Loaded preset %d" % (_active_preset_slot + 1))

func _on_save_preset_pressed() -> void:
	if _is_refreshing:
		return

	_sync_profile_from_controls()
	_apply_profile_to_game(false)
	var preset_error: Error = _profile.save_preset_to_disk(_active_preset_slot)
	var profile_error: Error = _profile.save_to_disk()
	if preset_error == OK and profile_error == OK:
		_set_status("Saved preset %d" % (_active_preset_slot + 1))
	else:
		_set_status("Preset save failed")
		push_warning("Unable to save streamer preset: %s / %s" % [preset_error, profile_error])

func _on_reset_defaults_pressed() -> void:
	if _is_refreshing:
		return

	var defaults: StreamerSettingsProfile = StreamerSettingsProfile.create_default_profile()
	_profile.apply_preset_values(defaults)
	_apply_profile_to_game(true)
	_refresh_controls()
	_save_profile("Defaults restored")

func _on_choose_character_pressed() -> void:
	_set_character_select_open(true)

func _on_character_close_pressed() -> void:
	_set_character_select_open(false)

func _on_character_button_pressed(index: int) -> void:
	if _is_refreshing:
		return

	_profile.streamer_avatar = int(clamp(index, 0, 3))
	_apply_profile_to_game(false)
	_refresh_avatar_labels()
	_save_profile("Saved streamer avatar")
	_set_character_select_open(false)

func _on_streamer_name_submitted(_text: String) -> void:
	_commit_streamer_name()

func _on_streamer_name_focus_exited() -> void:
	_commit_streamer_name()

func _on_tower_gun_selected(index: int) -> void:
	if _is_refreshing:
		return

	_profile.tower_gun = int(clamp(index, 0, 4))
	_apply_profile_to_game(false)
	_save_profile("Saved NPC loadout")

func _on_tower_weapon_toggled(enabled: bool) -> void:
	if _is_refreshing:
		return

	_profile.show_tower_weapons = enabled
	_apply_profile_to_game(false)
	_save_profile("Saved tower visuals")

func _on_premium_control_changed(_value: float) -> void:
	if _is_refreshing:
		return

	_refresh_chaos_meter_labels()
	_read_premium_controls()
	_apply_profile_to_game(true)
	_save_profile("Saved chaos controls")

func _on_reroll_pressed() -> void:
	if _is_map_change_locked():
		_set_status("Locked during round")
		return

	_apply_profile_to_game(true)
	_save_profile("Saved and rerolled street")


func _is_map_change_locked() -> bool:
	if _round_manager == null:
		return false
	return _round_manager.state in [
		RoundManager.RoundState.COUNTDOWN,
		RoundManager.RoundState.RUNNING,
		RoundManager.RoundState.PAUSED,
	]

func _commit_streamer_name() -> void:
	if _is_refreshing:
		return

	var clean_name: String = _streamer_name_edit.text.strip_edges()
	if clean_name.is_empty():
		clean_name = "Streamer"
		_streamer_name_edit.text = clean_name
	if clean_name == _profile.get_clean_streamer_name():
		return

	_profile.streamer_name = clean_name
	_apply_profile_to_game(false)
	_save_profile("Saved streamer name")

func _on_round_ended(_winner_name: String, _base_won: bool) -> void:
	_save_profile("Settings saved after run")

func _apply_profile_to_game(refresh_street_preview: bool) -> void:
	_profile.apply_to_configs(
		hazard_config,
		zombie_config,
		minigun_config,
		powerup_config,
		human_defender_config,
		visual_config,
		feature_config
	)

	if _race_map_controller != null:
		_race_map_controller.apply_profile(_profile)
	if _visual_settings_controller != null:
		_visual_settings_controller.apply_visual_settings()
	if refresh_street_preview:
		_refresh_street_preview()

func _refresh_street_preview() -> void:
	if _round_manager != null and _round_manager.get_state_text() != "Joining":
		return

	if _hazard_manager != null:
		var round_number: int = 0
		if _round_manager != null:
			round_number = _round_manager.round_number
		_hazard_manager.setup_preview(round_number)
	if _powerup_manager != null:
		_powerup_manager.clear_powerups()

func _save_profile(status_text: String) -> void:
	var error: Error = _profile.save_to_disk()
	if error == OK:
		_set_status(status_text)
	else:
		_set_status("Settings save failed")
		push_warning("Unable to save streamer settings: %s" % error)

func _refresh_balance_labels() -> void:
	if _balance_value_label != null:
		_balance_value_label.text = _profile.get_balance_name()
	if _balance_detail_label != null:
		_balance_detail_label.text = _profile.get_balance_detail()

func _refresh_menu_tier_controls() -> void:
	var premium_enabled: bool = _has_premium_access()
	if _edition_value_label != null:
		_edition_value_label.text = _profile.get_menu_tier_name(feature_config)
	if _menu_tier_detail_label != null:
		_menu_tier_detail_label.text = _profile.get_menu_tier_detail(feature_config)
	if _map_row != null:
		_map_row.visible = true
	if _save_preset_button != null:
		_save_preset_button.visible = true
	if _reset_defaults_button != null:
		_reset_defaults_button.visible = true
	if _premium_controls != null:
		_premium_controls.visible = true
	if _tower_gun_row != null:
		_tower_gun_row.visible = true
	if _tower_weapon_row != null:
		_tower_weapon_row.visible = true

func _refresh_avatar_labels() -> void:
	if _avatar_value_label != null:
		_avatar_value_label.text = _profile.get_avatar_name()

	var buttons: Array[Button] = [_matt_button, _lis_button, _sam_button, _shaun_button]
	var names: PackedStringArray = PackedStringArray(["Matt", "Lis", "Sam", "Shaun"])
	for index in range(buttons.size()):
		if buttons[index] == null:
			continue
		buttons[index].text = "SELECTED" if index == _profile.streamer_avatar else "Pick %s" % names[index]

func _refresh_preset_buttons() -> void:
	var buttons: Array[Button] = [_preset_button_1, _preset_button_2, _preset_button_3, _preset_button_4]
	for index in range(buttons.size()):
		if buttons[index] == null:
			continue
		var suffix: String = " *" if index == _active_preset_slot else ""
		buttons[index].text = "Preset %d%s" % [index + 1, suffix]

func _set_character_select_open(open: bool) -> void:
	if _character_overlay_wash != null:
		_character_overlay_wash.visible = open
	if _character_select_panel != null:
		_character_select_panel.visible = open
	if _settings_modal != null:
		_settings_modal.visible = not open and _root != null and _root.visible
	if open:
		_refresh_avatar_labels()

func _sanitize_character_previews() -> void:
	var grid: Control = get_node_or_null("Root/CharacterSelectPanel/Margin/VBox/CharacterGrid") as Control
	if grid == null:
		return

	for card_node in grid.get_children():
		var card: Node = card_node as Node
		if card == null:
			continue
		var model: Node = card.get_node_or_null("Margin/VBox/Preview/Viewport/Model")
		KitCharacterVisuals.set_weapon_nodes_visible(model)

func _set_status(status_text: String) -> void:
	_status_text = status_text
	if _status_label != null:
		_status_label.text = status_text
	_refresh_world_menu()

func _populate_options() -> void:
	_set_option_items(_time_of_day_option, PackedStringArray(["Night", "Day"]))
	_set_option_items(_backdrop_option, PackedStringArray(["City", "Industrial", "Skyline"]))
	_set_option_items(_tower_gun_option, PackedStringArray(["Random", "Pistol", "SMG", "Rifle", "Shotgun"]))
	_populate_map_options()

func _sync_profile_from_controls() -> void:
	_profile.audience_balance = int(round(_balance_slider.value))
	_profile.time_of_day = int(clamp(_time_of_day_option.selected, 0, 1))
	_profile.backdrop_style = int(clamp(_backdrop_option.selected, 0, 2))
	_profile.set_selected_settings_map_index(_get_settings_map_index_for_option(_map_option.selected))
	_profile.tower_gun = int(clamp(_tower_gun_option.selected, 0, 4))
	_profile.show_tower_weapons = _tower_weapon_check.button_pressed
	var clean_name: String = _streamer_name_edit.text.strip_edges()
	if clean_name.is_empty():
		clean_name = "Streamer"
		_streamer_name_edit.text = clean_name
	_profile.streamer_name = clean_name
	_read_premium_controls()

func _refresh_chaos_meter_labels() -> void:
	_set_meter_label(_mine_spin, _mine_meter_label)
	_set_meter_label(_street_prop_spin, _street_prop_meter_label)
	_set_meter_label(_boost_pad_spin, _boost_pad_meter_label)
	_set_meter_label(_sewer_spin, _sewer_meter_label)
	_set_meter_label(_defender_spin, _defender_meter_label)
	_set_meter_label(_vehicle_weight_spin, _vehicle_weight_meter_label)
	_set_meter_label(_cone_weight_spin, _cone_weight_meter_label)
	_set_meter_label(_barrier_weight_spin, _barrier_weight_meter_label)

func _set_meter_label(slider: SliderControl, label: Label) -> void:
	if slider == null or label == null:
		return
	label.text = str(int(round(slider.value)))

func _read_premium_controls() -> void:
	if _mine_spin == null:
		return

	_profile.premium_mine_count = int(round(_mine_spin.value))
	_profile.premium_obstacle_count = int(round(_street_prop_spin.value))
	_profile.premium_boost_pad_count = int(round(_boost_pad_spin.value))
	_profile.premium_sewer_hole_count = int(round(_sewer_spin.value))
	_profile.premium_defender_count = int(round(_defender_spin.value))
	_profile.premium_vehicle_weight = int(round(_vehicle_weight_spin.value))
	_profile.premium_cone_weight = int(round(_cone_weight_spin.value))
	_profile.premium_barrier_weight = int(round(_barrier_weight_spin.value))

func _set_option_items(option_button: OptionButton, labels: PackedStringArray) -> void:
	if option_button == null:
		return

	option_button.clear()
	for label in labels:
		option_button.add_item(str(label))

func _clamped_option_index(option_button: OptionButton, selected_index: int) -> int:
	if option_button == null or option_button.get_item_count() <= 0:
		return 0
	return int(clamp(selected_index, 0, option_button.get_item_count() - 1))

func _populate_map_options() -> void:
	if _map_option == null:
		return

	_map_option.clear()
	var settings_entries: Array[Dictionary] = MapCatalog.get_selectable_entries_for_settings()
	for entry in settings_entries:
		var settings_index: int = int(entry.get("settings_index", 0))
		var display_name: String = str(entry.get("display_name", "City Highway"))
		_map_option.add_item(display_name, settings_index)

	if _map_option.get_item_count() <= 0:
		_map_option.add_item("City Highway", 0)


func _select_map_option_by_settings_index(settings_index: int) -> void:
	if _map_option == null or _map_option.get_item_count() <= 0:
		return

	var allowed_settings_index: int = settings_index
	if _race_map_controller != null:
		allowed_settings_index = _race_map_controller.get_allowed_map_index(settings_index)
	for option_index in range(_map_option.get_item_count()):
		if _map_option.get_item_id(option_index) == allowed_settings_index:
			_map_option.select(option_index)
			return
	_map_option.select(0)


func _get_settings_map_index_for_option(option_index: int) -> int:
	if _map_option == null or _map_option.get_item_count() <= 0:
		return 0
	var clamped_option_index: int = int(clamp(option_index, 0, _map_option.get_item_count() - 1))
	return int(_map_option.get_item_id(clamped_option_index))


func _get_selected_map_name() -> String:
	var settings_index: int = _profile.get_selected_settings_map_index()
	if _race_map_controller != null:
		return _race_map_controller.get_map_name(settings_index)
	var entry: Dictionary = MapCatalog.get_settings_entry(settings_index)
	return str(entry.get("display_name", "City Highway"))


func get_selected_map_name() -> String:
	return _get_selected_map_name()


func get_selected_map_definition() -> RaceMapDefinition:
	return MapCatalog.load_definition_for_settings_index(_profile.get_selected_settings_map_index())


func get_selected_settings_map_index() -> int:
	return _profile.get_selected_settings_map_index()


func get_lobby_map_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = MapCatalog.get_selectable_entries_for_settings()
	if _has_premium_access():
		return entries
	if entries.is_empty():
		return []
	return [entries[0]]


func select_map_from_lobby(settings_index: int) -> bool:
	if _is_map_change_locked():
		_set_status("Map locked during round")
		return false
	if not _has_premium_access() and settings_index != 0:
		_set_status("Map selection requires Paid Premium")
		return false
	if _round_manager != null and _round_manager.state == RoundManager.RoundState.ENDED:
		_round_manager.reset_round()
	_profile.set_selected_settings_map_index(settings_index)
	_apply_profile_to_game(true)
	_refresh_controls()
	_save_profile("Saved map: %s" % _get_selected_map_name())
	return true

func _has_premium_access() -> bool:
	return feature_config != null and feature_config.has_premium_access()

func _connect_world_button(button: MainMenu3DButton) -> void:
	if button == null:
		return
	if not button.pressed.is_connected(_on_world_button_pressed):
		button.pressed.connect(_on_world_button_pressed)

func _on_world_button_pressed(action_id: StringName) -> void:
	match action_id:
		&"close":
			close_menu()
		&"map_next":
			_cycle_world_map()
		&"balance_down":
			_adjust_world_balance(-20)
		&"balance_up":
			_adjust_world_balance(20)
		&"lighting_next":
			_cycle_world_lighting()
		&"backdrop_next":
			_cycle_world_backdrop()
		&"avatar_next":
			_cycle_world_avatar()
		&"reroll":
			_on_reroll_pressed()
		&"save":
			_on_save_preset_pressed()
		&"preset_1":
			_on_preset_button_pressed(0)
		&"preset_2":
			_on_preset_button_pressed(1)
		&"preset_3":
			_on_preset_button_pressed(2)
		&"preset_4":
			_on_preset_button_pressed(3)
		&"reset_defaults":
			_on_reset_defaults_pressed()

func _set_world_menu_visible(open: bool) -> void:
	if open:
		_hide_peer_world_roots()
	if _world_menu_root != null:
		_world_menu_root.visible = open
	_set_world_buttons_interactable(open)
	if open:
		_refresh_world_menu()
	else:
		_restore_peer_world_roots()

func _refresh_world_menu() -> void:
	if _world_summary_board != null:
		_world_summary_board.set_board_text("STREAMER SETTINGS", _format_world_settings_body())
	_refresh_world_preset_button_text()

func _format_world_settings_body() -> String:
	var edition_text: String = _profile.get_menu_tier_name(feature_config)
	var map_text: String = _get_selected_map_name()
	var balance_text: String = _profile.get_balance_name()
	var time_text: String = _profile.get_time_of_day_name()
	var backdrop_text: String = _get_backdrop_name()
	var avatar_text: String = _profile.get_avatar_name()
	var street_text_a: String = "Mines %d | Props %d | Boosts %d" % [
		_profile.premium_mine_count,
		_profile.premium_obstacle_count,
		_profile.premium_boost_pad_count
	]
	var street_text_b: String = "Sewers %d | Defenders %d" % [
		_profile.premium_sewer_hole_count,
		_profile.premium_defender_count
	]
	return "Edition  %s\nMap  %s\nAuto Repeat  %s\nPreset  %d\nBalance  %s\nLighting  %s  Backdrop  %s\nStreamer  %s  Avatar  %s\n%s\n%s\nStatus  %s" % [
		edition_text,
		map_text,
		"on" if _round_manager != null and _round_manager.is_auto_repeat_enabled() else "off",
		_active_preset_slot + 1,
		balance_text,
		time_text,
		backdrop_text,
		_profile.get_clean_streamer_name(),
		avatar_text,
		street_text_a,
		street_text_b,
		_status_text
	]

func _hide_peer_world_roots() -> void:
	_hidden_world_roots.clear()
	for root in _collect_peer_world_roots():
		_hidden_world_roots[str(root.get_path())] = root.visible
		root.visible = false

func _restore_peer_world_roots() -> void:
	for root_path in _hidden_world_roots.keys():
		var root: Node3D = get_node_or_null(NodePath(str(root_path))) as Node3D
		if root != null:
			root.visible = _should_restore_world_root_visible(str(root_path), bool(_hidden_world_roots[root_path]))
	_hidden_world_roots.clear()

func _should_restore_world_root_visible(root_path: String, was_visible: bool) -> bool:
	return was_visible

func _collect_peer_world_roots() -> Array[Node3D]:
	var roots: Array[Node3D] = []
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return roots

	var root_paths: Array[String] = [
		"GameSettings3D",
	]
	for root_path in root_paths:
		var root: Node3D = camera.get_node_or_null(root_path) as Node3D
		if root != null and root != _world_menu_root:
			roots.append(root)
	return roots

func _refresh_world_preset_button_text() -> void:
	var buttons: Array[MainMenu3DButton] = [
		_world_preset_1_button,
		_world_preset_2_button,
		_world_preset_3_button,
		_world_preset_4_button,
	]
	for index in range(buttons.size()):
		if buttons[index] == null:
			continue
		var suffix: String = "*" if index == _active_preset_slot else ""
		buttons[index].set_button_text("P%d%s" % [index + 1, suffix])

func _set_world_buttons_interactable(enabled: bool) -> void:
	var buttons: Array[MainMenu3DButton] = [
		_world_close_button,
		_world_map_button,
		_world_balance_down_button,
		_world_balance_up_button,
		_world_lighting_button,
		_world_backdrop_button,
		_world_avatar_button,
		_world_reroll_button,
		_world_save_button,
		_world_preset_1_button,
		_world_preset_2_button,
		_world_preset_3_button,
		_world_preset_4_button,
		_world_reset_button,
	]
	for button in buttons:
		if button != null:
			button.set_interactable(enabled)

func _cycle_world_map() -> void:
	if not _has_premium_access():
		_set_status("Premium required")
		return
	if _map_option == null or _map_option.get_item_count() <= 0:
		return
	var next_index: int = (_map_option.selected + 1) % _map_option.get_item_count()
	_on_map_selected(next_index)

func _adjust_world_balance(delta: int) -> void:
	_profile.audience_balance = int(clamp(_profile.audience_balance + delta, 0, 100))
	_apply_profile_to_game(true)
	_refresh_controls()
	_save_profile("Saved: %s" % _profile.get_balance_name())

func _cycle_world_lighting() -> void:
	_profile.time_of_day = (_profile.time_of_day + 1) % 2
	_apply_profile_to_game(false)
	_refresh_controls()
	_save_profile("Saved: %s lighting" % _profile.get_time_of_day_name())

func _cycle_world_backdrop() -> void:
	_profile.backdrop_style = (_profile.backdrop_style + 1) % 3
	_apply_profile_to_game(false)
	_refresh_controls()
	_save_profile("Saved backdrop")

func _cycle_world_avatar() -> void:
	_profile.streamer_avatar = (_profile.streamer_avatar + 1) % 4
	_apply_profile_to_game(false)
	_refresh_controls()
	_save_profile("Saved streamer avatar")

func _get_backdrop_name() -> String:
	var names: PackedStringArray = PackedStringArray(["City", "Industrial", "Skyline"])
	var index: int = int(clamp(_profile.backdrop_style, 0, names.size() - 1))
	return names[index]
