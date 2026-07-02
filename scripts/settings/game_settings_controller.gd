class_name GameSettingsController
extends CanvasLayer

const CONFIG_PATH := "user://game_settings.cfg"
const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

const QUALITY_LABELS: Array[String] = ["Low", "Medium", "High", "Ultra"]
const DISPLAY_MODE_LABELS: Array[String] = ["Windowed", "Borderless", "Fullscreen"]
const FPS_CAP_LABELS: Array[String] = ["Unlimited", "60", "120", "144", "240"]
const FPS_CAP_VALUES: Array[int] = [0, 60, 120, 144, 240]

const CONTROL_ACTIONS: Array[String] = [
	"camera_forward",
	"camera_back",
	"camera_left",
	"camera_right",
	"camera_up",
	"camera_down",
	"camera_boost",
	"camera_overview",
	"camera_director",
	"round_start",
	"round_reset",
	"debug_join",
]

const CONTROL_LABELS: Dictionary = {
	"camera_forward": "Camera Forward",
	"camera_back": "Camera Back",
	"camera_left": "Camera Left",
	"camera_right": "Camera Right",
	"camera_up": "Camera Up",
	"camera_down": "Camera Down",
	"camera_boost": "Camera Sprint",
	"camera_overview": "Overview Camera",
	"camera_director": "Director Camera",
	"round_start": "Start Round",
	"round_reset": "Reset Round",
	"debug_join": "Add Test Join",
}

const DEFAULT_ACTION_BINDINGS: Dictionary = {
	"camera_forward": [KEY_W, KEY_UP],
	"camera_back": [KEY_S, KEY_DOWN],
	"camera_left": [KEY_A, KEY_LEFT],
	"camera_right": [KEY_D, KEY_RIGHT],
	"camera_up": [KEY_SPACE],
	"camera_down": [KEY_Q],
	"camera_boost": [KEY_SHIFT],
	"camera_overview": [KEY_C],
	"camera_director": [KEY_F],
	"round_start": [KEY_ENTER],
	"round_reset": [KEY_R],
	"debug_join": [KEY_J],
}

var _master_volume: float = 1.0
var _music_volume: float = 0.9
var _sfx_volume: float = 0.95
var _audio_muted: bool = false
var _graphics_quality_index: int = 2
var _display_mode_index: int = 0
var _vsync_enabled: bool = true
var _fps_cap_index: int = 0
var _bindings: Dictionary = {}
var _control_buttons: Dictionary = {}
var _waiting_for_action: String = ""
var _is_refreshing: bool = false

@onready var _root: Control = get_node("Root") as Control
@onready var _tabs: TabContainer = get_node("Root/Panel/Margin/VBox/Tabs") as TabContainer
@onready var _close_button: Button = get_node("Root/Panel/Margin/VBox/Header/CloseButton") as Button
@onready var _master_slider: HSlider = get_node("Root/Panel/Margin/VBox/Tabs/Audio/AudioControls/MasterRow/MasterSlider") as HSlider
@onready var _master_value_label: Label = get_node("Root/Panel/Margin/VBox/Tabs/Audio/AudioControls/MasterRow/MasterValueLabel") as Label
@onready var _music_slider: HSlider = get_node("Root/Panel/Margin/VBox/Tabs/Audio/AudioControls/MusicRow/MusicSlider") as HSlider
@onready var _music_value_label: Label = get_node("Root/Panel/Margin/VBox/Tabs/Audio/AudioControls/MusicRow/MusicValueLabel") as Label
@onready var _sfx_slider: HSlider = get_node("Root/Panel/Margin/VBox/Tabs/Audio/AudioControls/SfxRow/SfxSlider") as HSlider
@onready var _sfx_value_label: Label = get_node("Root/Panel/Margin/VBox/Tabs/Audio/AudioControls/SfxRow/SfxValueLabel") as Label
@onready var _mute_check: CheckBox = get_node("Root/Panel/Margin/VBox/Tabs/Audio/AudioControls/MuteCheck") as CheckBox
@onready var _test_sfx_button: Button = get_node("Root/Panel/Margin/VBox/Tabs/Audio/AudioControls/TestSfxButton") as Button
@onready var _quality_option: OptionButton = get_node("Root/Panel/Margin/VBox/Tabs/Graphics/GraphicsControls/QualityRow/QualityOption") as OptionButton
@onready var _display_mode_option: OptionButton = get_node("Root/Panel/Margin/VBox/Tabs/Graphics/GraphicsControls/DisplayModeRow/DisplayModeOption") as OptionButton
@onready var _vsync_check: CheckBox = get_node("Root/Panel/Margin/VBox/Tabs/Graphics/GraphicsControls/VsyncCheck") as CheckBox
@onready var _fps_cap_option: OptionButton = get_node("Root/Panel/Margin/VBox/Tabs/Graphics/GraphicsControls/FpsCapRow/FpsCapOption") as OptionButton
@onready var _controls_list: VBoxContainer = get_node("Root/Panel/Margin/VBox/Tabs/Controls/ControlsMargin/ControlsScroll/ControlsList") as VBoxContainer
@onready var _controls_status_label: Label = get_node("Root/Panel/Margin/VBox/Tabs/Controls/ControlsMargin/ControlsStatusLabel") as Label
@onready var _reset_controls_button: Button = get_node("Root/Panel/Margin/VBox/Tabs/Controls/ControlsMargin/ResetControlsButton") as Button
@onready var _reset_all_button: Button = get_node("Root/Panel/Margin/VBox/Footer/ResetAllButton") as Button
@onready var _streamer_controls_button: Button = get_node("Root/Panel/Margin/VBox/Footer/StreamerControlsButton") as Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_test_sfx_button.set_meta("_zh_sfx_skip_button", true)
	_ensure_audio_buses()
	_load_settings()
	_populate_static_options()
	_build_control_rows()
	_connect_controls()
	_apply_all_settings()
	_refresh_controls()

