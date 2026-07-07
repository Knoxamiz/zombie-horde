class_name GameFlowController
extends Node

const AUDIO_MANAGER_SCENE: PackedScene = preload("res://scenes/audio/audio_manager.tscn")
const GAME_SETTINGS_SCENE: PackedScene = preload("res://scenes/settings/game_settings_menu.tscn")

const META_COLLISION_LAYER := "_zh_saved_collision_layer"
const META_COLLISION_MASK := "_zh_saved_collision_mask"
const META_COLLISION_SHAPE_DISABLED := "_zh_saved_collision_shape_disabled"
const META_AREA_MONITORING := "_zh_saved_area_monitoring"
const META_AREA_MONITORABLE := "_zh_saved_area_monitorable"
const META_PROCESS_MODE := "_zh_saved_process_mode"

@export var round_manager_path: NodePath
@export var race_world_path: NodePath
@export var lobby_world_path: NodePath
@export var zombie_manager_path: NodePath
@export var hazard_manager_path: NodePath
@export var powerup_manager_path: NodePath
@export var defender_manager_path: NodePath
@export var race_map_controller_path: NodePath
@export var debug_join_source_path: NodePath
@export var spectator_camera_path: NodePath
@export var hud_path: NodePath
@export var streamer_menu_path: NodePath
@export var pre_round_ui_path: NodePath
@export var world_environment_path: NodePath
@export var transition_overlay_path: NodePath
@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/main_menu/main_menu.tscn"
@export var lobby_environment: Environment
@export var race_environment: Environment
@export var fade_seconds: float = 0.22
@export var intro_camera_position: Vector3 = Vector3(0.0, 7.2, 10.5)
@export var intro_camera_rotation_degrees: Vector3 = Vector3(-27.0, 0.0, 0.0)
@export var lobby_camera_position: Vector3 = Vector3(0.0, 7.2, 10.5)
@export var lobby_camera_rotation_degrees: Vector3 = Vector3(-27.0, 0.0, 0.0)
@export var race_camera_position: Vector3 = Vector3(0.0, 23.0, -46.0)
@export var race_camera_rotation_degrees: Vector3 = Vector3(-31.0, 180.0, 0.0)

var _round_manager: RoundManager
var _race_world: Node
var _lobby_world: Node
var _zombie_manager: Node
var _hazard_manager: Node
var _powerup_manager: Node
var _defender_manager: Node
var _race_map_controller: RaceMapController
var _debug_join_source: DebugJoinSource
var _spectator_camera: SpectatorCameraController
var _hud: CanvasLayer
var _streamer_menu: CanvasLayer
var _pre_round_ui: PreRoundUIController
var _world_environment: WorldEnvironment
var _transition_overlay: ColorRect
var _music_controller: MusicController
var _intro_active: bool = true
var _current_phase: String = ""
var _transition_token: int = 0
var _transition_tween: Tween
var _returning_to_main_menu: bool = false

func _ready() -> void:
	call_deferred("_initialize_flow")

func _initialize_flow() -> void:
	_round_manager = get_node_or_null(round_manager_path) as RoundManager
	_race_world = get_node_or_null(race_world_path)
	_lobby_world = get_node_or_null(lobby_world_path)
	_zombie_manager = get_node_or_null(zombie_manager_path)
	_hazard_manager = get_node_or_null(hazard_manager_path)
	_powerup_manager = get_node_or_null(powerup_manager_path)
	_defender_manager = get_node_or_null(defender_manager_path)
	_race_map_controller = get_node_or_null(race_map_controller_path) as RaceMapController
	_debug_join_source = get_node_or_null(debug_join_source_path) as DebugJoinSource
	_spectator_camera = get_node_or_null(spectator_camera_path) as SpectatorCameraController
	_hud = get_node_or_null(hud_path) as CanvasLayer
	_streamer_menu = get_node_or_null(streamer_menu_path) as CanvasLayer
	_pre_round_ui = get_node_or_null(pre_round_ui_path) as PreRoundUIController
	_world_environment = get_node_or_null(world_environment_path) as WorldEnvironment
	_transition_overlay = get_node_or_null(transition_overlay_path) as ColorRect
	_music_controller = _get_or_create_music_controller()

	if _pre_round_ui != null:
		_pre_round_ui.ready_requested.connect(_on_ready_requested)
		_pre_round_ui.options_requested.connect(_on_options_requested)
		_pre_round_ui.main_menu_requested.connect(_on_main_menu_requested)
	if _race_map_controller != null:
		_race_map_controller.active_map_changed.connect(_on_active_map_changed)

	GameEvents.round_state_changed.connect(_on_round_state_changed)
	GameEvents.round_reset.connect(_on_round_reset)
	GameEvents.round_ended.connect(_on_round_ended)
	_prepare_transition_overlay()
	_apply_phase("lobby")
	_apply_launch_request()
	_fade_overlay_to(0.0, 0.35)

