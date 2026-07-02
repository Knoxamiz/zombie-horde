class_name VisualSettingsController
extends Node

@export var visual_config: StreamerVisualConfig
@export var world_environment_path: NodePath
@export var road_arena_path: NodePath
@export var minigun_path: NodePath
@export var race_environment: Environment
@export var lobby_environment: Environment

var _world_environment: WorldEnvironment
var _road_arena: Node3D
var _minigun: BaseMinigun

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	_world_environment = get_node_or_null(world_environment_path) as WorldEnvironment
	_road_arena = get_node_or_null(road_arena_path) as Node3D
	_minigun = get_node_or_null(minigun_path) as BaseMinigun
	apply_visual_settings()

func set_time_of_day(value: int) -> void:
	_get_config().time_of_day = int(clamp(value, 0, 1))
	apply_visual_settings()

func set_backdrop_style(value: int) -> void:
	_get_config().backdrop_style = int(clamp(value, 0, 2))
	apply_visual_settings()

func set_streamer_avatar(value: int) -> void:
	_get_config().streamer_avatar = int(clamp(value, 0, 3))
	apply_visual_settings()

func apply_visual_settings() -> void:
	_road_arena = get_node_or_null(road_arena_path) as Node3D
	_minigun = get_node_or_null(minigun_path) as BaseMinigun
	var active_config: StreamerVisualConfig = _get_config()
	_apply_time_of_day(active_config.time_of_day)
	_apply_backdrop(active_config.backdrop_style)
	_apply_streamer_avatar(active_config.streamer_avatar)
	_apply_streamer_name(active_config.streamer_name)

func _apply_time_of_day(time_of_day: int) -> void:
	var background_color: Color = Color(0.045, 0.055, 0.064, 1.0)
	var ambient_color: Color = Color(0.23, 0.29, 0.26, 1.0)
	var ambient_energy: float = 0.72
	var fog_density: float = 0.027
	var sun_energy: float = 0.34
	var street_light_multiplier: float = 1.35
	var sun_color: Color = Color(0.48, 0.62, 0.66, 1.0)

	match time_of_day:
		StreamerVisualConfig.TimeOfDay.DAY:
			background_color = Color(0.16, 0.18, 0.19, 1.0)
			ambient_color = Color(0.48, 0.5, 0.47, 1.0)
			ambient_energy = 1.02
			fog_density = 0.018
			sun_energy = 1.0
			street_light_multiplier = 0.55
			sun_color = Color(0.95, 0.9, 0.78, 1.0)

	var lobby_background_color: Color = background_color.darkened(0.18).lerp(Color(0.018, 0.03, 0.022, 1.0), 0.58)
	var lobby_ambient_color: Color = ambient_color.lerp(Color(0.16, 0.34, 0.18, 1.0), 0.38)
	var lobby_ambient_energy: float = max(ambient_energy * 0.82, 0.58)
	var lobby_fog_density: float = max(fog_density * 1.8, 0.04)

	_apply_environment_values(race_environment, background_color, ambient_color, ambient_energy, fog_density)
	_apply_environment_values(lobby_environment, lobby_background_color, lobby_ambient_color, lobby_ambient_energy, lobby_fog_density)
	if _world_environment != null and _world_environment.environment != null:
		if _world_environment.environment == lobby_environment:
			_apply_environment_values(_world_environment.environment, lobby_background_color, lobby_ambient_color, lobby_ambient_energy, lobby_fog_density)
		else:
			_apply_environment_values(_world_environment.environment, background_color, ambient_color, ambient_energy, fog_density)
	_apply_road_lighting(sun_energy, street_light_multiplier, sun_color)

func _apply_environment_values(
	environment: Environment,
	background_color: Color,
	ambient_color: Color,
	ambient_energy: float,
	fog_density: float
) -> void:
	if environment == null:
		return

	environment.background_color = background_color
	environment.ambient_light_color = ambient_color
	environment.ambient_light_energy = ambient_energy
	environment.fog_light_color = ambient_color.darkened(0.35)
	environment.fog_density = fog_density

func _apply_road_lighting(sun_energy: float, street_light_multiplier: float, sun_color: Color) -> void:
	if _road_arena == null:
		return

	var sun: DirectionalLight3D = _find_child_by_name(_road_arena, "Sun") as DirectionalLight3D
	if sun != null:
		sun.light_energy = sun_energy
		sun.light_color = sun_color

	for child in _road_arena.get_children():
		_apply_light_multiplier(child, street_light_multiplier)

func _apply_light_multiplier(node: Node, street_light_multiplier: float) -> void:
	var light: Light3D = node as Light3D
	if light != null and not (light is DirectionalLight3D):
		if not light.has_meta("base_light_energy"):
			light.set_meta("base_light_energy", light.light_energy)
		light.light_energy = float(light.get_meta("base_light_energy")) * street_light_multiplier

	for child in node.get_children():
		_apply_light_multiplier(child, street_light_multiplier)

func _apply_backdrop(backdrop_style: int) -> void:
	if _road_arena == null:
		return

	var backdrop: Node3D = _find_child_by_name(_road_arena, "CityBackdrop") as Node3D
	if backdrop == null:
		return

	_set_child_visible(backdrop, "LeftBuildings", backdrop_style != StreamerVisualConfig.BackdropStyle.INDUSTRIAL)
	_set_child_visible(backdrop, "RightBuildings", backdrop_style != StreamerVisualConfig.BackdropStyle.INDUSTRIAL)
	_set_child_visible(backdrop, "KitCityProps", backdrop_style != StreamerVisualConfig.BackdropStyle.SKYLINE)

func _set_child_visible(parent: Node, child_name: String, visible: bool) -> void:
	var child: Node3D = parent.get_node_or_null(child_name) as Node3D
	if child != null:
		child.visible = visible

func _find_child_by_name(root: Node, child_name: String) -> Node:
	if root == null:
		return null
	if root.name == child_name:
		return root

	for child in root.get_children():
		var result: Node = _find_child_by_name(child, child_name)
		if result != null:
			return result
	return null

func _apply_streamer_avatar(avatar_index: int) -> void:
	if _minigun != null:
		_minigun.set_streamer_avatar_index(avatar_index)

func _apply_streamer_name(display_name: String) -> void:
	if _minigun != null:
		_minigun.set_streamer_name(display_name)

func _get_config() -> StreamerVisualConfig:
	if visual_config != null:
		return visual_config
	return StreamerVisualConfig.new()
