class_name RaceMapController
extends Node

signal active_map_changed(map_index: int, display_name: String)

@export var feature_config: FeatureAccessConfig
@export var race_world_path: NodePath
@export var zombie_manager_path: NodePath
@export var base_goal_path: NodePath
@export var minigun_path: NodePath
@export var hazard_config: HazardConfig
@export var zombie_config: ZombieConfig
@export var powerup_config: PowerupConfig
@export var human_defender_config: HumanDefenderConfig
@export var default_map_index: int = 0
@export var map_0_definition: RaceMapDefinition
@export var map_1_definition: RaceMapDefinition
@export var map_2_definition: RaceMapDefinition
@export var map_3_definition: RaceMapDefinition
@export var map_4_definition: RaceMapDefinition
@export var map_5_definition: RaceMapDefinition
@export var map_6_definition: RaceMapDefinition

var active_map_index: int = -1
var active_map_id: String = ""
var _prototype_test_map_id: String = ""
var _race_world: Node3D
var _active_map: Node3D
var _zombie_manager: ZombieManager
var _base_goal: Node3D
var _minigun: Node3D

func _ready() -> void:
	_race_world = get_node_or_null(race_world_path) as Node3D
	_zombie_manager = get_node_or_null(zombie_manager_path) as ZombieManager
	_base_goal = get_node_or_null(base_goal_path) as Node3D
	_minigun = get_node_or_null(minigun_path) as Node3D
	if not GameEvents.round_started.is_connected(_on_round_started):
		GameEvents.round_started.connect(_on_round_started)
	var profile: StreamerSettingsProfile = StreamerSettingsProfile.load_from_disk()
	apply_profile(profile)

func apply_profile(profile: StreamerSettingsProfile) -> bool:
	_prototype_test_map_id = ""
	var map_id: String = MapCatalog.DEFAULT_MAP_ID
	if profile != null:
		map_id = profile.get_selected_map_id()
	return set_active_map_by_id(map_id)


func set_active_map_index(requested_index: int) -> bool:
	var map_id: String = MapCatalog.resolve_selectable_map_id("", requested_index)
	return set_active_map_by_id(map_id)


func set_active_map_by_id(requested_map_id: String, is_fallback_attempt: bool = false) -> bool:
	_prototype_test_map_id = ""
	var trimmed_id: String = requested_map_id.strip_edges()
	var entry: Dictionary = MapCatalog.get_entry_by_id(trimmed_id)
	var fallback_used: bool = false
	var fallback_reason: String = ""

	if trimmed_id.is_empty() or entry.is_empty() or not MapCatalog.is_entry_selectable(entry):
		fallback_used = true
		fallback_reason = "map id missing or not selectable (requested='%s')" % trimmed_id
	elif not _entry_paths_exist(entry):
		fallback_used = true
		fallback_reason = "resource or scene path missing for id='%s'" % trimmed_id

	if fallback_used:
		_log_map_selection(
			"map_load",
			trimmed_id,
			entry,
			fallback_used,
			fallback_reason
		)
		if is_fallback_attempt or trimmed_id == MapCatalog.DEFAULT_MAP_ID:
			return false
		push_warning(
			"RaceMapController: %s; falling back to City Highway" % fallback_reason
		)
		return set_active_map_by_id(MapCatalog.DEFAULT_MAP_ID, true)

	var legacy_index: int = int(entry.get("legacy_index", 0))
	var definition: RaceMapDefinition = get_map_definition_for_legacy_index(legacy_index)
	if definition == null or definition.scene == null or _race_world == null:
		_log_map_selection(
			"map_load",
			trimmed_id,
			entry,
			true,
			"definition or scene failed to load"
		)
		if is_fallback_attempt or trimmed_id == MapCatalog.DEFAULT_MAP_ID:
			return false
		push_warning(
			"RaceMapController: map '%s' failed to load; falling back to City Highway" % trimmed_id
		)
		return set_active_map_by_id(MapCatalog.DEFAULT_MAP_ID, true)

	if (
		active_map_id == trimmed_id
		and not is_prototype_test_load_active()
		and _get_current_map() != null
	):
		_apply_map_geometry(definition, _get_current_map())
		_apply_gameplay_dimensions(definition)
		_log_map_selection("map_reload", trimmed_id, entry, false, "")
		return false

	var old_map: Node = _race_world.get_node_or_null("RoadArena")
	if old_map != null:
		old_map.name = "RoadArena_Unloading"
		old_map.queue_free()

	var new_map: Node3D = definition.scene.instantiate() as Node3D
	if new_map == null:
		_log_map_selection(
			"map_load",
			trimmed_id,
			entry,
			true,
			"scene instantiation failed"
		)
		if is_fallback_attempt or trimmed_id == MapCatalog.DEFAULT_MAP_ID:
			return false
		push_warning(
			"RaceMapController: failed to instantiate map '%s'; falling back to City Highway" % trimmed_id
		)
		return set_active_map_by_id(MapCatalog.DEFAULT_MAP_ID, true)

	new_map.name = "RoadArena"
	_race_world.add_child(new_map)
	_race_world.move_child(new_map, 0)
	_active_map = new_map
	active_map_id = trimmed_id
	active_map_index = legacy_index
	_apply_map_geometry(definition, new_map)
	_apply_gameplay_dimensions(definition)
	_log_map_selection("map_load", trimmed_id, entry, false, "")
	active_map_changed.emit(active_map_index, get_map_name_by_id(active_map_id))
	return true

