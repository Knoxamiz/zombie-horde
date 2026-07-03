class_name MainMenuController
extends Control

const AUDIO_MANAGER_SCENE: PackedScene = preload("res://scenes/audio/audio_manager.tscn")
const GAME_SETTINGS_SCENE: PackedScene = preload("res://scenes/settings/game_settings_menu.tscn")
const MENU_ART: Texture2D = preload("res://assets/ui/main_menu/zombie_chat_horde_menu_art.png")
const JOIN_FEED_LINES: Array[String] = [
	"TacoKing joined the horde!\nPixelPunk: !BRAINS\nNotSleepy: !CHAOS\nHexHunger: !NUKE\nDoomSprint: !SLOWMO\nGraveSnarl: !BRAINS\nMossFang: !CHAOS\nRustJaw: !BRAINS\nViperGut: !NUKE\nHollowKid: !SLOWMO\n>>> HORDE GROWING!",
	"ByteBiter joined the horde!\nRoadRage: !NUKE\nSnackStack: !BRAINS\nMoldMode: !CHAOS\nCrateLord: !BRAINS\nNeonRot: !SLOWMO\nAshCrawl: !BRAINS\nDripFang: !CHAOS\nBoltHusk: !NUKE\nGnashPit: !BRAINS\n>>> CHAOS RISING!",
	"CrawlerQ joined the horde!\nEchoRot: !BRAINS\nAdaBites: !CHAOS\nCaptainDecay: !BRAINS\nGlitchGnaw: !SLOWMO\nPixelMunch: !NUKE\nSludgeRun: !BRAINS\nFrostMaw: !CHAOS\nZeroPulse: !BRAINS\nVoidSnarl: !SLOWMO\n>>> TOO MANY BRAINS!",
]

@export_file("*.tscn") var game_scene_path: String = "res://scenes/main/main_game.tscn"
@export var camera_path: NodePath = NodePath("MenuViewportContainer/MenuViewport/MenuWorld/CinematicCamera")
@export_range(0.0, 1.0, 0.01) var camera_idle_strength: float = 0.06
@export_range(0.0, 1.0, 0.01) var logo_wobble_strength: float = 1.0
@export var button_stack_start_y: float = -0.72
@export var button_stack_gap: float = 0.1
@export var button_depth_z: float = -6.85
@export var corner_x: float = 3.55

var _transitioning: bool = false
var _time: float = 0.0
var _camera_base_position: Vector3 = Vector3.ZERO
var _logo_base_position: Vector3 = Vector3.ZERO
var _logo_base_scale: Vector3 = Vector3.ONE
var _menu_buttons: Array[MainMenuBlockButton] = []
var _viewport_container: SubViewportContainer
var _pressed_button: MainMenuBlockButton
var _feed_index: int = 0
var _feed_elapsed: float = 0.0
var _prompt_time: float = 0.0

@onready var _background: TextureRect = $Background
@onready var _viewport: SubViewport = $MenuViewportContainer/MenuViewport
@onready var _camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var _logo_rig: Node3D = get_node_or_null(
	"MenuViewportContainer/MenuViewport/MenuWorld/CinematicCamera/Menu3DOverlay/LogoRig"
) as Node3D
@onready var _button_rack: Node3D = get_node_or_null(
	"MenuViewportContainer/MenuViewport/MenuWorld/CinematicCamera/Menu3DOverlay/ButtonCenterRack"
) as Node3D
@onready var _settings_button: MainMenuBlockButton = get_node_or_null(
	"MenuViewportContainer/MenuViewport/MenuWorld/CinematicCamera/Menu3DOverlay/SettingsButton3D"
) as MainMenuBlockButton
@onready var _version_label: Label3D = get_node_or_null(
	"MenuViewportContainer/MenuViewport/MenuWorld/CinematicCamera/Menu3DOverlay/VersionLabel3D"
) as Label3D
@onready var _feed_body: Label = get_node_or_null("OverlayLayer/JoinFeedPanel/Margin/VBox/FeedBody") as Label
@onready var _join_prompt: Label = get_node_or_null("OverlayLayer/JoinPromptPanel/JoinPromptLabel") as Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit_layout)
	_viewport_container = get_node_or_null("MenuViewportContainer") as SubViewportContainer
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fit_layout()
	ResourceLoader.load_threaded_request(game_scene_path)

	var music_controller: MusicController = _get_or_create_music_controller()
	if music_controller != null:
		music_controller.play_menu_music()

	_connect_buttons()
	call_deferred("_layout_menu_buttons")

	if _camera != null:
		_camera_base_position = _camera.position
		var look_target: Vector3 = _camera.global_position + Vector3(0.0, -0.12, -18.0)
		_camera.look_at(look_target, Vector3.UP)

	if _logo_rig != null:
		_logo_base_position = _logo_rig.position
		_logo_base_scale = _logo_rig.scale

	_refresh_join_feed()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_fit_layout()

func _process(delta: float) -> void:
	_time += delta
	_update_camera_idle()
	_update_logo_rig()
	_update_join_feed(delta)
	_update_join_prompt(delta)

func _update_join_feed(delta: float) -> void:
	if _feed_body == null:
		return
	_feed_elapsed += delta
	if _feed_elapsed < 2.6:
		return
	_feed_elapsed = 0.0
	_feed_index = (_feed_index + 1) % JOIN_FEED_LINES.size()
	_refresh_join_feed()

