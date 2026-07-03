class_name MainMenuBlockButton
extends Area3D

signal pressed(action_id: StringName)

@export var action_id: StringName = &""
@export var text: String = "BUTTON"
@export var base_color: Color = Color(0.4, 0.75, 0.18, 1.0)
@export var hover_color: Color = Color(0.55, 0.92, 0.28, 1.0)
@export var text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var glow_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var block_size: Vector3 = Vector3(1.6, 0.32, 0.16)
@export var font_size: int = 22
@export var horizontal_padding: float = 0.55
@export var vertical_padding: float = 0.16
@export var min_block_width: float = 1.2
@export var extrusion_layers: int = 5
@export var autofit_block: bool = true
@export var hover_lift: float = 0.1
@export var hover_scale: float = 1.05
@export var press_depth: float = 0.08
@export var press_scale: float = 0.95
@export var idle_phase: float = 0.0
@export var interactable: bool = true

var _hovered: bool = false
var _pressed_down: bool = false
var _base_position: Vector3 = Vector3.ZERO
var _base_scale: Vector3 = Vector3.ONE
var _time: float = 0.0
var _menu_font: Font
var _face_material: StandardMaterial3D
var _depth_material: StandardMaterial3D
var _top_bevel_material: StandardMaterial3D
var _bottom_shade_material: StandardMaterial3D
var _shadow_material: StandardMaterial3D
var _glow_material: StandardMaterial3D
var _glow_pulse: float = 0.0
var _extrusion_labels: Array[Label3D] = []

@onready var _visual_root: Node3D = get_node("VisualRoot") as Node3D
@onready var _glow_back: MeshInstance3D = get_node_or_null("VisualRoot/GlowBack") as MeshInstance3D
@onready var _depth: MeshInstance3D = get_node("VisualRoot/Depth") as MeshInstance3D
@onready var _face: MeshInstance3D = get_node("VisualRoot/Face") as MeshInstance3D
@onready var _top_bevel: MeshInstance3D = get_node("VisualRoot/TopBevel") as MeshInstance3D
@onready var _bottom_shade: MeshInstance3D = get_node("VisualRoot/BottomShade") as MeshInstance3D
@onready var _drop_shadow: MeshInstance3D = get_node("VisualRoot/DropShadow") as MeshInstance3D
@onready var _text_anchor: Node3D = get_node("VisualRoot/TextAnchor") as Node3D
@onready var _label_shadow: Label3D = get_node("VisualRoot/TextAnchor/LabelShadow") as Label3D
@onready var _label: Label3D = get_node("VisualRoot/TextAnchor/Label") as Label3D
@onready var _shape: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	input_ray_pickable = interactable
	_base_position = position
	_base_scale = scale
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	_apply_layout()
	_apply_visuals(true)

func _process(delta: float) -> void:
	_time += delta

	var hover_offset: float = hover_lift if _hovered and interactable and not _pressed_down else 0.0
	var press_offset: float = -press_depth if _pressed_down and interactable else 0.0
	var float_offset: float = sin(_time * 1.1 + idle_phase) * 0.003
	var target_position: Vector3 = _base_position + Vector3(0.0, float_offset, hover_offset + press_offset)
	position = position.lerp(target_position, 1.0 - exp(-18.0 * delta))

	var target_scale_factor: float = 1.0
	if _pressed_down and interactable:
		target_scale_factor = press_scale
	elif _hovered and interactable:
		target_scale_factor = hover_scale
	scale = scale.lerp(_base_scale * target_scale_factor, 1.0 - exp(-20.0 * delta))

	_apply_visuals(false)

func get_block_height() -> float:
	return block_size.y

func set_base_position(world_position: Vector3) -> void:
	_base_position = world_position
	position = world_position

func set_interactable(enabled: bool) -> void:
	interactable = enabled
	input_ray_pickable = enabled
	if not enabled:
		_hovered = false
		_pressed_down = false

func contains_world_point(world_point: Vector3) -> bool:
	var local_point: Vector3 = to_local(world_point)
	var half: Vector3 = block_size * 0.5
	return (
		abs(local_point.x) <= half.x + 0.05
		and abs(local_point.y) <= half.y + 0.05
		and abs(local_point.z) <= half.z + 0.12
	)

func trigger_pressed() -> void:
	if not interactable:
		return
	pressed.emit(action_id)

func set_pressed_state(is_pressed: bool) -> void:
	_pressed_down = is_pressed

func set_hovered_state(is_hovered: bool) -> void:
	_hovered = is_hovered