func get_allowed_map_index(requested_index: int) -> int:
	return MapCatalog.resolve_legacy_index_from_map_id(
		MapCatalog.resolve_selectable_map_id("", requested_index)
	)


func get_allowed_map_id(requested_map_id: String) -> String:
	return MapCatalog.resolve_selectable_map_id(requested_map_id)

func get_map_count() -> int:
	return MapCatalog.get_selectable_count()

static func get_catalog_definition(index: int) -> RaceMapDefinition:
	return MapCatalog.load_definition_for_playable_index(index)

static func is_catalog_map_available(index: int, _feature_config: FeatureAccessConfig) -> bool:
	return MapCatalog.is_playable_legacy_index(index)

static func get_catalog_map_name(index: int) -> String:
	var entry: Dictionary = MapCatalog.get_entry_by_legacy_index(index)
	if entry.is_empty() or not MapCatalog.is_entry_selectable(entry):
		return MapCatalog.get_playable_display_name(0)
	return str(entry.get("display_name", "City Highway"))

func get_map_name(index: int) -> String:
	return get_map_name_by_id(MapCatalog.resolve_selectable_map_id("", index))


func get_map_name_by_id(map_id: String) -> String:
	var definition: RaceMapDefinition = get_map_definition_by_id(map_id)
	if definition == null:
		return MapCatalog.get_selectable_display_name(MapCatalog.DEFAULT_MAP_ID)
	return definition.display_name


func get_map_scene(index: int) -> PackedScene:
	return get_map_scene_by_id(MapCatalog.resolve_selectable_map_id("", index))


func get_map_scene_by_id(map_id: String) -> PackedScene:
	var definition: RaceMapDefinition = get_map_definition_by_id(map_id)
	if definition == null:
		return null
	return definition.scene


func get_map_definition(index: int) -> RaceMapDefinition:
	return get_map_definition_for_legacy_index(
		MapCatalog.resolve_legacy_index_from_map_id(
			MapCatalog.resolve_selectable_map_id("", index)
		)
	)


func get_map_definition_by_id(map_id: String) -> RaceMapDefinition:
	var resolved_id: String = MapCatalog.resolve_selectable_map_id(map_id)
	var legacy_index: int = MapCatalog.resolve_legacy_index_from_map_id(resolved_id)
	return get_map_definition_for_legacy_index(legacy_index)


func get_map_definition_for_legacy_index(legacy_index: int) -> RaceMapDefinition:
	var definition: RaceMapDefinition = _get_exported_map_definition(legacy_index)
	if definition != null:
		return definition
	return MapCatalog.load_definition_for_legacy_index(legacy_index)

func _get_exported_map_definition(index: int) -> RaceMapDefinition:
	match index:
		0:
			return map_0_definition
		1:
			return map_1_definition
		2:
			return map_2_definition
		3:
			return map_3_definition
		4:
			return map_4_definition
		5:
			return map_5_definition
		6:
			return map_6_definition
		_:
			return null

func is_map_available(index: int) -> bool:
	return MapCatalog.is_playable_legacy_index(index)

func get_active_map_name() -> String:
	if not _prototype_test_map_id.is_empty():
		var prototype_definition: RaceMapDefinition = MapCatalog.load_definition_by_id(_prototype_test_map_id)
		if prototype_definition != null:
			return prototype_definition.display_name
	if active_map_id.is_empty():
		return get_map_name_by_id(MapCatalog.DEFAULT_MAP_ID)
	return get_map_name_by_id(active_map_id)


func is_prototype_test_load_active() -> bool:
	return not _prototype_test_map_id.is_empty()


func get_prototype_test_map_id() -> String:
	return _prototype_test_map_id


