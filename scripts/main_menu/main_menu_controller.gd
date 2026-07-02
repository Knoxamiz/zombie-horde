class_name MainMenuController
extends Node3D

const AUDIO_MANAGER_SCENE: PackedScene = preload("res://scenes/audio/audio_manager.tscn")
const GAME_SETTINGS_SCENE: PackedScene = preload("res://scenes/settings/game_settings_menu.tscn")
const CHAT_ACTIVITY_FEED: Array[String] = [
	"TacoKing: !BRAINS\nPixelPunk: !CHAOS\nNotSleepy: !NUKE\nHexHunger: !SLOWMO\n>>> TOO MANY BRAINS!",
	"ByteBiter: !BRAINS\nGraveShift: !CHAOS\nNeonRot: !BRAINS\nVanDad: !SLOWMO\n>>> HORDE GROWING",
	"RoadRage: !NUKE\nSnackStack: !BRAINS\nMoldMode: !CHAOS\nCrateLord: !BRAINS\n>>> CHAT IS LOUD",
]

@export_file("*.tscn") var game_scene_path: String = "res://scenes/main/main_game.tscn"
@export var camera_path: NodePath
@export var camera_focus: Vector3 = Vector3(0.0, 1.8, 4.0)
@export var menu_zombies_path: NodePath
@export var cage_light_path: NodePath
@export var base_light_path: NodePath
@export var road_sweep_light_path: NodePath
@export_range(1, 24, 1) var debug_joins_per_click: int = 1
@export_range(0.0, 1.0, 0.01) var camera_idle_strength: float = 0.32

var _transitioning: bool = false
var _time: float = 0.0
var _camera_base_position: Vector3 = Vector3.ZERO
var _menu_zombies: Array[Node3D] = []
var _menu_zombie_base_transforms: Array[Transform3D] = []
var _cage_light: Light3D
var _base_light: Light3D
var _road_sweep_light: Light3D
var _cage_light_energy: float = 0.0
var _base_light_energy: float = 0.0
var _road_sweep_light_energy: float = 0.0
var _chat_activity_index: int = 0
var _chat_activity_elapsed: float = 0.0
var _menu_3d_buttons: Array[MainMenu3DButton] = []
var _logo_rig_base_position: Vector3 = Vector3.ZERO

@onready var _camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var _open_lobby_button: Button = get_node_or_null("MenuLayer/Root/Nav/OpenLobbyButton") as Button
@onready var _add_join_button: Button = get_node_or_null("MenuLayer/Root/Nav/AddJoinButton") as Button
@onready var _leaderboard_button: Button = get_node_or_null("MenuLayer/Root/Nav/LeaderboardButton") as Button
@onready var _settings_button: Button = get_node_or_null("MenuLayer/Root/Nav/SettingsButton") as Button
@onready var _exit_button: Button = get_node_or_null("MenuLayer/Root/Nav/ExitButton") as Button
@onready var _chat_activity_label: Label = get_node_or_null("MenuLayer/Root/ChatActivityPanel/Margin/VBox/ActivityLines") as Label
@onready var _chat_activity_label_3d: Label3D = get_node_or_null("CinematicCamera/Menu3DOverlay/ChatRoadSign/ChatFeedLabel3D") as Label3D
@onready var _logo_rig: Node3D = get_node_or_null("CinematicCamera/Menu3DOverlay/LogoRig") as Node3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var music_controller: MusicController = _get_or_create_music_controller()
	if music_controller != null:
		music_controller.play_menu_music()
	_cache_cinematic_nodes()
	if _camera != null:
		_camera.look_at(camera_focus, Vector3.UP)

	_connect_canvas_buttons()
	_connect_3d_buttons()
	_refresh_chat_activity()
	_refresh_feature_buttons()

func _process(delta: float) -> void:
	_time += delta
	_update_camera_idle()
	_update_menu_zombies()
	_update_menu_lights()
	_update_logo_rig()
	_update_chat_activity(delta)

func _on_open_lobby_pressed() -> void:
	_launch_lobby(0, false)

func _on_add_join_pressed() -> void:
	_launch_lobby(0, true)

func _on_leaderboard_pressed() -> void:
	_launch_lobby(0, false)

func _on_menu_3d_button_pressed(action_id: StringName) -> void:
	match action_id:
		&"start":
			_on_open_lobby_pressed()
		&"streamer":
			_on_add_join_pressed()
		&"leaderboard":
			_on_leaderboard_pressed()
		&"settings":
			_on_settings_pressed()
		&"exit":
			_on_exit_pressed()

func _on_settings_pressed() -> void:
	var game_settings: GameSettingsController = _get_or_create_game_settings()
	if game_settings != null:
		game_settings.open_settings()