func open_settings(tab_name: String = "") -> void:
	_refresh_streamer_controls_button()
	visible = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if tab_name == "audio":
		_tabs.current_tab = 0
	elif tab_name == "graphics":
		_tabs.current_tab = 1
	elif tab_name == "controls":
		_tabs.current_tab = 2

func close_settings() -> void:
	_waiting_for_action = ""
	visible = false
	_root.visible = false
	_refresh_control_buttons()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	var key_code: int = key_event.physical_keycode
	if key_code == 0:
		key_code = key_event.keycode

	if not _waiting_for_action.is_empty():
		if key_code == KEY_ESCAPE:
			_waiting_for_action = ""
			_set_controls_status("Rebind canceled")
			_refresh_control_buttons()
			get_viewport().set_input_as_handled()
			return

		_set_primary_binding(_waiting_for_action, key_code)
		_waiting_for_action = ""
		_save_settings()
		_apply_control_bindings()
		_refresh_control_buttons()
		_set_controls_status("Saved")
		get_viewport().set_input_as_handled()
		return

	if key_code == KEY_ESCAPE:
		close_settings()
		get_viewport().set_input_as_handled()

func _connect_controls() -> void:
	_close_button.pressed.connect(close_settings)
	_master_slider.value_changed.connect(_on_master_volume_changed)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_mute_check.toggled.connect(_on_mute_toggled)
	_test_sfx_button.pressed.connect(_on_test_sfx_pressed)
	_quality_option.item_selected.connect(_on_quality_selected)
	_display_mode_option.item_selected.connect(_on_display_mode_selected)
	_vsync_check.toggled.connect(_on_vsync_toggled)
	_fps_cap_option.item_selected.connect(_on_fps_cap_selected)
	_reset_controls_button.pressed.connect(_on_reset_controls_pressed)
	_reset_all_button.pressed.connect(_on_reset_all_pressed)
	_streamer_controls_button.pressed.connect(_on_streamer_controls_pressed)

func _populate_static_options() -> void:
	_set_option_items(_quality_option, QUALITY_LABELS)
	_set_option_items(_display_mode_option, DISPLAY_MODE_LABELS)
	_set_option_items(_fps_cap_option, FPS_CAP_LABELS)

