class_name DevAnnotationPainter
extends Node

## Debug-only world spray paint for marking map issues. Exports to artifacts/ for agent review.

signal paint_mode_changed(enabled: bool)
signal strokes_changed()

const GROUP_NAME := "dev_annotation_painter"
const JSON_PATH := "res://artifacts/dev_annotation_latest.json"
const PNG_PATH := "res://artifacts/dev_annotation_latest.png"

enum SprayColor {
	BUG,
	VISUAL,
	SHOULD_WALK,
}

const SPRAY_COLORS: Dictionary = {
	SprayColor.BUG: Color(1.0, 0.2, 0.33, 0.92),
	SprayColor.VISUAL: Color(1.0, 0.87, 0.2, 0.92),
	SprayColor.SHOULD_WALK: Color(0.2, 1.0, 0.53, 0.92),
}

const SPRAY_LABELS: Dictionary = {
	SprayColor.BUG: "bug",
	SprayColor.VISUAL: "visual",
	SprayColor.SHOULD_WALK: "should_walk",
}

const STAMP_RADIUS: float = 0.42
const STAMP_HEIGHT: float = 0.09
const MIN_STAMP_DISTANCE_SQ: float = 0.02
const RAY_LENGTH: float = 1200.0
const ALL_COLLISION_MASK: int = 0x7FFFFFFF

@export var race_world_path: NodePath
@export var race_map_controller_path: NodePath
@export var spectator_camera_path: NodePath

var _race_world: Node3D
var _race_map_controller: RaceMapController
var _spectator_camera: SpectatorCameraController
var _marks_root: Node3D

var _paint_mode_enabled: bool = false
var _spray_color: SprayColor = SprayColor.BUG
var _note: String = ""
var _marks_visible: bool = true
var _strokes: Array[Dictionary] = []
var _current_stroke: Dictionary = {}
var _is_spraying: bool = false
var _last_stamp_position: Vector3 = Vector3(INF, INF, INF)
var _panel_blocks_input: bool = false
var _last_spray_miss_reason: String = ""
var _last_spray_hit_source: String = ""


func _enter_tree() -> void:
	if not OS.is_debug_build():
		queue_free()


func _ready() -> void:
	add_to_group(GROUP_NAME)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_resolve_nodes()


func _resolve_nodes() -> void:
	_race_world = get_node_or_null(race_world_path) as Node3D
	_race_map_controller = get_node_or_null(race_map_controller_path) as RaceMapController
	_spectator_camera = get_node_or_null(spectator_camera_path) as SpectatorCameraController
	_ensure_marks_root()


func _ensure_marks_root() -> void:
	if _race_world == null:
		_race_world = get_node_or_null(race_world_path) as Node3D
	if _race_world == null:
		return
	_marks_root = _race_world.get_node_or_null("DevAnnotations") as Node3D
	if _marks_root == null:
		_marks_root = Node3D.new()
		_marks_root.name = "DevAnnotations"
		_race_world.add_child(_marks_root)


func _unhandled_input(event: InputEvent) -> void:
	if _panel_blocks_input:
		return
	if event.is_action_pressed("dev_annotation_paint"):
		set_paint_mode_enabled(not _paint_mode_enabled)
		get_viewport().set_input_as_handled()


func process_paint_input(event: InputEvent) -> bool:
	if not _paint_mode_enabled or _panel_blocks_input:
		return false

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			_begin_stroke()
			_try_spray_at_screen_position(mouse_button.position)
		else:
			_end_stroke()
		return true

	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion != null and _is_spraying and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_spray_at_screen_position(mouse_motion.position)
		return true

	return false


func set_panel_blocks_input(blocked: bool) -> void:
	_panel_blocks_input = blocked


func is_paint_mode_enabled() -> bool:
	return _paint_mode_enabled


func set_paint_mode_enabled(enabled: bool) -> void:
	if _paint_mode_enabled == enabled:
		return
	_paint_mode_enabled = enabled
	if not enabled:
		_last_spray_miss_reason = ""
		_last_spray_hit_source = ""
	if _spectator_camera == null:
		_spectator_camera = get_node_or_null(spectator_camera_path) as SpectatorCameraController
	if _spectator_camera != null:
		_spectator_camera.set_annotation_paint_active(enabled)
	elif enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	paint_mode_changed.emit(enabled)


func get_spray_color() -> SprayColor:
	return _spray_color


func set_spray_color(color: SprayColor) -> void:
	_spray_color = color


func get_note() -> String:
	return _note


func set_note(text: String) -> void:
	_note = text.strip_edges()


func are_marks_visible() -> bool:
	return _marks_visible


func set_marks_visible(visible: bool) -> void:
	_marks_visible = visible
	if _marks_root != null:
		_marks_root.visible = visible


func get_stamp_count() -> int:
	var count: int = 0
	for stroke in _strokes:
		if stroke is Dictionary:
			var points: Variant = stroke.get("points", [])
			if points is Array:
				count += points.size()
	return count


func get_stroke_count() -> int:
	return _strokes.size()