func show_intro() -> void:
	_transition_to_phase("lobby")

func show_lobby() -> void:
	_transition_to_phase("lobby")

func show_race() -> void:
	_transition_to_phase("race")

func _on_ready_requested() -> void:
	if _round_manager != null:
		_round_manager.start_round()

func _on_options_requested() -> void:
	_open_streamer_settings()

func _on_main_menu_requested() -> void:
	if _returning_to_main_menu:
		return

	_returning_to_main_menu = true
	LaunchState.request_intro()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var error: Error = get_tree().change_scene_to_file(main_menu_scene_path)
	if error != OK:
		_returning_to_main_menu = false
		push_error("Unable to return to main menu: %s" % main_menu_scene_path)

func _on_round_state_changed(state_text: String) -> void:
	match state_text:
		"Joining":
			if _intro_active:
				show_intro()
			else:
				show_lobby()
		"Countdown", "Running", "Ended":
			show_race()

func _on_round_reset() -> void:
	_intro_active = false
	show_lobby()

func _on_round_ended(_winner_name: String, _base_won: bool) -> void:
	if _spectator_camera != null:
		_spectator_camera.set_mouse_capture_allowed(false)

func _on_active_map_changed(_map_index: int, _display_name: String) -> void:
	if _current_phase.is_empty():
		return
	_apply_phase(_current_phase)


func _apply_race_camera_view() -> void:
	if _spectator_camera == null:
		return
	var allow_race_free_cam: bool = _should_allow_race_mouse_capture()
	_spectator_camera.set_mouse_capture_allowed(allow_race_free_cam)
	if _race_map_controller != null:
		_race_map_controller.ensure_spectator_camera_active()
	if (
		_race_map_controller != null
		and _race_map_controller.should_use_definition_race_camera()
	):
		var definition: RaceMapDefinition = _race_map_controller.get_active_map_definition()
		if definition != null:
			_race_map_controller.frame_spectator_camera_for_definition(
				_spectator_camera,
				definition,
				allow_race_free_cam
			)
			return
	_spectator_camera.set_view(race_camera_position, race_camera_rotation_degrees, allow_race_free_cam)

func _transition_to_phase(phase_name: String) -> void:
	if phase_name == _current_phase:
		return

	_transition_token += 1
	_run_phase_transition(phase_name, _transition_token)

func _run_phase_transition(phase_name: String, token: int) -> void:
	if _transition_overlay == null:
		_apply_phase(phase_name)
		return

	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_overlay.visible = true
	_transition_tween = create_tween()
	_transition_tween.tween_property(_transition_overlay, "modulate:a", 1.0, max(fade_seconds, 0.01))
	_transition_tween.tween_callback(Callable(self, "_apply_phase_if_current").bind(phase_name, token))
	_transition_tween.tween_interval(0.03)
	_transition_tween.tween_property(_transition_overlay, "modulate:a", 0.0, max(fade_seconds, 0.01))
	_transition_tween.tween_callback(Callable(self, "_hide_transition_overlay_if_current").bind(token))

func _apply_phase_if_current(phase_name: String, token: int) -> void:
	if token == _transition_token:
		_apply_phase(phase_name)