func _refresh_join_feed() -> void:
	if _feed_body != null:
		_feed_body.text = JOIN_FEED_LINES[_feed_index]

func _update_join_prompt(delta: float) -> void:
	if _join_prompt == null:
		return
	_prompt_time += delta
	var pulse: float = 0.75 + 0.25 * sin(_prompt_time * 3.0)
	_join_prompt.modulate = Color(1.0, 1.0, 1.0, pulse)

func _unhandled_input(event: InputEvent) -> void:
	if _transitioning or _viewport_container == null or _camera == null:
		return

	if event is InputEventMouseMotion:
		_update_hover_from_mouse()
		return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return

	var local_pos: Vector2 = _viewport_container.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, _viewport_container.size).has_point(local_pos):
		return

	if mouse_button.pressed:
		var hit_button: MainMenuBlockButton = _pick_button_at(local_pos)
		if hit_button != null:
			_pressed_button = hit_button
			hit_button.set_pressed_state(true)
			get_viewport().set_input_as_handled()
		return

	if _pressed_button != null:
		var release_button: MainMenuBlockButton = _pick_button_at(local_pos)
		if release_button == _pressed_button:
			_pressed_button.trigger_pressed()
		_pressed_button.set_pressed_state(false)
		_pressed_button = null
		get_viewport().set_input_as_handled()

func _update_hover_from_mouse() -> void:
	if _viewport_container == null:
		return
	var local_pos: Vector2 = _viewport_container.get_local_mouse_position()
	var hovered_button: MainMenuBlockButton = _pick_button_at(local_pos)
	for button in _menu_buttons:
		if button != null:
			button.set_hovered_state(button == hovered_button)

func _pick_button_at(local_pos: Vector2) -> MainMenuBlockButton:
	var viewport_size: Vector2 = Vector2(_viewport.size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return null

	var viewport_pos: Vector2 = Vector2(
		local_pos.x * viewport_size.x / _viewport_container.size.x,
		local_pos.y * viewport_size.y / _viewport_container.size.y
	)
	var ray_origin: Vector3 = _camera.project_ray_origin(viewport_pos)
	var ray_direction: Vector3 = _camera.project_ray_normal(viewport_pos)

	var closest_button: MainMenuBlockButton = null
	var closest_distance: float = INF
	for button in _menu_buttons:
		if button == null or not button.interactable:
			continue
		var hit_distance: Variant = button.intersect_ray(ray_origin, ray_direction)
		if hit_distance == null:
			continue
		var distance: float = float(hit_distance)
		if distance < closest_distance:
			closest_distance = distance
			closest_button = button

	return closest_button

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

	var packed: PackedScene = _take_preloaded_game_scene()
	var error: Error
	if packed != null:
		error = get_tree().change_scene_to_packed(packed)
	else:
		error = get_tree().change_scene_to_file(game_scene_path)

	if error != OK:
		_transitioning = false
		_set_buttons_enabled(true)
		push_error("Unable to load game scene: %s" % game_scene_path)

func _take_preloaded_game_scene() -> PackedScene:
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(game_scene_path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS or status == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(game_scene_path) as PackedScene
	return null

func _set_buttons_enabled(enabled: bool) -> void:
	for button in _menu_buttons:
		if button != null and is_instance_valid(button):
			button.set_interactable(enabled)

func _connect_buttons() -> void:
	_menu_buttons.clear()
	if _button_rack != null:
		for child in _button_rack.get_children():
			var button: MainMenuBlockButton = child as MainMenuBlockButton
			if button != null:
				_register_button(button)
	if _settings_button != null:
		_register_button(_settings_button)

func _register_button(button: MainMenuBlockButton) -> void:
	_menu_buttons.append(button)
	if not button.pressed.is_connected(_on_menu_button_pressed):
		button.pressed.connect(_on_menu_button_pressed)

func _layout_menu_buttons() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var stack_y: float = button_stack_start_y
	if _button_rack != null:
		for child in _button_rack.get_children():
			var button: MainMenuBlockButton = child as MainMenuBlockButton
			if button == null:
				continue
			var placed: Vector3 = Vector3(0.0, stack_y, button_depth_z)
			button.set_base_position(placed)
			stack_y -= button.get_block_height() + button_stack_gap

	if _settings_button != null:
		var settings_y: float = -2.72
		_settings_button.set_base_position(Vector3(corner_x, settings_y, button_depth_z))
		if _version_label != null:
			_version_label.position = Vector3(
				corner_x,
				settings_y - _settings_button.get_block_height() - 0.22,
				button_depth_z - 0.05
			)

func _fit_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	if _background != null:
		_background.set_anchors_preset(Control.PRESET_FULL_RECT)
		_background.offset_left = 0.0
		_background.offset_top = 0.0
		_background.offset_right = 0.0
		_background.offset_bottom = 0.0
		_background.texture = MENU_ART
		_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	if _viewport_container != null:
		_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		_viewport_container.offset_left = 0.0
		_viewport_container.offset_top = 0.0
		_viewport_container.offset_right = 0.0
		_viewport_container.offset_bottom = 0.0
		_viewport_container.stretch = true
		_viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP

	if _viewport != null:
		_viewport.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_viewport.handle_input_locally = false
		_viewport.physics_object_picking = true

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
