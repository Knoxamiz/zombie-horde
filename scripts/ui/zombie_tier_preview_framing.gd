class_name ZombieTierPreviewFraming
extends RefCounted

const MODEL_GROUND_Y := -0.95
const MODEL_SCALE := 1.9
const VIEWPORT_WIDTH := 220
const VIEWPORT_HEIGHT := 300
const SHOWCASE_ICON_SCALE := 2.35
const CAMERA_FOV := 40.0
const FEET_MARGIN := 0.12
const TOP_MARGIN := 0.18
const HEAD_TOP_LOCAL_Y := 1.05
const ICON_TEXTURE_HEIGHT := 128.0

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


static func needs_icon_headroom(tier: ParticipantJoinInfo.SupporterTier) -> bool:
	return (
		tier == ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT
		or tier == ParticipantJoinInfo.SupporterTier.BITS_DONOR
	)


static func get_model_transform() -> Transform3D:
	return Transform3D(
		Vector3(MODEL_SCALE, 0.0, 0.0),
		Vector3(0.0, MODEL_SCALE, 0.0),
		Vector3(0.0, 0.0, MODEL_SCALE),
		Vector3(0.0, MODEL_GROUND_Y, 0.0)
	)


static func build_camera_transform(tier: ParticipantJoinInfo.SupporterTier) -> Transform3D:
	var bottom_y: float = MODEL_GROUND_Y - FEET_MARGIN
	var top_y: float = _get_content_top_y(tier) + TOP_MARGIN
	var center_y: float = (bottom_y + top_y) * 0.5
	var content_height: float = max(top_y - bottom_y, 0.5)
	var distance: float = _get_camera_distance_for_height(content_height, CAMERA_FOV)

	var camera_position := Vector3(0.0, center_y, distance)
	var look_target := Vector3(0.0, center_y, 0.0)
	var camera_transform := Transform3D.IDENTITY
	camera_transform.origin = camera_position
	return camera_transform.looking_at(look_target, Vector3.UP)


static func _get_content_top_y(tier: ParticipantJoinInfo.SupporterTier) -> float:
	var head_top_local_y: float = 0.88 if tier == ParticipantJoinInfo.SupporterTier.NONE else HEAD_TOP_LOCAL_Y
	var head_top_y: float = MODEL_GROUND_Y + head_top_local_y * MODEL_SCALE
	if not needs_icon_headroom(tier):
		return head_top_y

	var icon_offset_y: float = SupporterUpgradeApplier.BITS_ICON_OFFSET.y
	if tier == ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT:
		icon_offset_y = SupporterUpgradeApplier.GIFT_ICON_OFFSET.y

	var attach_y: float = MODEL_GROUND_Y + SupporterUpgradeApplier.HEAD_ATTACH_OFFSET.y * MODEL_SCALE
	var icon_half_height: float = (
		SupporterUpgradeApplier.ICON_PIXEL_SIZE
		* SHOWCASE_ICON_SCALE
		* ICON_TEXTURE_HEIGHT
		* 0.5
	)
	var icon_top_y: float = attach_y + (icon_offset_y * MODEL_SCALE) + icon_half_height
	if tier == ParticipantJoinInfo.SupporterTier.BITS_DONOR:
		icon_top_y += 0.28 * MODEL_SCALE
	return max(head_top_y, icon_top_y)


static func _get_camera_distance_for_height(height: float, fov_degrees: float) -> float:
	var half_fov_radians: float = deg_to_rad(fov_degrees * 0.5)
	return (height * 0.5) / tan(half_fov_radians)
