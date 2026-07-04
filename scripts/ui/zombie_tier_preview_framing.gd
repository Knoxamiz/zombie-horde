class_name ZombieTierPreviewFraming
extends RefCounted

const MODEL_GROUND_Y := -0.95
const MODEL_SCALE := 1.9
const VIEWPORT_WIDTH := 220
const VIEWPORT_HEIGHT := 300
const SHOWCASE_ICON_SCALE := 1.32
const CAMERA_FOV := 40.0
const FEET_MARGIN := 0.12
const TOP_MARGIN := 0.16
const ICON_TEXTURE_HEIGHT := 128.0
const REFERENCE_BODY_HEIGHT := 2.82
const REFERENCE_TIER: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT

const PREVIEW_LIGHT_TRANSFORM := Transform3D(
	Vector3(0.866025, 0.0, -0.5),
	Vector3(-0.25, 0.866025, -0.433013),
	Vector3(0.433013, 0.5, 0.75),
	Vector3(0.0, 4.0, 4.0)
)


static func get_viewport_size() -> Vector2i:
	return Vector2i(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)


static func get_viewport_size_vector() -> Vector2:
	return Vector2(float(VIEWPORT_WIDTH), float(VIEWPORT_HEIGHT))


static func get_showcase_icon_scale() -> float:
	return SHOWCASE_ICON_SCALE


static func get_model_transform(_tier: ParticipantJoinInfo.SupporterTier = REFERENCE_TIER) -> Transform3D:
	return Transform3D(
		Vector3(MODEL_SCALE, 0.0, 0.0),
		Vector3(0.0, MODEL_SCALE, 0.0),
		Vector3(0.0, 0.0, MODEL_SCALE),
		Vector3(0.0, MODEL_GROUND_Y, 0.0)
	)


static func fit_visual_to_reference(zombie_visual: Node3D) -> void:
	if zombie_visual == null:
		return

	var measured_height: float = measure_visual_height(zombie_visual)
	if measured_height <= 0.001:
		return

	var scale_factor: float = REFERENCE_BODY_HEIGHT / measured_height
	if abs(scale_factor - 1.0) < 0.015:
		return

	zombie_visual.scale = zombie_visual.scale * scale_factor


static func measure_visual_height(root: Node3D) -> float:
	var min_y: float = INF
	var max_y: float = -INF

	for mesh_instance in _find_mesh_instances(root):
		var local_aabb: AABB = mesh_instance.get_aabb()
		for corner_index in range(8):
			var global_corner: Vector3 = mesh_instance.global_transform * local_aabb.get_endpoint(corner_index)
			min_y = min(min_y, global_corner.y)
			max_y = max(max_y, global_corner.y)

	if min_y == INF:
		return 0.0

	return max_y - min_y


static func build_camera_transform(_tier: ParticipantJoinInfo.SupporterTier = REFERENCE_TIER) -> Transform3D:
	var bottom_y: float = MODEL_GROUND_Y - FEET_MARGIN
	var top_y: float = _get_reference_content_top_y() + TOP_MARGIN
	var center_y: float = (bottom_y + top_y) * 0.5
	var content_height: float = max(top_y - bottom_y, 0.5)
	var distance: float = _get_camera_distance_for_height(content_height, CAMERA_FOV)

	var camera_position := Vector3(0.0, center_y, distance)
	var look_target := Vector3(0.0, center_y, 0.0)
	var camera_transform := Transform3D.IDENTITY
	camera_transform.origin = camera_position
	return camera_transform.looking_at(look_target, Vector3.UP)


static func _get_reference_content_top_y() -> float:
	var model_scale: float = MODEL_SCALE
	var head_top_y: float = MODEL_GROUND_Y + 1.05 * model_scale
	var attach_y: float = MODEL_GROUND_Y + SupporterUpgradeApplier.HEAD_ATTACH_OFFSET.y * model_scale
	var icon_half_height: float = (
		SupporterUpgradeApplier.ICON_PIXEL_SIZE
		* SHOWCASE_ICON_SCALE
		* ICON_TEXTURE_HEIGHT
		* 0.5
	)
	var gift_icon_top_y: float = (
		attach_y
		+ (SupporterUpgradeApplier.GIFT_ICON_OFFSET.y * model_scale)
		+ icon_half_height
	)
	return max(head_top_y, gift_icon_top_y)


static func _get_camera_distance_for_height(height: float, fov_degrees: float) -> float:
	var half_fov_radians: float = deg_to_rad(fov_degrees * 0.5)
	return (height * 0.5) / tan(half_fov_radians)


static func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var results: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, results)
	return results


static func _collect_mesh_instances(node: Node, results: Array[MeshInstance3D]) -> void:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		results.append(mesh_instance)

	for child in node.get_children():
		_collect_mesh_instances(child, results)