func _build_control_rows() -> void:
	for child in _controls_list.get_children():
		child.queue_free()

	_control_buttons.clear()
	for action_name in CONTROL_ACTIONS:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_controls_list.add_child(row)

		var label: Label = Label.new()
		label.custom_minimum_size = Vector2(230, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = str(CONTROL_LABELS.get(action_name, action_name))
		row.add_child(label)

		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(190, 36)
		button.text = _format_binding(action_name)
		button.pressed.connect(_on_rebind_pressed.bind(action_name))
		row.add_child(button)
		_control_buttons[action_name] = button

func _refresh_controls() -> void:
	_is_refreshing = true
	_master_slider.value = round(_master_volume * 100.0)
	_music_slider.value = round(_music_volume * 100.0)
	_sfx_slider.value = round(_sfx_volume * 100.0)
	_mute_check.button_pressed = _audio_muted
	_quality_option.select(_graphics_quality_index)
	_display_mode_option.select(_display_mode_index)
	_vsync_check.button_pressed = _vsync_enabled
	_fps_cap_option.select(_fps_cap_index)
	_refresh_volume_labels()
	_refresh_control_buttons()
	_set_controls_status("Ready")
	_is_refreshing = false

func _refresh_volume_labels() -> void:
	_master_value_label.text = "%d%%" % int(round(_master_volume * 100.0))
	_music_value_label.text = "%d%%" % int(round(_music_volume * 100.0))
	_sfx_value_label.text = "%d%%" % int(round(_sfx_volume * 100.0))

func _refresh_control_buttons() -> void:
	for action_name in CONTROL_ACTIONS:
		var button: Button = _control_buttons.get(action_name) as Button
		if button == null:
			continue
		if action_name == _waiting_for_action:
			button.text = "Press a key"
		else:
			button.text = _format_binding(action_name)

func _refresh_streamer_controls_button() -> void:
	var streamer_menu: StreamerMenuController = _get_streamer_menu()
	_streamer_controls_button.visible = streamer_menu != null and streamer_menu.can_open_menu()

func _on_master_volume_changed(value: float) -> void:
	if _is_refreshing:
		return
	_master_volume = clamp(value / 100.0, 0.0, 1.0)
	_apply_audio_settings()
	_refresh_volume_labels()
	_save_settings()

func _on_music_volume_changed(value: float) -> void:
	if _is_refreshing:
		return
	_music_volume = clamp(value / 100.0, 0.0, 1.0)
	_apply_audio_settings()
	_refresh_volume_labels()
	_save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	if _is_refreshing:
		return
	_sfx_volume = clamp(value / 100.0, 0.0, 1.0)
	_apply_audio_settings()
	_refresh_volume_labels()
	_save_settings()

func _on_mute_toggled(enabled: bool) -> void:
	if _is_refreshing:
		return
	_audio_muted = enabled
	_apply_audio_settings()
	_save_settings()

func _on_test_sfx_pressed() -> void:
	var audio_manager: MusicController = get_node_or_null("/root/AudioManager") as MusicController
	if audio_manager != null:
		audio_manager.play_ui_select()

func _on_quality_selected(index: int) -> void:
	if _is_refreshing:
		return
	_graphics_quality_index = int(clamp(index, 0, QUALITY_LABELS.size() - 1))
	_apply_graphics_quality()
	_save_settings()

func _on_display_mode_selected(index: int) -> void:
	if _is_refreshing:
		return
	_display_mode_index = int(clamp(index, 0, DISPLAY_MODE_LABELS.size() - 1))
	_apply_display_mode()
	_save_settings()

func _on_vsync_toggled(enabled: bool) -> void:
	if _is_refreshing:
		return
	_vsync_enabled = enabled
	_apply_vsync()
	_save_settings()

func _on_fps_cap_selected(index: int) -> void:
	if _is_refreshing:
		return
	_fps_cap_index = int(clamp(index, 0, FPS_CAP_VALUES.size() - 1))
	_apply_fps_cap()
	_save_settings()

func _on_rebind_pressed(action_name: String) -> void:
	_waiting_for_action = action_name
	_set_controls_status("Press a key for %s" % str(CONTROL_LABELS.get(action_name, action_name)))
	_refresh_control_buttons()

func _on_reset_controls_pressed() -> void:
	_apply_default_bindings()
	_apply_control_bindings()
	_save_settings()
	_refresh_control_buttons()
	_set_controls_status("Defaults restored")

func _on_reset_all_pressed() -> void:
	_master_volume = 1.0
	_music_volume = 0.9
	_sfx_volume = 0.95
	_audio_muted = false
	_graphics_quality_index = 2
	_display_mode_index = 0
	_vsync_enabled = true
	_fps_cap_index = 0
	_apply_default_bindings()
	_apply_all_settings()
	_save_settings()
	_refresh_controls()

func _on_streamer_controls_pressed() -> void:
	var streamer_menu: StreamerMenuController = _get_streamer_menu()
	if streamer_menu == null:
		return
	close_settings()
	streamer_menu.open_menu()

func _apply_all_settings() -> void:
	_apply_audio_settings()
	_apply_graphics_quality()
	_apply_display_mode()
	_apply_vsync()
	_apply_fps_cap()
	_apply_control_bindings()

func _apply_audio_settings() -> void:
	_ensure_audio_buses()
	_apply_bus_volume(BUS_MASTER, _master_volume, _audio_muted)
	_apply_bus_volume(BUS_MUSIC, _music_volume, _audio_muted)
	_apply_bus_volume(BUS_SFX, _sfx_volume, _audio_muted)

func _apply_bus_volume(bus_name: StringName, volume_linear: float, force_muted: bool) -> void:
	var bus_index: int = _get_or_create_bus_index(bus_name)
	if bus_index < 0:
		return

	var clamped_volume: float = clamp(volume_linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(max(clamped_volume, 0.001)))
	AudioServer.set_bus_mute(bus_index, force_muted or clamped_volume <= 0.001)

func _apply_graphics_quality() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return

	match _graphics_quality_index:
		0:
			viewport.scaling_3d_scale = 0.7
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			viewport.use_taa = false
		1:
			viewport.scaling_3d_scale = 0.85
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.use_taa = false
		2:
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.use_taa = true
		_:
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_8X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.use_taa = true

func _apply_display_mode() -> void:
	match _display_mode_index:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		2:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _vsync_enabled else DisplayServer.VSYNC_DISABLED)

