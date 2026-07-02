class_name StreamerMenuController
extends CanvasLayer

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

var _round_manager: RoundManager
var _hazard_manager: HazardManager
var _powerup_manager: PowerupManager
var _race_map_controller: RaceMapController
var _visual_settings_controller: VisualSettingsController
var _profile: StreamerSettingsProfile = StreamerSettingsProfile.new()
var _is_refreshing: bool = false
var _active_preset_slot: int = 0

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
@onready var _tower_weapon_check: CheckBox = get_node("Root/MenuPanel/Margin/VBox/TowerWeaponRow/TowerWeaponCheck") as CheckBox
@onready var _premium_scroll: ScrollContainer = get_node("Root/MenuPanel/Margin/VBox/PremiumScroll") as ScrollContainer
@onready var _premium_controls: VBoxContainer = get_node("Root/MenuPanel/Margin/VBox/PremiumScroll/PremiumControls") as VBoxContainer
@onready var _mine_spin: SpinBox = get_node("Root/MenuPanel/Margin/VBox/PremiumScroll/PremiumControls/MineRow/MineSpin") as SpinBox
@onready var _street_prop_spin: SpinBox = get_node("Root/MenuPanel/Margin/VBox/PremiumScroll/PremiumControls/StreetPropRow/StreetPropSpin") as SpinBox
@onready var _boost_pad_spin: SpinBox = get_node("Root/MenuPanel/Margin/VBox/PremiumScroll/PremiumControls/BoostPadRow/BoostPadSpin") as SpinBox
@onready var _sewer_spin: SpinBox = get_node("Root/MenuPanel/Margin/VBox/PremiumScroll/PremiumControls/SewerRow/SewerSpin") as SpinBox
@onready var _defender_spin: SpinBox = get_node("Root/MenuPanel/Margin/VBox/PremiumScroll/PremiumControls/DefenderRow/DefenderSpin") as SpinBox
@onready var _vehicle_weight_spin: SpinBox = get_node("Root/MenuPanel/Margin/VBox/PremiumScroll/PremiumControls/VehicleWeightRow/VehicleWeightSpin") as SpinBox
@onready var _cone_weight_spin: SpinBox = get_node("Root/MenuPanel/Margin/VBox/PremiumScroll/PremiumControls/ConeWeightRow/ConeWeightSpin") as SpinBox
@onready var _barrier_weight_spin: SpinBox = get_node("Root/MenuPanel/Margin/VBox/PremiumScroll/PremiumControls/BarrierWeightRow/BarrierWeightSpin") as SpinBox
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
	_mine_spin.value_changed.connect(_on_premium_control_changed)
	_street_prop_spin.value_changed.connect(_on_premium_control_changed)
	_boost_pad_spin.value_changed.connect(_on_premium_control_changed)
	_sewer_spin.value_changed.connect(_on_premium_control_changed)
	_defender_spin.value_changed.connect(_on_premium_control_changed)
	_vehicle_weight_spin.value_changed.connect(_on_premium_control_changed)
	_cone_weight_spin.value_changed.connect(_on_premium_control_changed)
	_barrier_weight_spin.value_changed.connect(_on_premium_control_changed)
	GameEvents.round_ended.connect(_on_round_ended)

	_sanitize_character_previews()
	_refresh_controls()
	_set_menu_open(false)
	_set_character_select_open(false)
	_set_status("Settings loaded")

func _on_toggle_pressed() -> void:
	_set_menu_open(not _menu_panel.visible)

func open_menu() -> void:
	if not _has_premium_access():
		_set_menu_open(false)
		return

	_set_menu_open(true)

func close_menu() -> void:
	_set_menu_open(false)

func _set_menu_open(open: bool) -> void:
	_menu_panel.visible = open
	_toggle_button.visible = open
	_toggle_button.text = "Close"
	if not open:
		_set_character_select_open(false)