func intersect_ray(ray_origin: Vector3, ray_direction: Vector3) -> Variant:
	var local_origin: Vector3 = to_local(ray_origin)
	var local_direction: Vector3 = to_local(ray_origin + ray_direction) - local_origin
	if local_direction.length_squared() < 0.000001:
		return null
	local_direction = local_direction.normalized()

	var half: Vector3 = block_size * 0.5 + Vector3(0.04, 0.04, 0.08)
	var t_min: float = -INF
	var t_max: float = INF
	for axis: int in range(3):
		var origin_component: float = local_origin[axis]
		var direction_component: float = local_direction[axis]
		if absf(direction_component) < 0.0001:
			if origin_component < -half[axis] or origin_component > half[axis]:
				return null
			continue
		var t1: float = (-half[axis] - origin_component) / direction_component
		var t2: float = (half[axis] - origin_component) / direction_component
		if t1 > t2:
			var swap: float = t1
			t1 = t2
			t2 = swap
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return null

	if t_max < 0.0:
		return null
	var hit_distance: float = t_min if t_min > 0.0 else t_max
	return hit_distance

func _get_menu_font() -> Font:
	if _menu_font != null:
		return _menu_font

	if ResourceLoader.exists("res://assets/fonts/bangers.ttf"):
		var loaded: Resource = load("res://assets/fonts/bangers.ttf")
		_menu_font = loaded as Font

	if _menu_font == null:
		_menu_font = ThemeDB.fallback_font

	return _menu_font

func _apply_layout() -> void:
	if autofit_block:
		block_size = _compute_block_size()

	var face_z: float = block_size.z * 0.5
	var depth_offset: float = block_size.z * 0.42

	if _glow_back != null:
		var glow_mesh: QuadMesh = QuadMesh.new()
		glow_mesh.size = Vector2(block_size.x * 1.9 + 1.8, block_size.y * 4.6 + 1.8)
		_glow_back.mesh = glow_mesh
		_glow_back.position = Vector3(0.0, 0.0, -depth_offset - 0.04)

	_set_box(_depth, Vector3(block_size.x * 0.98, block_size.y * 0.96, block_size.z * 0.72), Vector3(0.0, -0.01, -depth_offset))
	_set_box(_face, block_size, Vector3.ZERO)
	_set_box(_top_bevel, Vector3(block_size.x * 0.96, block_size.y * 0.1, 0.03), Vector3(0.0, block_size.y * 0.42, face_z + 0.012))
	_set_box(_bottom_shade, Vector3(block_size.x * 0.96, block_size.y * 0.08, 0.03), Vector3(0.0, -block_size.y * 0.42, face_z + 0.01))
	_set_box(_drop_shadow, Vector3(block_size.x * 1.02, 0.03, block_size.z * 0.92), Vector3(0.0, -block_size.y * 0.52, -0.02))

	_text_anchor.position = Vector3(0.0, 0.0, face_z + 0.002)

	var menu_font: Font = _get_menu_font()
	for label_node: Label3D in [_label, _label_shadow]:
		label_node.font = menu_font
		label_node.text = text
		label_node.font_size = font_size
		label_node.outline_size = maxi(6, int(round(float(font_size) * 0.09)))
		label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label_node.position = Vector3.ZERO
		label_node.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label_node.no_depth_test = false

	_label.modulate = text_color
	_label.outline_modulate = Color(0.04, 0.04, 0.04, 1.0)
	_label_shadow.modulate = Color(0.0, 0.0, 0.0, 0.42)
	_label_shadow.outline_size = 0
	_label_shadow.position = Vector3(0.014, -0.016, -0.006)
	_label.render_priority = 12 + extrusion_layers
	_label_shadow.render_priority = 11

	_build_extrusion_labels(menu_font)

	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(block_size.x + 0.04, block_size.y + 0.06, block_size.z + 0.18)
	_shape.shape = box_shape

func _build_extrusion_labels(menu_font: Font) -> void:
	for old_label in _extrusion_labels:
		if old_label != null and is_instance_valid(old_label):
			old_label.queue_free()
	_extrusion_labels.clear()

	var step: float = 0.012
	var extrude_color: Color = _darken(base_color, 0.4)
	for layer in range(extrusion_layers):
		var depth_label: Label3D = Label3D.new()
		depth_label.font = menu_font
		depth_label.text = text
		depth_label.font_size = font_size
		depth_label.outline_size = 0
		depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		depth_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		depth_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		depth_label.no_depth_test = false
		var t: float = float(layer + 1) / float(extrusion_layers)
		depth_label.position = Vector3(-step * float(layer + 1), -step * float(layer + 1), -0.004 * float(layer + 1))
		depth_label.modulate = _darken(extrude_color, t * 0.25)
		depth_label.render_priority = 12 + (extrusion_layers - layer - 1)
		_text_anchor.add_child(depth_label)
		_extrusion_labels.append(depth_label)

func _set_box(mesh_node: MeshInstance3D, size: Vector3, local_position: Vector3) -> void:
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_node.mesh = box_mesh
	mesh_node.position = local_position