func _apply_phase(phase_name: String) -> void:
	_current_phase = phase_name
	_apply_music_for_phase(phase_name)
	match phase_name:
		"intro":
			_intro_active = true
			_apply_lobby_environment()
			_set_world_active(_race_world, false)
			_set_world_active(_lobby_world, true)
			_set_race_manager_active(false)
			_set_node_visible(_hud, false)
			_set_node_visible(_streamer_menu, false)
			if _pre_round_ui != null:
				_pre_round_ui.set_screen_mode("intro")
			if _spectator_camera != null:
				_spectator_camera.set_mouse_capture_allowed(false)
				_spectator_camera.set_view(intro_camera_position, intro_camera_rotation_degrees, false)
		"lobby":
			_intro_active = false
			_apply_lobby_environment()
			_set_world_active(_race_world, false)
			_set_world_active(_lobby_world, true)
			_set_race_manager_active(false)
			_set_node_visible(_hud, false)
			_set_node_visible(_streamer_menu, true)
			if _pre_round_ui != null:
				_pre_round_ui.set_screen_mode("lobby")
			if _spectator_camera != null:
				_spectator_camera.set_mouse_capture_allowed(false)
				_spectator_camera.set_view(lobby_camera_position, lobby_camera_rotation_degrees, false)
		"race":
			_apply_race_environment()
			_set_world_active(_race_world, true)
			_set_world_active(_lobby_world, false)
			_set_race_manager_active(true)
			_set_node_visible(_hud, true)
			_set_node_visible(_streamer_menu, false)
			if _pre_round_ui != null:
				_pre_round_ui.set_screen_mode("hidden")
			_apply_race_camera_view()

func _apply_launch_request() -> void:
	var request: Dictionary = LaunchState.consume_request()
	if str(request.get("phase", "intro")) != "lobby":
		return

	_apply_phase("lobby")
	var debug_joins_to_seed: int = int(request.get("debug_joins_to_seed", 0))
	if debug_joins_to_seed > 0:
		call_deferred("_seed_launch_debug_joins", debug_joins_to_seed)
	if bool(request.get("open_settings", false)):
		call_deferred("_open_streamer_settings")
	call_deferred("_apply_stream_capture_visuals")

func _apply_stream_capture_visuals() -> void:
	var game_settings: GameSettingsController = get_node_or_null("/root/GameSettings") as GameSettingsController
	if game_settings != null:
		game_settings.apply_stream_capture_visuals_to_scene()

func _should_allow_race_mouse_capture() -> bool:
	var game_settings: GameSettingsController = get_node_or_null("/root/GameSettings") as GameSettingsController
	if game_settings == null:
		return true
	return game_settings.should_lock_race_mouse_capture()

func _apply_music_for_phase(phase_name: String) -> void:
	if _music_controller == null:
		return

	match phase_name:
		"intro", "lobby":
			_music_controller.play_lobby_music()
		"race":
			_music_controller.play_race_music()

func _seed_launch_debug_joins(debug_joins_to_seed: int) -> void:
	if _debug_join_source == null:
		return

	for join_index in range(debug_joins_to_seed):
		_debug_join_source.request_random_join()

func _open_streamer_settings() -> void:
	var streamer_menu_controller: StreamerMenuController = _streamer_menu as StreamerMenuController
	if streamer_menu_controller != null:
		streamer_menu_controller.open_menu()
func _open_game_settings() -> void:
	var game_settings: GameSettingsController = _get_or_create_game_settings()
	if game_settings != null:
		game_settings.open_settings()

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

func _set_node_visible(node: Node, visible: bool) -> void:
	if node == null:
		return

	var node_3d: Node3D = node as Node3D
	if node_3d != null:
		node_3d.visible = visible
		return

	var canvas_layer: CanvasLayer = node as CanvasLayer
	if canvas_layer != null:
		canvas_layer.visible = visible
		return

	var canvas_item: CanvasItem = node as CanvasItem
	if canvas_item != null:
		canvas_item.visible = visible