func load_prototype_map_for_test(map_id: String) -> bool:
	if map_id.strip_edges().is_empty():
		return _fallback_prototype_load_to_city_highway("empty map id")

	var entry: Dictionary = MapCatalog.get_entry_by_id(map_id)
	if entry.is_empty():
		return _fallback_prototype_load_to_city_highway("unknown map id '%s'" % map_id)
	if not MapCatalog.is_prototype_testable(entry):
		return _fallback_prototype_load_to_city_highway(
			"map '%s' is not an enabled=false prototype entry" % map_id
		)

	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(map_id)
	if definition == null or definition.scene == null:
		return _fallback_prototype_load_to_city_highway("missing definition or scene for '%s'" % map_id)
	if _race_world == null:
		return _fallback_prototype_load_to_city_highway("race world is not available")

	return _load_map_definition_for_test(map_id, definition)


func clear_prototype_test_load(restore_saved_map: bool = true) -> bool:
	if _prototype_test_map_id.is_empty():
		return false
	_prototype_test_map_id = ""
	if not restore_saved_map:
		return true
	return apply_profile(StreamerSettingsProfile.load_from_disk())


func frame_spectator_camera_for_definition(
	spectator_camera: SpectatorCameraController,
	definition: RaceMapDefinition,
	enable_mouse_look: bool = false
) -> void:
	if spectator_camera == null or definition == null:
		return
	var view: Dictionary = compute_race_camera_view_for_definition(definition)
	spectator_camera.set_view(
		view.get("position", Vector3.ZERO),
		view.get("rotation_degrees", Vector3.ZERO),
		enable_mouse_look
	)


static func compute_race_camera_view_for_definition(definition: RaceMapDefinition) -> Dictionary:
	if definition == null:
		return {"position": Vector3.ZERO, "rotation_degrees": Vector3.ZERO}

	var spawn_z: float = definition.spawn_origin.z
	var goal_z: float = definition.goal_position.z
	var center_z: float = (spawn_z + goal_z) * 0.5
	var bridge_length: float = abs(goal_z - spawn_z)
	var side_offset: float = max(definition.lane_half_width + 6.0, 12.0)
	var height: float = clampf(bridge_length * 0.2, 12.0, 20.0)
	var back_offset: float = clampf(bridge_length * 0.38, 26.0, 46.0)
	var camera_position := Vector3(-side_offset, height, spawn_z - back_offset)
	var focus := Vector3(0.0, 0.9, center_z)

	var look_transform := Transform3D(Basis(), camera_position).looking_at(focus, Vector3.UP)
	var rotation_degrees: Vector3 = look_transform.basis.get_euler(EULER_ORDER_YXZ) * (180.0 / PI)
	return {
		"position": camera_position,
		"rotation_degrees": rotation_degrees,
		"focus": focus,
	}


func _load_map_definition_for_test(map_id: String, definition: RaceMapDefinition) -> bool:
	var old_map: Node = _race_world.get_node_or_null("RoadArena")
	if old_map != null:
		old_map.name = "RoadArena_Unloading"
		old_map.queue_free()

	var new_map: Node3D = definition.scene.instantiate() as Node3D
	if new_map == null:
		return _fallback_prototype_load_to_city_highway("failed to instantiate scene for '%s'" % map_id)

	new_map.name = "RoadArena"
	_race_world.add_child(new_map)
	_race_world.move_child(new_map, 0)
	_active_map = new_map
	_prototype_test_map_id = map_id
	active_map_id = ""
	active_map_index = -1

	_apply_map_geometry(definition, new_map)
	_apply_gameplay_dimensions(definition)
	_log_prototype_dimension_report(definition)
	active_map_changed.emit(-1, definition.display_name)
	print("RaceMapController: prototype test load succeeded for '%s'" % map_id)
	return true


func _fallback_prototype_load_to_city_highway(reason: String) -> bool:
	push_warning("RaceMapController: prototype test load failed (%s); falling back to City Highway" % reason)
	_prototype_test_map_id = ""
	var profile: StreamerSettingsProfile = StreamerSettingsProfile.load_from_disk()
	var saved_map_id: String = MapCatalog.DEFAULT_MAP_ID
	if profile != null:
		saved_map_id = profile.get_selected_map_id()
	return set_active_map_by_id(saved_map_id)


