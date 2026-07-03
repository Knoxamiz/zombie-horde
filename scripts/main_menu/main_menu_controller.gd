class_name MainMenuController
extends Node3D

const AUDIO_MANAGER_SCENE: PackedScene = preload("res://scenes/audio/audio_manager.tscn")
const GAME_SETTINGS_SCENE: PackedScene = preload("res://scenes/settings/game_settings_menu.tscn")

@export_file("*.tscn") var game_scene_path: String = "res://scenes/main/main_game.tscn"
@export var camera_path: NodePath
@export_range(0.0, 1.0, 0.01) var camera_idle_strength: float = 0.06
@export_range(0.0, 1.0, 0.01) var logo_wobble_strength: float = 1.0

var _transitioning: bool = false
var _time: float = 0.0
var _camera_base_position: Vector3 = Vector3.ZERO
var _logo_base_position: Vector3 = Vector3.ZERO
var _logo_base_scale: Vector3 = Vector3.ONE
var _menu_buttons: Array[MainMenuBlockButton] = []

@onready var _camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var _logo_rig: Node3D = get_node_or_null("CinematicCamera/Menu3DOverlay/LogoRig") as Node3D
@onready var _background: TextureRect = get_node_or_null("BackgroundLayer/Background") as TextureRect

func _ready() -> void:
	get_viewport().transparent_bg = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fit_background()

	var music_controller: MusicController = _get_or_create_music_controller()
	if music_controller != null:
		music_controller.play_menu_music()

	_connect_buttons()

	if _camera != null:
		_camera_base_position = _camera.position
		var look_target: Vector3 = _camera.global_position + Vector3(0.0, -0.12, -18.0)
		_camera.look_at(look_target, Vector3.UP)

	if _logo_rig != null:
		_logo_base_position = _logo_rig.position
		_logo_base_scale = _logo_rig.scale

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_fit_background()

func _process(delta: float) -> void:
	_time += delta
	_update_camera_idle()
	_update_logo_rig()

func _on_menu_button_pressed(action_id: StringName) -> void:
	match action_id:
		&"start":
			_launch_lobby(0, false)
		&"streamer":
			_launch_lobby(0, true)
		&"settings":
			_on_settings_pressed()
		&"quit":
			get_tree().quit()

func _on_settings_pressed() -> void:
	var game_settings: GameSettingsController = _get_or_create_game_settings()
	if game_settings != null:
		game_settings.open_settings()

func _launch_lobby(debug_joins_to_seed: int, open_settings: bool) -> void:
	if _transitioning:
		return

	_transitioning = true
	_set_buttons_enabled(false)
	LaunchState.request_lobby(debug_joins_to_seed, open_settings)
	var error: Error = get_tree().change_scene_to_file(game_scene_path)
	if error != OK:
		_transitioning = false
		_set_buttons_enabled(true)
		push_error("Unable to load game scene: %s" % game_scene_path)

func _set_buttons_enabled(enabled: bool) -> void:
	for button in _menu_buttons:
		if button != null and is_instance_valid(button):
			button.set_interactable(enabled)

func _connect_buttons() -> void:
	_menu_buttons.clear()
	var paths: Array[NodePath] = [
		NodePath("CinematicCamera/Menu3DOverlay/ButtonCenterRack"),
		NodePath("CinematicCamera/Menu3DOverlay/SettingsButton3D"),
	]
	for path in paths:
		var node: Node = get_node_or_null(path)
		if node == null:
			continue
		if node is MainMenuBlockButton:
			_register_button(node as MainMenuBlockButton)
			continue
		for child in node.get_children():
			var button: MainMenuBlockButton = child as MainMenuBlockButton
			if button != null:
				_register_button(button)

func _register_button(button: MainMenuBlockButton) -> void:
	_menu_buttons.append(button)
	if not button.pressed.is_connected(_on_menu_button_pressed):
		button.pressed.connect(_on_menu_button_pressed)

func _fit_background() -> void:
	if _background == null:
		return
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.offset_left = 0.0
	_background.offset_top = 0.0
	_background.offset_right = 0.0
	_background.offset_bottom = 0.0

func _update_camera_idle() -> void:
	if _camera == null or camera_idle_strength <= 0.0:
		return

	var offset: Vector3 = Vector3(
		sin(_time * 0.37) * 0.1,
		sin(_time * 0.29 + 1.4) * 0.05,
		sin(_time * 0.23 + 0.8) * 0.06
	) * camera_idle_strength
	_camera.position = _camera_base_position + offset

func _update_logo_rig() -> void:
	if _logo_rig == null or logo_wobble_strength <= 0.0:
		return

	var wobble: float = logo_wobble_strength
	_logo_rig.position = _logo_base_position + Vector3(
		sin(_time * 0.82) * 0.035 * wobble,
		sin(_time * 0.68 + 0.9) * 0.04 * wobble,
		sin(_time * 0.51 + 0.4) * 0.012 * wobble
	)
	_logo_rig.rotation.z = sin(_time * 0.55) * 0.012 * wobble
	_logo_rig.rotation.x = sin(_time * 0.43 + 1.1) * 0.008 * wobble
	var pulse: float = 1.0 + sin(_time * 1.05) * 0.018 * wobble
	_logo_rig.scale = _logo_base_scale * pulse

func _get_or_create_music_controller() -> MusicController:
	var music_controller: MusicController = get_node_or_null("/root/AudioManager") as MusicController
	if music_controller != null:
		return music_controller

	music_controller = AUDIO_MANAGER_SCENE.instantiate() as MusicController
	if music_controller == null:
		return null

	music_controller.name = "AudioManager"
	get_tree().root.add_child(music_controller)
	return music_controller

func _get_or_create_game_settings() -> GameSettingsController:
	var game_settings: GameSettingsController = get_node_or_null("/root/GameSettings") as GameSettingsController
	if game_settings != null:
		return game_settings

	game_settings = GAME_SETTINGS_SCENE.instantiate() as GameSettingsController
	if game_settings == null:
		return null

	game_settings.name = "GameSettings"
	get_tree().root.add_child(game_settings)
	return game_settings