func _apply_fps_cap() -> void:
	Engine.max_fps = FPS_CAP_VALUES[_fps_cap_index]

func _apply_control_bindings() -> void:
	for action_name in CONTROL_ACTIONS:
		var key_code: int = int(_bindings.get(action_name, _get_default_primary_key(action_name)))
		var key_codes: Array = [key_code]
		if key_code == _get_default_primary_key(action_name):
			key_codes = DEFAULT_ACTION_BINDINGS.get(action_name, key_codes)
		_apply_key_bindings(StringName(action_name), key_codes)

func _apply_key_bindings(action_name: StringName, key_codes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	InputMap.action_erase_events(action_name)
	for key_code in key_codes:
		var input_event: InputEventKey = InputEventKey.new()
		input_event.physical_keycode = int(key_code)
		InputMap.action_add_event(action_name, input_event)

func _apply_default_bindings() -> void:
	_bindings.clear()
	for action_name in CONTROL_ACTIONS:
		_bindings[action_name] = _get_default_primary_key(action_name)

func _set_primary_binding(action_name: String, key_code: int) -> void:
	_bindings[action_name] = key_code

func _ensure_audio_buses() -> void:
	_get_or_create_bus_index(BUS_MUSIC)
	_get_or_create_bus_index(BUS_SFX)

func _get_or_create_bus_index(bus_name: StringName) -> int:
	var existing_index: int = AudioServer.get_bus_index(bus_name)
	if existing_index >= 0:
		return existing_index
	if bus_name == BUS_MASTER:
		return 0

	AudioServer.add_bus()
	var bus_index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, BUS_MASTER)
	return bus_index

func _load_settings() -> void:
	_apply_default_bindings()
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(CONFIG_PATH)
	if error != OK:
		return

	_master_volume = clamp(float(config.get_value("audio", "master_volume", _master_volume)), 0.0, 1.0)
	_music_volume = clamp(float(config.get_value("audio", "music_volume", _music_volume)), 0.0, 1.0)
	_sfx_volume = clamp(float(config.get_value("audio", "sfx_volume", _sfx_volume)), 0.0, 1.0)
	_audio_muted = bool(config.get_value("audio", "muted", _audio_muted))
	_graphics_quality_index = int(clamp(int(config.get_value("graphics", "quality", _graphics_quality_index)), 0, QUALITY_LABELS.size() - 1))
	_display_mode_index = int(clamp(int(config.get_value("graphics", "display_mode", _display_mode_index)), 0, DISPLAY_MODE_LABELS.size() - 1))
	_vsync_enabled = bool(config.get_value("graphics", "vsync", _vsync_enabled))
	_fps_cap_index = int(clamp(int(config.get_value("graphics", "fps_cap", _fps_cap_index)), 0, FPS_CAP_VALUES.size() - 1))

	for action_name in CONTROL_ACTIONS:
		_bindings[action_name] = int(config.get_value("controls", action_name, _bindings[action_name]))

func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master_volume", _master_volume)
	config.set_value("audio", "music_volume", _music_volume)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.set_value("audio", "muted", _audio_muted)
	config.set_value("graphics", "quality", _graphics_quality_index)
	config.set_value("graphics", "display_mode", _display_mode_index)
	config.set_value("graphics", "vsync", _vsync_enabled)
	config.set_value("graphics", "fps_cap", _fps_cap_index)

	for action_name in CONTROL_ACTIONS:
		config.set_value("controls", action_name, int(_bindings.get(action_name, _get_default_primary_key(action_name))))

	var error: Error = config.save(CONFIG_PATH)
	if error != OK:
		push_warning("Unable to save game settings: %s" % error)

func _set_option_items(option_button: OptionButton, labels: Array[String]) -> void:
	option_button.clear()
	for label in labels:
		option_button.add_item(str(label))

func _set_controls_status(status_text: String) -> void:
	if _controls_status_label != null:
		_controls_status_label.text = status_text

func _format_binding(action_name: String) -> String:
	var key_code: int = int(_bindings.get(action_name, _get_default_primary_key(action_name)))
	var key_name: String = OS.get_keycode_string(key_code)
	if key_name.is_empty():
		return "Unassigned"
	return key_name

func _get_default_primary_key(action_name: String) -> int:
	var key_codes: Array = DEFAULT_ACTION_BINDINGS.get(action_name, [KEY_NONE])
	if key_codes.is_empty():
		return KEY_NONE
	return int(key_codes[0])

func _get_streamer_menu() -> StreamerMenuController:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("StreamerMenu") as StreamerMenuController