func _on_exit_pressed() -> void:
	get_tree().quit()

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
	if _open_lobby_button != null:
		_open_lobby_button.disabled = not enabled
	if _add_join_button != null:
		_add_join_button.disabled = not enabled
	if _leaderboard_button != null:
		_leaderboard_button.disabled = not enabled
	if _settings_button != null:
		_settings_button.disabled = not enabled
	if _exit_button != null:
		_exit_button.disabled = not enabled
	for button in _menu_3d_buttons:
		if button != null and is_instance_valid(button):
			button.set_interactable(enabled)

func _refresh_feature_buttons() -> void:
	if _settings_button != null:
		_settings_button.visible = true
		_settings_button.disabled = false

func _connect_canvas_buttons() -> void:
	if _open_lobby_button != null:
		_open_lobby_button.pressed.connect(_on_open_lobby_pressed)
	if _add_join_button != null:
		_add_join_button.pressed.connect(_on_add_join_pressed)
	if _leaderboard_button != null:
		_leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	if _settings_button != null:
		_settings_button.pressed.connect(_on_settings_pressed)
	if _exit_button != null:
		_exit_button.pressed.connect(_on_exit_pressed)

func _connect_3d_buttons() -> void:
	var button_rack: Node = get_node_or_null("CinematicCamera/Menu3DOverlay/ButtonRack")
	if button_rack == null:
		return

	for child in button_rack.get_children():
		var button: MainMenu3DButton = child as MainMenu3DButton
		if button == null:
			continue
		_menu_3d_buttons.append(button)
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

func _cache_cinematic_nodes() -> void:
	if _camera != null:
		_camera_base_position = _camera.global_position

	var zombie_group: Node3D = get_node_or_null(menu_zombies_path) as Node3D
	if zombie_group != null:
		for child in zombie_group.get_children():
			var zombie: Node3D = child as Node3D
			if zombie == null:
				continue
			_menu_zombies.append(zombie)
			_menu_zombie_base_transforms.append(zombie.transform)

	_cage_light = get_node_or_null(cage_light_path) as Light3D
	_base_light = get_node_or_null(base_light_path) as Light3D
	_road_sweep_light = get_node_or_null(road_sweep_light_path) as Light3D
	if _cage_light != null:
		_cage_light_energy = _cage_light.light_energy
	if _base_light != null:
		_base_light_energy = _base_light.light_energy
	if _road_sweep_light != null:
		_road_sweep_light_energy = _road_sweep_light.light_energy
	if _logo_rig != null:
		_logo_rig_base_position = _logo_rig.position

func _update_camera_idle() -> void:
	if _camera == null or camera_idle_strength <= 0.0:
		return

	var offset := Vector3(
		sin(_time * 0.37) * 0.42,
		sin(_time * 0.29 + 1.4) * 0.18,
		sin(_time * 0.23 + 0.8) * 0.26
	) * camera_idle_strength
	_camera.global_position = _camera_base_position + offset
	var look_target: Vector3 = camera_focus + Vector3(0.0, sin(_time * 0.31) * 0.08, 0.0)
	_camera.look_at(look_target, Vector3.UP)

func _update_menu_zombies() -> void:
	for index in range(_menu_zombies.size()):
		var zombie: Node3D = _menu_zombies[index]
		if zombie == null or not is_instance_valid(zombie):
			continue

		var base_transform: Transform3D = _menu_zombie_base_transforms[index]
		zombie.transform = base_transform
		zombie.position.y = base_transform.origin.y + sin(_time * 1.25 + float(index) * 0.9) * 0.045
		zombie.rotate_y(sin(_time * 0.58 + float(index) * 1.7) * 0.08)

func _update_menu_lights() -> void:
	if _cage_light != null:
		_cage_light.light_energy = _cage_light_energy * (1.0 + sin(_time * 1.7) * 0.08)
	if _base_light != null:
		_base_light.light_energy = _base_light_energy * (1.0 + sin(_time * 1.15 + 1.3) * 0.06)
	if _road_sweep_light != null:
		_road_sweep_light.light_energy = _road_sweep_light_energy * (1.0 + sin(_time * 0.9 + 0.6) * 0.09)

func _update_logo_rig() -> void:
	if _logo_rig == null:
		return

	_logo_rig.position = _logo_rig_base_position + Vector3(
		sin(_time * 0.82) * 0.035,
		sin(_time * 0.68 + 0.9) * 0.045,
		0.0
	)
	_logo_rig.rotation.z = sin(_time * 0.55) * 0.012

func _update_chat_activity(delta: float) -> void:
	if _chat_activity_label == null and _chat_activity_label_3d == null:
		return

	_chat_activity_elapsed += delta
	if _chat_activity_elapsed < 1.9:
		return

	_chat_activity_elapsed = 0.0
	_chat_activity_index = (_chat_activity_index + 1) % CHAT_ACTIVITY_FEED.size()
	_refresh_chat_activity()

func _refresh_chat_activity() -> void:
	var feed_text: String = CHAT_ACTIVITY_FEED[_chat_activity_index]
	if _chat_activity_label != null:
		_chat_activity_label.text = feed_text
	if _chat_activity_label_3d != null:
		_chat_activity_label_3d.text = feed_text
