class_name MainMenuController
extends Node3D

const AUDIO_MANAGER_SCENE: PackedScene = preload("res://scenes/audio/audio_manager.tscn")
const GAME_SETTINGS_SCENE: PackedScene = preload("res://scenes/settings/game_settings_menu.tscn")
const BLOCK_TEXT_SCENE: Script = preload("res://scripts/ui/main_menu_3d_block_text.gd")
const INFO_PANEL_SCENE: Script = preload("res://scripts/ui/main_menu_3d_info_panel.gd")
const FEATURE_CONFIG: FeatureAccessConfig = preload("res://resources/config/feature_access_config.tres")
const CHAT_CONTROLS_TEXT := "!BRAINS - Join the horde\n!NUKE - Drop a mine strike\n!SLOWMO - Slow the race\n!CHAOS - Random chaos event"
const CHAT_ACTIVITY_FEED: Array[String] = [
	"ByteBiter: !brains\nGraveSnarl: !chaos\nNeonRot: !brains\nCrawlerQ: !slowmo",
	"RoadRage: !nuke\nSnackStack: !brains\nMoldMode: !chaos\nCrateLord: !brains",
	"TacoKing: !brains\nPixelPunk: !chaos\nNotSleepy: !nuke\nHexHunger: !slowmo",
]

@export_file("*.tscn") var game_scene_path: String = "res://scenes/main/main_game.tscn"
@export var camera_path: NodePath
@export var camera_focus: Vector3 = Vector3(2.2, 1.85, -9.5)
@export var menu_zombies_path: NodePath
@export var cage_light_path: NodePath
@export var base_light_path: NodePath
@export var road_sweep_light_path: NodePath
@export_range(1, 24, 1) var debug_joins_per_click: int = 1
@export_range(0.0, 1.0, 0.01) var camera_idle_strength: float = 0.28

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
var _chat_activity_panel: MainMenu3DInfoPanel

@onready var _camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var _chat_activity_label_3d: Label3D = get_node_or_null("CinematicCamera/Menu3DOverlay/ChatRoadSign/ChatFeedLabel3D") as Label3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var music_controller: MusicController = _get_or_create_music_controller()
	if music_controller != null:
		music_controller.play_menu_music()
	_activate_cinematic_menu()
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
		&"exit":
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
	for button in _menu_3d_buttons:
		if button != null and is_instance_valid(button):
			button.set_interactable(enabled)

func _activate_cinematic_menu() -> void:
	var legacy_layer: CanvasItem = get_node_or_null("MenuLayer") as CanvasItem
	if legacy_layer != null:
		legacy_layer.visible = false

	var cinematic_world: Node3D = get_node_or_null("CinematicWorld") as Node3D
	if cinematic_world != null:
		cinematic_world.visible = true

	var overlay: Node3D = get_node_or_null("CinematicCamera/Menu3DOverlay") as Node3D
	if overlay == null:
		return
	overlay.visible = true

	var flat_art: Node3D = overlay.get_node_or_null("MenuArt3D") as Node3D
	if flat_art != null:
		flat_art.visible = false

	var legacy_logo: Node3D = overlay.get_node_or_null("LogoRig") as Node3D
	if legacy_logo != null:
		legacy_logo.visible = false

	var legacy_chat_sign: Node3D = overlay.get_node_or_null("ChatRoadSign") as Node3D
	if legacy_chat_sign != null:
		legacy_chat_sign.visible = false

	_build_title(overlay)
	_build_info_panels(overlay)
	_connect_3d_buttons()

func _build_title(overlay: Node3D) -> void:
	if overlay.get_node_or_null("TitleBlocks") != null:
		return

	var title: MainMenu3DBlockText = BLOCK_TEXT_SCENE.new() as MainMenu3DBlockText
	title.name = "TitleBlocks"
	title.position = Vector3(0.35, 2.05, -6.35)
	title.block_size = Vector3(0.31, 0.31, 0.48)
	title.line_spacing = 0.34
	overlay.add_child(title)

func _build_info_panels(overlay: Node3D) -> void:
	if overlay.get_node_or_null("ChatControlsPanel") == null:
		var controls: MainMenu3DInfoPanel = INFO_PANEL_SCENE.new() as MainMenu3DInfoPanel
		controls.name = "ChatControlsPanel"
		controls.position = Vector3(-4.55, 1.72, -5.95)
		controls.rotation_degrees = Vector3(0.0, 8.0, 0.0)
		controls.panel_size = Vector2(3.15, 1.95)
		controls.header_text = "CHAT CONTROLS"
		controls.body_text = CHAT_CONTROLS_TEXT
		controls.header_color = Color(0.72, 0.42, 1.0, 1.0)
		controls.body_color = Color(0.88, 0.92, 1.0, 1.0)
		controls.frame_color = Color(0.52, 0.18, 0.82, 1.0)
		controls.body_font_size = 20
		overlay.add_child(controls)

	if overlay.get_node_or_null("ChatActivityPanel") == null:
		_chat_activity_panel = INFO_PANEL_SCENE.new() as MainMenu3DInfoPanel
		_chat_activity_panel.name = "ChatActivityPanel"
		_chat_activity_panel.position = Vector3(4.35, 1.72, -5.95)
		_chat_activity_panel.rotation_degrees = Vector3(0.0, -8.0, 0.0)
		_chat_activity_panel.panel_size = Vector2(3.05, 1.75)
		_chat_activity_panel.header_text = "CHAT ACTIVITY"
		_chat_activity_panel.body_text = CHAT_ACTIVITY_FEED[0]
		_chat_activity_panel.header_color = Color(1.0, 0.31, 0.22, 1.0)
		_chat_activity_panel.body_color = Color(0.82, 1.0, 0.3, 1.0)
		_chat_activity_panel.mount_pole = true
		_chat_activity_panel.mount_siren = true
		overlay.add_child(_chat_activity_panel)

func _connect_3d_buttons() -> void:
	_menu_3d_buttons.clear()
	var button_rack: Node = get_node_or_null("CinematicCamera/Menu3DOverlay/ButtonRack")
	if button_rack == null:
		return

	for child in button_rack.get_children():
		var button: MainMenu3DButton = child as MainMenu3DButton
		if button == null:
			continue
		if button.action_id == &"exit":
			button.visible = false
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

func _update_chat_activity(delta: float) -> void:
	if _chat_activity_panel == null and _chat_activity_label_3d == null:
		return

	_chat_activity_elapsed += delta
	if _chat_activity_elapsed < 1.9:
		return

	_chat_activity_elapsed = 0.0
	_chat_activity_index = (_chat_activity_index + 1) % CHAT_ACTIVITY_FEED.size()
	_refresh_chat_activity()

func _refresh_chat_activity() -> void:
	var feed_text: String = CHAT_ACTIVITY_FEED[_chat_activity_index]
	if _chat_activity_label_3d != null:
		_chat_activity_label_3d.text = feed_text
	if _chat_activity_panel != null:
		_chat_activity_panel.set_panel_text("CHAT ACTIVITY", feed_text)
