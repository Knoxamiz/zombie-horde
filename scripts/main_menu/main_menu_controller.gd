class_name MainMenuController
extends Node3D

const AUDIO_MANAGER_SCENE: PackedScene = preload("res://scenes/audio/audio_manager.tscn")
const GAME_SETTINGS_SCENE: PackedScene = preload("res://scenes/settings/game_settings_menu.tscn")
const CHAT_ACTIVITY_FEED: Array[String] = [
	"TacoKing: !BRAINS\nPixelPunk: !CHAOS\nNotSleepy: !NUKE\nHexHunger: !SLOWMO\nDoomSprint: !BRAINS\n>>> TOO MANY BRAINS!",
	"RoadRage: !NUKE\nSnackStack: !BRAINS\nMoldMode: !CHAOS\nCrateLord: !BRAINS\nByteBiter: !SLOWMO\n>>> CHAOS RISING!",
	"ByteBiter: !brains\nGraveSnarl: !chaos\nNeonRot: !brains\nCrawlerQ: !slowmo\nHexHunger: !nuke\n>>> HORDE GROWS!",
]

@export_file("*.tscn") var game_scene_path: String = "res://scenes/main/main_game.tscn"
@export var camera_path: NodePath
@export var camera_focus: Vector3 = Vector3(0.0, 0.0, -20.0)
@export_range(0.0, 1.0, 0.01) var camera_idle_strength: float = 0.1

var _transitioning: bool = false
var _time: float = 0.0
var _camera_base_position: Vector3 = Vector3.ZERO
var _logo_base_position: Vector3 = Vector3.ZERO
var _chat_activity_index: int = 0
var _chat_activity_elapsed: float = 0.0
var _menu_3d_buttons: Array[MainMenu3DButton] = []

@onready var _camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var _logo_rig: Node3D = get_node_or_null("CinematicCamera/Menu3DOverlay/LogoRig") as Node3D
@onready var _chat_activity_panel: MainMenu3DInfoPanel = get_node_or_null(
	"CinematicCamera/Menu3DOverlay/ChatActivityPanel"
) as MainMenu3DInfoPanel

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var music_controller: MusicController = _get_or_create_music_controller()
	if music_controller != null:
		music_controller.play_menu_music()
	_connect_3d_buttons()
	if _camera != null:
		_camera_base_position = _camera.position
		var look_target: Vector3 = _camera.global_position + Vector3(0.0, -0.15, -18.0)
		_camera.look_at(look_target, Vector3.UP)
	if _logo_rig != null:
		_logo_base_position = _logo_rig.position
	_refresh_chat_activity()

func _process(delta: float) -> void:
	_time += delta
	_update_camera_idle()
	_update_logo_rig()
	_update_chat_activity(delta)

func _on_menu_3d_button_pressed(action_id: StringName) -> void:
	match action_id:
		&"start":
			_launch_lobby(0, false)
		&"streamer":
			_launch_lobby(0, true)
		&"leaderboard":
			_launch_lobby(0, false)
		&"settings":
			_on_settings_pressed()

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
	for button in _menu_3d_buttons:
		if button != null and is_instance_valid(button):
			button.set_interactable(enabled)

func _connect_3d_buttons() -> void:
	_menu_3d_buttons.clear()
	var button_rack: Node = get_node_or_null("CinematicCamera/Menu3DOverlay/ButtonRack")
	if button_rack == null:
		return

	for child in button_rack.get_children():
		var button: MainMenu3DButton = child as MainMenu3DButton
		if button == null:
			continue
		_menu_3d_buttons.append(button)
		if not button.pressed.is_connected(_on_menu_3d_button_pressed):
			button.pressed.connect(_on_menu_3d_button_pressed)

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

func _update_camera_idle() -> void:
	if _camera == null or camera_idle_strength <= 0.0:
		return

	var offset: Vector3 = Vector3(
		sin(_time * 0.37) * 0.18,
		sin(_time * 0.29 + 1.4) * 0.08,
		sin(_time * 0.23 + 0.8) * 0.1
	) * camera_idle_strength
	_camera.position = _camera_base_position + offset

func _update_logo_rig() -> void:
	if _logo_rig == null:
		return

	_logo_rig.position = _logo_base_position + Vector3(
		sin(_time * 0.82) * 0.02,
		sin(_time * 0.68 + 0.9) * 0.025,
		0.0
	)
	_logo_rig.rotation.z = sin(_time * 0.55) * 0.008

func _update_chat_activity(delta: float) -> void:
	if _chat_activity_panel == null:
		return

	_chat_activity_elapsed += delta
	if _chat_activity_elapsed < 2.4:
		return

	_chat_activity_elapsed = 0.0
	_chat_activity_index = (_chat_activity_index + 1) % CHAT_ACTIVITY_FEED.size()
	_refresh_chat_activity()

func _refresh_chat_activity() -> void:
	if _chat_activity_panel != null:
		_chat_activity_panel.set_panel_text("CHAT ACTIVITY", CHAT_ACTIVITY_FEED[_chat_activity_index])
