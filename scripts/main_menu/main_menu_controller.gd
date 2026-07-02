class_name MainMenuController
extends Node3D

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

@onready var _camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var _open_lobby_button: Button = get_node("MenuLayer/Root/Nav/OpenLobbyButton") as Button
@onready var _add_join_button: Button = get_node("MenuLayer/Root/Nav/AddJoinButton") as Button
@onready var _settings_button: Button = get_node("MenuLayer/Root/Nav/SettingsButton") as Button
@onready var _exit_button: Button = get_node("MenuLayer/Root/Nav/ExitButton") as Button

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var music_controller: MusicController = _get_music_controller()
	if music_controller != null:
		music_controller.play_menu_music()
	_cache_cinematic_nodes()
	if _camera != null:
		_camera.look_at(camera_focus, Vector3.UP)

	_open_lobby_button.pressed.connect(_on_open_lobby_pressed)
	_add_join_button.pressed.connect(_on_add_join_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_refresh_feature_buttons()

func _process(delta: float) -> void:
	_time += delta
	_update_camera_idle()
	_update_menu_zombies()
	_update_menu_lights()

func _on_open_lobby_pressed() -> void:
	_launch_lobby(0, false)

func _on_add_join_pressed() -> void:
	_launch_lobby(debug_joins_per_click, false)

func _on_settings_pressed() -> void:
	var game_settings: GameSettingsController = _get_game_settings()
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
	_open_lobby_button.disabled = not enabled
	_add_join_button.disabled = not enabled
	_settings_button.disabled = not enabled
	_exit_button.disabled = not enabled

func _refresh_feature_buttons() -> void:
	if _settings_button != null:
		_settings_button.visible = true
		_settings_button.disabled = false

func _get_music_controller() -> MusicController:
	return get_node_or_null("/root/AudioManager") as MusicController

func _get_game_settings() -> GameSettingsController:
	return get_node_or_null("/root/GameSettings") as GameSettingsController

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
