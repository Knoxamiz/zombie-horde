class_name MainMenuController
extends Node3D

const AUDIO_MANAGER_SCENE: PackedScene = preload("res://scenes/audio/audio_manager.tscn")
const GAME_SETTINGS_SCENE: PackedScene = preload("res://scenes/settings/game_settings_menu.tscn")
const CHAT_ACTIVITY_FEED: Array[String] = [
	"ByteBiter: !brains\nGraveSnarl: !chaos\nNeonRot: !brains\nCrawlerQ: !slowmo",
	"RoadRage: !nuke\nSnackStack: !brains\nMoldMode: !chaos\nCrateLord: !brains",
	"TacoKing: !brains\nPixelPunk: !chaos\nNotSleepy: !nuke\nHexHunger: !slowmo",
]

@export_file("*.tscn") var game_scene_path: String = "res://scenes/main/main_game.tscn"
@export var camera_path: NodePath
@export var camera_focus: Vector3 = Vector3(1.8, 1.45, -6.5)
@export var menu_zombies_path: NodePath
@export var cage_light_path: NodePath
@export var base_light_path: NodePath
@export var road_sweep_light_path: NodePath
@export_range(0.0, 1.0, 0.01) var camera_idle_strength: float = 0.22

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

@onready var _camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var _chat_activity_panel: MainMenu3DInfoPanel = get_node_or_null(
	"CinematicCamera/Menu3DOverlay/ChatActivityPanel"
) as MainMenu3DInfoPanel

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var music_controller: MusicController = _get_or_create_music_controller()
	if music_controller != null:
		music_controller.play_menu_music()
	_connect_3d_buttons()
	_cache_cinematic_nodes()
	if _camera != null:
		_camera.look_at(camera_focus, Vector3.UP)
	_refresh_chat_activity()

func _process(delta: float) -> void:
	_time += delta
	_update_camera_idle()
	_update_menu_zombies()
	_update_menu_lights()
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

func _update_camera_idle() -> void:
	if _camera == null or camera_idle_strength <= 0.0:
		return

	var offset: Vector3 = Vector3(
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

func _update_chat_activity(delta: float) -> void:
	if _chat_activity_panel == null:
		return

	_chat_activity_elapsed += delta
	if _chat_activity_elapsed < 1.9:
		return

	_chat_activity_elapsed = 0.0
	_chat_activity_index = (_chat_activity_index + 1) % CHAT_ACTIVITY_FEED.size()
	_refresh_chat_activity()

func _refresh_chat_activity() -> void:
	if _chat_activity_panel != null:
		_chat_activity_panel.set_panel_text("CHAT ACTIVITY", CHAT_ACTIVITY_FEED[_chat_activity_index])