func get_status_text() -> String:
	if not _paint_mode_enabled:
		return "Paint: off | strokes: %d | stamps: %d" % [get_stroke_count(), get_stamp_count()]

	var hint: String = "left-drag on map"
	if _panel_blocks_input:
		hint = "close F3 panel first"
	elif not _last_spray_miss_reason.is_empty() and get_stamp_count() == 0:
		hint = _last_spray_miss_reason
	elif not _last_spray_hit_source.is_empty():
		hint = "hit: %s" % _last_spray_hit_source

	return "Paint: ON | %s | strokes: %d | stamps: %d" % [hint, get_stroke_count(), get_stamp_count()]


func clear_all_paint() -> void:
	_strokes.clear()
	_current_stroke = {}
	_is_spraying = false
	_last_stamp_position = Vector3(INF, INF, INF)
	if _marks_root != null:
		for child in _marks_root.get_children():
			child.queue_free()
	write_json_report(build_report(self))
	strokes_changed.emit()


func build_report(painter: DevAnnotationPainter = self) -> Dictionary:
	var map_id: String = "unknown"
	if painter._race_map_controller != null:
		map_id = painter._resolve_map_id()

	var camera_payload: Dictionary = {}
	var camera: Camera3D = painter._get_active_camera()
	if camera != null:
		camera_payload = {
			"position": _vector3_to_array(camera.global_position),
			"rotation_degrees": _vector3_to_array(camera.global_rotation_degrees),
		}

	return {
		"version": 1,
		"kind": "dev_annotation_report",
		"map_id": map_id,
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"note": painter._note,
		"camera": camera_payload,
		"strokes": painter._strokes.duplicate(true),
	}


static func write_json_report(report: Dictionary, file_path: String = JSON_PATH) -> bool:
	_ensure_artifacts_dir()
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("DevAnnotationPainter: could not write %s" % file_path)
		return false
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	return true


func export_report(capture_screenshot: bool = true) -> Dictionary:
	var report: Dictionary = build_report()
	write_json_report(report)
	if capture_screenshot:
		await get_tree().process_frame
		await get_tree().process_frame
		_capture_viewport_png()
	print("DevAnnotationPainter: exported %s (%d strokes)" % [JSON_PATH, _strokes.size()])
	return report


func _begin_stroke() -> void:
	_is_spraying = true
	_last_stamp_position = Vector3(INF, INF, INF)
	_current_stroke = {
		"color": _color_to_hex(SPRAY_COLORS[_spray_color]),
		"label": SPRAY_LABELS[_spray_color],
		"points": [],
	}


func _end_stroke() -> void:
	_is_spraying = false
	var points: Variant = _current_stroke.get("points", [])
	if points is Array and not points.is_empty():
		_strokes.append(_current_stroke.duplicate(true))
		strokes_changed.emit()
		write_json_report(build_report())
	_current_stroke = {}
	_last_stamp_position = Vector3(INF, INF, INF)


func _try_spray_at_screen_position(screen_position: Vector2) -> void:
	var hit: Dictionary = _raycast_from_screen(screen_position)
	if hit.is_empty():
		return

	var world_position: Vector3 = hit["position"]
	_last_spray_hit_source = str(hit.get("source", "physics"))
	_last_spray_miss_reason = ""
	if _last_stamp_position.distance_squared_to(world_position) < MIN_STAMP_DISTANCE_SQ:
		return

	_last_stamp_position = world_position
	_add_stamp(world_position, hit.get("normal", Vector3.UP))
	var point_payload: Dictionary = {
		"x": snappedf(world_position.x, 0.01),
		"y": snappedf(world_position.y, 0.01),
		"z": snappedf(world_position.z, 0.01),
	}
	var points: Array = _current_stroke.get("points", [])
	points.append(point_payload)
	_current_stroke["points"] = points


func _raycast_from_screen(screen_position: Vector2) -> Dictionary:
	var camera: Camera3D = _get_active_camera()
	if camera == null:
		_last_spray_miss_reason = "no active camera"
		return {}

	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	if ray_direction.length_squared() < 0.0001:
		_last_spray_miss_reason = "invalid camera ray"
		return {}

	var world: World3D = camera.get_world_3d()
	if world != null:
		var query := PhysicsRayQueryParameters3D.create(
			ray_origin,
			ray_origin + ray_direction * RAY_LENGTH
		)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.collision_mask = ALL_COLLISION_MASK
		var physics_hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if not physics_hit.is_empty():
			physics_hit["source"] = "physics"
			return physics_hit

	var plane_hit: Variant = _raycast_fallback_planes(ray_origin, ray_direction)
	if plane_hit is Vector3:
		return {
			"position": plane_hit,
			"normal": Vector3.UP,
			"source": "deck_plane",
		}

	_last_spray_miss_reason = "aim at road or gap (no surface hit)"
	return {}


static func intersect_ray_with_plane_y(
	ray_origin: Vector3,
	ray_direction: Vector3,
	plane_y: float
) -> Variant:
	if absf(ray_direction.y) < 0.0001:
		return null
	var distance: float = (plane_y - ray_origin.y) / ray_direction.y
	if distance < 0.0 or distance > RAY_LENGTH:
		return null
	return ray_origin + ray_direction * distance