func _log_prototype_dimension_report(definition: RaceMapDefinition) -> void:
	if definition == null:
		return
	print("=== Prototype Map Dimension Report ===")
	print("spawn_origin: %s" % definition.spawn_origin)
	print("goal_position: %s" % definition.goal_position)
	print("lane_half_width: %.2f" % definition.lane_half_width)
	print("out_of_bounds_half_width: %.2f" % definition.out_of_bounds_half_width)
	print("out_of_bounds_z: %.1f to %.1f" % [definition.out_of_bounds_min_z, definition.out_of_bounds_max_z])
	print("hazard_placement_half_width: %.2f" % definition.hazard_placement_half_width)
	print("hazard_placement_z: %.1f to %.1f" % [definition.hazard_placement_min_z, definition.hazard_placement_max_z])


func _clamp_map_index(index: int) -> int:
	return MapCatalog.resolve_legacy_index_from_map_id(
		MapCatalog.resolve_selectable_map_id("", index)
	)


func _on_round_started(_round_number: int) -> void:
	if is_prototype_test_load_active():
		return
	var entry: Dictionary = MapCatalog.get_entry_by_id(active_map_id)
	_log_map_selection("race_start", active_map_id, entry, false, "")


func _entry_paths_exist(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	var resource_path: String = str(entry.get("resource_path", ""))
	var scene_path: String = str(entry.get("scene_path", ""))
	return (
		not resource_path.is_empty()
		and ResourceLoader.exists(resource_path)
		and not scene_path.is_empty()
		and ResourceLoader.exists(scene_path)
	)


func _log_map_selection(
	context: String,
	map_id: String,
	entry: Dictionary,
	fallback_used: bool,
	fallback_reason: String
) -> void:
	var display_name: String = MapCatalog.get_selectable_display_name(map_id)
	var status: String = str(entry.get("status", "unknown"))
	var resource_path: String = str(entry.get("resource_path", ""))
	var scene_path: String = str(entry.get("scene_path", ""))
	print(
		"RaceMapController [%s]: label='%s' map_id='%s' status='%s' resource='%s' scene='%s' fallback=%s%s"
		% [
			context,
			display_name,
			map_id,
			status,
			resource_path,
			scene_path,
			fallback_used,
			"" if fallback_reason.is_empty() else " reason='%s'" % fallback_reason,
		]
	)

func _get_current_map() -> Node3D:
	if _active_map != null and is_instance_valid(_active_map):
		return _active_map
	if _race_world == null:
		return null
	return _race_world.get_node_or_null("RoadArena") as Node3D

func _apply_map_geometry(definition: RaceMapDefinition, map: Node3D) -> void:
	if definition == null or map == null:
		return

	var core_road: Node3D = map.get_node_or_null("CoreRoad") as Node3D
	if core_road != null:
		core_road.scale = definition.road_core_scale
	else:
		map.scale = definition.road_core_scale

func _apply_gameplay_dimensions(definition: RaceMapDefinition) -> void:
	if definition == null:
		return

	if _zombie_manager != null:
		_zombie_manager.spawn_origin = definition.spawn_origin
		_zombie_manager.spawn_area_size = definition.spawn_area_size
		_zombie_manager.goal_position = definition.goal_position

	if zombie_config != null:
		zombie_config.lane_half_width = definition.lane_half_width
		zombie_config.out_of_bounds_half_width = definition.out_of_bounds_half_width
		zombie_config.out_of_bounds_min_z = definition.out_of_bounds_min_z
		zombie_config.out_of_bounds_max_z = definition.out_of_bounds_max_z

	if hazard_config != null:
		hazard_config.placement_half_width = definition.hazard_placement_half_width
		hazard_config.placement_min_z = definition.hazard_placement_min_z
		hazard_config.placement_max_z = definition.hazard_placement_max_z
		hazard_config.obstacle_half_width = definition.obstacle_half_width
		hazard_config.obstacle_min_z = definition.obstacle_min_z
		hazard_config.obstacle_max_z = definition.obstacle_max_z
		hazard_config.obstacle_lane_count = definition.obstacle_lane_count
		hazard_config.obstacle_segment_length = definition.obstacle_segment_length

	if powerup_config != null:
		powerup_config.placement_half_width = definition.powerup_placement_half_width
		powerup_config.placement_min_z = definition.powerup_placement_min_z
		powerup_config.placement_max_z = definition.powerup_placement_max_z

	if human_defender_config != null:
		human_defender_config.placement_half_width = definition.defender_placement_half_width
		human_defender_config.placement_min_z = definition.defender_placement_min_z
		human_defender_config.placement_max_z = definition.defender_placement_max_z

	if _base_goal != null:
		_base_goal.global_position = definition.base_position
	if _minigun != null:
		_minigun.global_position = definition.minigun_position