func _refresh_controls() -> void:
	_is_refreshing = true
	_balance_slider.value = _profile.audience_balance
	_streamer_name_edit.text = _profile.get_clean_streamer_name()
	_time_of_day_option.select(_clamped_option_index(_time_of_day_option, _profile.time_of_day))
	_backdrop_option.select(_clamped_option_index(_backdrop_option, _profile.backdrop_style))
	_select_map_option(_profile.selected_map_index)
	_tower_gun_option.select(_clamped_option_index(_tower_gun_option, _profile.tower_gun))
	_tower_weapon_check.button_pressed = _profile.show_tower_weapons
	_mine_spin.value = _profile.premium_mine_count
	_street_prop_spin.value = _profile.premium_obstacle_count
	_boost_pad_spin.value = _profile.premium_boost_pad_count
	_sewer_spin.value = _profile.premium_sewer_hole_count
	_defender_spin.value = _profile.premium_defender_count
	_vehicle_weight_spin.value = _profile.premium_vehicle_weight
	_cone_weight_spin.value = _profile.premium_cone_weight
	_barrier_weight_spin.value = _profile.premium_barrier_weight
	_refresh_menu_tier_controls()
	_refresh_balance_labels()
	_refresh_avatar_labels()
	_refresh_preset_buttons()
	_is_refreshing = false

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
	if not _has_premium_access():
		return
	if _round_manager != null and _round_manager.get_state_text() != "Joining":
		_refresh_controls()
		_set_status("Map locked during round")
		return

	_profile.selected_map_index = _get_map_index_for_option(option_index)
	_apply_profile_to_game(true)
	_refresh_controls()
	_save_profile("Saved map: %s" % _get_selected_map_name())

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

	_read_premium_controls()
	_apply_profile_to_game(true)
	_save_profile("Saved premium controls")

func _on_reroll_pressed() -> void:
	if _round_manager != null and _round_manager.get_state_text() != "Joining":
		_set_status("Locked during round")
		return

	_apply_profile_to_game(true)
	_save_profile("Saved and rerolled street")

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
		_map_row.visible = premium_enabled
	if _save_preset_button != null:
		_save_preset_button.visible = premium_enabled
	if _reset_defaults_button != null:
		_reset_defaults_button.visible = premium_enabled
	if _premium_scroll != null:
		_premium_scroll.visible = premium_enabled
	if _premium_controls != null:
		_premium_controls.visible = premium_enabled
	if _tower_gun_row != null:
		_tower_gun_row.visible = premium_enabled
	if _tower_weapon_row != null:
		_tower_weapon_row.visible = premium_enabled

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
	if _status_label != null:
		_status_label.text = status_text

func _populate_options() -> void:
	_set_option_items(_time_of_day_option, PackedStringArray(["Night", "Day"]))
	_set_option_items(_backdrop_option, PackedStringArray(["City", "Industrial", "Skyline"]))
	_set_option_items(_tower_gun_option, PackedStringArray(["Random", "Pistol", "SMG", "Rifle", "Shotgun"]))
	_populate_map_options()

func _sync_profile_from_controls() -> void:
	_profile.audience_balance = int(round(_balance_slider.value))
	_profile.time_of_day = int(clamp(_time_of_day_option.selected, 0, 1))
	_profile.backdrop_style = int(clamp(_backdrop_option.selected, 0, 2))
	_profile.selected_map_index = _get_map_index_for_option(_map_option.selected)
	_profile.tower_gun = int(clamp(_tower_gun_option.selected, 0, 4))
	_profile.show_tower_weapons = _tower_weapon_check.button_pressed
	var clean_name: String = _streamer_name_edit.text.strip_edges()
	if clean_name.is_empty():
		clean_name = "Streamer"
		_streamer_name_edit.text = clean_name
	_profile.streamer_name = clean_name
	_read_premium_controls()

func _read_premium_controls() -> void:
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
	if _race_map_controller == null:
		_map_option.add_item("Quarantine Boulevard", 0)
		return

	for map_index in range(_race_map_controller.get_map_count()):
		if not _race_map_controller.is_map_available(map_index):
			continue
		_map_option.add_item(_race_map_controller.get_map_name(map_index), map_index)

	if _map_option.get_item_count() <= 0:
		_map_option.add_item("Quarantine Boulevard", 0)

func _select_map_option(map_index: int) -> void:
	if _map_option == null or _map_option.get_item_count() <= 0:
		return

	var allowed_map_index: int = map_index
	if _race_map_controller != null:
		allowed_map_index = _race_map_controller.get_allowed_map_index(map_index)
	for option_index in range(_map_option.get_item_count()):
		if _map_option.get_item_id(option_index) == allowed_map_index:
			_map_option.select(option_index)
			return
	_map_option.select(0)

func _get_map_index_for_option(option_index: int) -> int:
	if _map_option == null or _map_option.get_item_count() <= 0:
		return 0
	var clamped_option_index: int = int(clamp(option_index, 0, _map_option.get_item_count() - 1))
	return _map_option.get_item_id(clamped_option_index)

func _get_selected_map_name() -> String:
	if _race_map_controller != null:
		return _race_map_controller.get_map_name(_race_map_controller.get_allowed_map_index(_profile.selected_map_index))
	return "Quarantine Boulevard"

func _has_premium_access() -> bool:
	return feature_config != null and feature_config.has_premium_access()