func _set_world_active(node: Node, active: bool) -> void:
	if node == null:
		return

	_set_node_visible(node, active)
	_set_process_enabled(node, active)
	_set_collision_tree_enabled(node, active)

func _set_race_manager_active(active: bool) -> void:
	_set_world_active(_zombie_manager, active)
	_set_world_active(_hazard_manager, active)
	_set_world_active(_powerup_manager, active)
	_set_world_active(_defender_manager, active)

func _set_process_enabled(node: Node, enabled: bool) -> void:
	if enabled:
		if node.has_meta(META_PROCESS_MODE):
			node.process_mode = int(node.get_meta(META_PROCESS_MODE))
		return

	if not node.has_meta(META_PROCESS_MODE):
		node.set_meta(META_PROCESS_MODE, node.process_mode)
	node.process_mode = Node.PROCESS_MODE_DISABLED

func _set_collision_tree_enabled(node: Node, enabled: bool) -> void:
	_set_collision_node_enabled(node, enabled)
	for child in node.get_children():
		_set_collision_tree_enabled(child, enabled)

func _set_collision_node_enabled(node: Node, enabled: bool) -> void:
	var collision_object: CollisionObject3D = node as CollisionObject3D
	if collision_object != null:
		if enabled:
			if node.has_meta(META_COLLISION_LAYER):
				collision_object.collision_layer = int(node.get_meta(META_COLLISION_LAYER))
			if node.has_meta(META_COLLISION_MASK):
				collision_object.collision_mask = int(node.get_meta(META_COLLISION_MASK))
		else:
			if not node.has_meta(META_COLLISION_LAYER):
				node.set_meta(META_COLLISION_LAYER, collision_object.collision_layer)
			if not node.has_meta(META_COLLISION_MASK):
				node.set_meta(META_COLLISION_MASK, collision_object.collision_mask)
			collision_object.collision_layer = 0
			collision_object.collision_mask = 0

	var area: Area3D = node as Area3D
	if area != null:
		if enabled:
			if node.has_meta(META_AREA_MONITORING):
				area.monitoring = bool(node.get_meta(META_AREA_MONITORING))
			if node.has_meta(META_AREA_MONITORABLE):
				area.monitorable = bool(node.get_meta(META_AREA_MONITORABLE))
		else:
			if not node.has_meta(META_AREA_MONITORING):
				node.set_meta(META_AREA_MONITORING, area.monitoring)
			if not node.has_meta(META_AREA_MONITORABLE):
				node.set_meta(META_AREA_MONITORABLE, area.monitorable)
			area.monitoring = false
			area.monitorable = false

	var collision_shape: CollisionShape3D = node as CollisionShape3D
	if collision_shape != null:
		if enabled:
			if node.has_meta(META_COLLISION_SHAPE_DISABLED):
				collision_shape.disabled = bool(node.get_meta(META_COLLISION_SHAPE_DISABLED))
		else:
			if not node.has_meta(META_COLLISION_SHAPE_DISABLED):
				node.set_meta(META_COLLISION_SHAPE_DISABLED, collision_shape.disabled)
			collision_shape.disabled = true

func _apply_lobby_environment() -> void:
	if _world_environment != null and lobby_environment != null:
		_world_environment.environment = lobby_environment

func _apply_race_environment() -> void:
	if _world_environment != null and race_environment != null:
		_world_environment.environment = race_environment

func _prepare_transition_overlay() -> void:
	if _transition_overlay == null:
		return

	_transition_overlay.visible = true
	_transition_overlay.modulate = Color(1, 1, 1, 1)

func _fade_overlay_to(target_alpha: float, duration: float) -> void:
	if _transition_overlay == null:
		return

	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_overlay.visible = true
	_transition_tween = create_tween()
	_transition_tween.tween_property(_transition_overlay, "modulate:a", target_alpha, max(duration, 0.01))
	if target_alpha <= 0.01:
		_transition_tween.tween_callback(Callable(self, "_hide_transition_overlay_if_current").bind(_transition_token))

func _hide_transition_overlay_if_current(token: int) -> void:
	if token == _transition_token and _transition_overlay != null:
		_transition_overlay.visible = false