func _raycast_fallback_planes(ray_origin: Vector3, ray_direction: Vector3) -> Variant:
	var plane_heights: Array[float] = _resolve_fallback_plane_heights()
	for plane_y: float in plane_heights:
		var hit_position: Variant = intersect_ray_with_plane_y(ray_origin, ray_direction, plane_y)
		if hit_position is not Vector3:
			continue
		if _is_position_within_map_bounds(hit_position as Vector3):
			return hit_position
	return null


func _resolve_fallback_plane_heights() -> Array[float]:
	var heights: Array[float] = []
	_add_unique_height(heights, 0.0)
	_add_unique_height(heights, 0.8)

	if _race_map_controller == null:
		_race_map_controller = get_node_or_null(race_map_controller_path) as RaceMapController
	if _race_map_controller == null:
		return heights

	var definition: RaceMapDefinition = _race_map_controller.get_active_map_definition()
	if definition == null:
		return heights

	if definition.deck_y > 0.0:
		_add_unique_height(heights, definition.deck_y)
	_add_unique_height(heights, definition.spawn_origin.y)
	_add_unique_height(heights, definition.goal_position.y)
	_add_unique_height(heights, definition.resolve_hazard_surface_y())
	return heights


func _is_position_within_map_bounds(world_position: Vector3) -> bool:
	if _race_map_controller == null:
		return true

	var definition: RaceMapDefinition = _race_map_controller.get_active_map_definition()
	if definition == null:
		return true

	var half_width: float = maxf(definition.out_of_bounds_half_width, definition.lane_half_width + 4.0)
	if absf(world_position.x) > half_width + 2.0:
		return false

	var min_z: float = definition.out_of_bounds_min_z - 2.0
	var max_z: float = definition.out_of_bounds_max_z + 2.0
	return world_position.z >= min_z and world_position.z <= max_z


static func _add_unique_height(heights: Array[float], value: float) -> void:
	for existing: float in heights:
		if is_equal_approx(existing, value):
			return
	heights.append(value)


func _get_active_camera() -> Camera3D:
	if _spectator_camera == null:
		_spectator_camera = get_node_or_null(spectator_camera_path) as SpectatorCameraController
	if _spectator_camera != null:
		var camera: Camera3D = _spectator_camera.get_node_or_null("Camera3D") as Camera3D
		if camera != null:
			return camera
	return get_viewport().get_camera_3d()


func _add_stamp(world_position: Vector3, surface_normal: Vector3) -> void:
	_ensure_marks_root()
	if _marks_root == null:
		return

	var stamp := MeshInstance3D.new()
	stamp.name = "SprayStamp_%d" % (_marks_root.get_child_count() + 1)
	stamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stamp.visible = _marks_visible

	var mesh := CylinderMesh.new()
	mesh.top_radius = STAMP_RADIUS
	mesh.bottom_radius = STAMP_RADIUS
	mesh.height = STAMP_HEIGHT
	stamp.mesh = mesh

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = SPRAY_COLORS[_spray_color]
	material.emission_enabled = true
	material.emission = SPRAY_COLORS[_spray_color]
	material.emission_energy_multiplier = 1.35
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	stamp.material_override = material

	var up: Vector3 = surface_normal.normalized()
	if up.length_squared() < 0.001:
		up = Vector3.UP
	stamp.global_position = world_position + up * (STAMP_HEIGHT * 0.5 + 0.02)
	stamp.look_at(stamp.global_position + up, Vector3.UP)
	stamp.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_marks_root.add_child(stamp)


func _capture_viewport_png(file_path: String = PNG_PATH) -> bool:
	_ensure_artifacts_dir()
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return false
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		return false
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return false
	var error: Error = image.save_png(file_path)
	if error != OK:
		push_error("DevAnnotationPainter: screenshot save failed (%s)" % error)
		return false
	return true


func _resolve_map_id() -> String:
	if _race_map_controller == null:
		return "unknown"
	if _race_map_controller.is_prototype_test_load_active():
		var prototype_id: String = _race_map_controller.get_prototype_test_map_id()
		if not prototype_id.is_empty():
			return prototype_id
	if not _race_map_controller.active_map_id.is_empty():
		return _race_map_controller.active_map_id
	return "unknown"


static func _ensure_artifacts_dir() -> void:
	var absolute_dir: String = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(absolute_dir)


static func _vector3_to_array(value: Vector3) -> Array:
	return [snappedf(value.x, 0.01), snappedf(value.y, 0.01), snappedf(value.z, 0.01)]


static func _color_to_hex(color: Color) -> String:
	return "#%s%s%s" % [
		_color_channel_to_hex(color.r),
		_color_channel_to_hex(color.g),
		_color_channel_to_hex(color.b),
	]


static func _color_channel_to_hex(channel: float) -> String:
	return "%02x" % int(round(clampf(channel, 0.0, 1.0) * 255.0))
