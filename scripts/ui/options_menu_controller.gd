class_name OptionsMenuController
extends CanvasLayer

const SETTINGS_MODAL_SCRIPT: Script = preload("res://scripts/ui/settings_modal.gd")

@export var streamer_settings_applier_path: NodePath
@export var hazard_manager_path: NodePath
@export var powerup_manager_path: NodePath
@export var round_manager_path: NodePath

var _settings_applier: StreamerSettingsApplier
var _hazard_manager: HazardManager
var _powerup_manager: PowerupManager
var _round_manager: RoundManager
var _profile: StreamerSettingsProfile = StreamerSettingsProfile.new()
var _settings_modal: SettingsModal
var _difficulty_slider: SliderControl
var _difficulty_value_label: Label
var _difficulty_detail_label: Label
var _is_refreshing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_settings_applier = get_node_or_null(streamer_settings_applier_path) as StreamerSettingsApplier
	_hazard_manager = get_node_or_null(hazard_manager_path) as HazardManager
	_powerup_manager = get_node_or_null(powerup_manager_path) as PowerupManager
	_round_manager = get_node_or_null(round_manager_path) as RoundManager
	_profile = StreamerSettingsProfile.load_from_disk()
	_build_modal()


func open_menu() -> void:
	_profile = StreamerSettingsProfile.load_from_disk()
	_refresh_controls()
	visible = true
	if _settings_modal != null:
		_settings_modal.show_modal()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_menu() -> void:
	visible = false
	if _settings_modal != null:
		_settings_modal.hide_modal()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()


func _build_modal() -> void:
	_settings_modal = SETTINGS_MODAL_SCRIPT.new() as SettingsModal
	if _settings_modal == null:
		return

	_settings_modal.name = "OptionsModal"
	add_child(_settings_modal)
	_settings_modal.set_title("Options")
	_settings_modal.close_pressed.connect(close_menu)
	_settings_modal.done_pressed.connect(close_menu)
	_settings_modal.reset_pressed.connect(_on_reset_defaults_pressed)
	_settings_modal.clear_groups()

	var gameplay_group: VBoxContainer = _settings_modal.add_group("Gameplay")
	_difficulty_value_label = Label.new()
	ControlRoomTheme.apply_label(_difficulty_value_label, 19, ControlRoomTheme.COLOR_GREEN)
	_difficulty_detail_label = Label.new()
	_difficulty_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ControlRoomTheme.apply_label(_difficulty_detail_label, 16, ControlRoomTheme.COLOR_MUTED)

	var difficulty_pair: Dictionary = _make_slider_value_pair(_difficulty_value_label)
	_difficulty_slider = difficulty_pair["slider"] as SliderControl
	_settings_modal.add_row(gameplay_group, "Difficulty", difficulty_pair["root"] as Control)
	gameplay_group.add_child(_difficulty_detail_label)

	var hint_label := Label.new()
	hint_label.text = "Streamer friendly ← → Chat friendly"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ControlRoomTheme.apply_label(hint_label, 15, ControlRoomTheme.COLOR_MUTED)
	gameplay_group.add_child(hint_label)

	_difficulty_slider.value_changed.connect(_on_difficulty_changed)
	_refresh_controls()


func _make_slider_value_pair(value_label: Label) -> Dictionary:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var slider := SliderControl.new()
	box.add_child(slider)
	value_label.custom_minimum_size = Vector2(180, 0)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(value_label)
	return {"root": box, "slider": slider}


func _refresh_controls() -> void:
	_is_refreshing = true
	if _difficulty_slider != null:
		_difficulty_slider.value = _profile.audience_balance
	_refresh_difficulty_labels()
	_is_refreshing = false


func _refresh_difficulty_labels() -> void:
	if _difficulty_value_label != null:
		_difficulty_value_label.text = _profile.get_balance_name()
	if _difficulty_detail_label != null:
		_difficulty_detail_label.text = _profile.get_balance_detail()


func _on_difficulty_changed(value: float) -> void:
	if _is_refreshing:
		return

	_profile.audience_balance = int(round(value))
	_apply_difficulty()
	_refresh_difficulty_labels()


func _on_reset_defaults_pressed() -> void:
	_profile.audience_balance = StreamerSettingsProfile.create_default_profile().audience_balance
	_apply_difficulty()
	_refresh_controls()


func _apply_difficulty() -> void:
	var error: Error = _profile.save_to_disk()
	if error != OK:
		push_warning("Unable to save options: %s" % error)
		return

	if _settings_applier != null:
		_settings_applier.reload_and_apply()
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