func _compute_block_size() -> Vector3:
	var menu_font: Font = _get_menu_font()
	var text_width_px: float = menu_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_height_px: float = menu_font.get_height(font_size)
	var width_scale: float = 0.0044
	var height_scale: float = 0.0034
	var fitted_width: float = maxf(min_block_width, text_width_px * width_scale + horizontal_padding)
	var fitted_height: float = maxf(0.26, text_height_px * height_scale + vertical_padding)
	return Vector3(fitted_width, fitted_height, block_size.z)

func _apply_visuals(force: bool) -> void:
	_ensure_materials()

	var target: Color = hover_color if _hovered and interactable else base_color
	var blend_speed: float = 1.0 if force else 0.28
	var current: Color = target if force else _face_material.albedo_color.lerp(target, blend_speed)

	_face_material.albedo_color = _darken(current, 0.06)
	_face_material.emission = _brighten(current, 0.02) * (0.12 if _hovered and interactable else 0.03)

	_depth_material.albedo_color = _darken(current, 0.32)
	_depth_material.emission = _darken(current, 0.24) * 0.04

	_top_bevel_material.albedo_color = _brighten(current, 0.22 if _hovered else 0.14)
	_top_bevel_material.emission = _brighten(current, 0.14) * (0.14 if _hovered and interactable else 0.05)

	_bottom_shade_material.albedo_color = _darken(current, 0.26)
	_bottom_shade_material.emission = _darken(current, 0.34) * 0.02

	_shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.42 if _hovered and interactable else 0.3)

	if _glow_material != null:
		var glow_tint: Color = glow_color
		if glow_tint.a <= 0.0:
			glow_tint = _brighten(base_color, 0.12)
		_glow_pulse = 0.5 + 0.5 * sin(_time * 2.4 + idle_phase)
		var base_glow_alpha: float = 0.7 + _glow_pulse * 0.2
		var glow_alpha: float = 1.0 if _hovered and interactable else base_glow_alpha
		if not interactable:
			glow_alpha = 0.25
		_glow_material.albedo_color = Color(glow_tint.r, glow_tint.g, glow_tint.b, glow_alpha)
		_glow_material.emission = Color(glow_tint.r, glow_tint.g, glow_tint.b) * (3.0 if _hovered and interactable else 1.8)
		_glow_material.emission_energy_multiplier = 2.2 if _hovered and interactable else 1.4

	var label_target: Color = _brighten(text_color, 0.06) if _hovered and interactable else text_color
	_label.modulate = label_target if interactable else Color(text_color.r, text_color.g, text_color.b, 0.45)

func _ensure_materials() -> void:
	if _face_material == null:
		_face_material = _make_surface_material()
		_face.set_surface_override_material(0, _face_material)
	if _depth_material == null:
		_depth_material = _make_surface_material()
		_depth.set_surface_override_material(0, _depth_material)
	if _top_bevel_material == null:
		_top_bevel_material = _make_surface_material()
		_top_bevel.set_surface_override_material(0, _top_bevel_material)
	if _bottom_shade_material == null:
		_bottom_shade_material = _make_surface_material()
		_bottom_shade.set_surface_override_material(0, _bottom_shade_material)
	if _shadow_material == null:
		_shadow_material = StandardMaterial3D.new()
		_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_drop_shadow.set_surface_override_material(0, _shadow_material)
	if _glow_back != null and _glow_material == null:
		_glow_material = StandardMaterial3D.new()
		_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_material.emission_enabled = true
		_glow_material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		_glow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glow_material.albedo_texture = _make_radial_glow_texture()
		_glow_material.emission_texture = _glow_material.albedo_texture
		_glow_back.set_surface_override_material(0, _glow_material)

func _make_radial_glow_texture() -> Texture2D:
	var size: int = 128
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = float(size - 1) * 0.5
	var max_dist: float = center
	for y in range(size):
		for x in range(size):
			var dx: float = (float(x) - center) / max_dist
			var dy: float = (float(y) - center) / max_dist
			var dist: float = sqrt(dx * dx + dy * dy)
			var falloff: float = clampf(1.0 - dist, 0.0, 1.0)
			falloff = pow(falloff, 1.4)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, falloff))
	return ImageTexture.create_from_image(image)

func _make_surface_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.roughness = 0.82
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.emission_enabled = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material

func _brighten(color: Color, amount: float) -> Color:
	return Color(
		clampf(color.r + amount, 0.0, 1.0),
		clampf(color.g + amount, 0.0, 1.0),
		clampf(color.b + amount, 0.0, 1.0),
		color.a
	)

func _darken(color: Color, amount: float) -> Color:
	return Color(
		clampf(color.r - amount, 0.0, 1.0),
		clampf(color.g - amount, 0.0, 1.0),
		clampf(color.b - amount, 0.0, 1.0),
		color.a
	)

func _on_mouse_entered() -> void:
	if interactable:
		_hovered = true

func _on_mouse_exited() -> void:
	_hovered = false
	_pressed_down = false

func _on_input_event(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not interactable:
		return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return

	_pressed_down = mouse_button.pressed
	if not mouse_button.pressed and _hovered:
		trigger_pressed()
