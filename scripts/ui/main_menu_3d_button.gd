class_name MainMenu3DButton
extends Area3D

signal pressed(action_id: StringName)

@export var action_id: StringName = &""
@export var text: String = "BUTTON"
@export var icon_kind: StringName = &"play"
@export var base_color: Color = Color(0.35, 0.7, 0.1, 1.0)
@export var hover_color: Color = Color(0.55, 0.95, 0.2, 1.0)
@export var accent_color: Color = Color(0.9, 1.0, 0.35, 1.0)
@export var text_color: Color = Color(1.0, 0.96, 0.82, 1.0)
@export var block_size: Vector3 = Vector3(4.55, 0.7, 0.32)
@export var font_size: int = 40
@export var outline_size: int = 7
@export var hover_lift: float = 0.18
@export var press_depth: float = 0.1
@export var idle_phase: float = 0.0
@export var interactable: bool = true
@export_range(0.0, 1.0, 0.05) var texture_strength: float = 0.8

var _hovered: bool = false
var _pressed_down: bool = false
var _base_position: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _block_material: StandardMaterial3D
var _accent_material: StandardMaterial3D
var _lip_material: StandardMaterial3D
var _shadow_material: StandardMaterial3D
var _scratch_material: StandardMaterial3D
var _icon_material: StandardMaterial3D
var _stone_texture: Texture2D
var _detail_nodes: Array[MeshInstance3D] = []
var _icon_nodes: Array[MeshInstance3D] = []

@onready var _block: MeshInstance3D = get_node("Block") as MeshInstance3D
@onready var _accent: MeshInstance3D = get_node("Accent") as MeshInstance3D
@onready var _label: Label3D = get_node("Label") as Label3D
@onready var _shape: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D

func _ready() -> void:
	input_ray_pickable = interactable
	_base_position = position
	_stone_texture = _make_noise_texture(Color(0.5, 0.48, 0.42), Color(0.2, 0.18, 0.15), 64)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	_ensure_detail_nodes()
	_apply_layout()
	_build_icon()
	_apply_visuals(true)

func _process(delta: float) -> void:
	_time += delta
	var hover_offset: float = hover_lift if _hovered and interactable else 0.0
	var press_offset: float = -press_depth if _pressed_down and interactable else 0.0
	var float_offset: float = sin(_time * 1.15 + idle_phase) * 0.018
	var target_position: Vector3 = _base_position + Vector3(0.0, float_offset, hover_offset + press_offset)
	position = position.lerp(target_position, 1.0 - exp(-14.0 * delta))
	rotation.z = lerp_angle(rotation.z, sin(_time * 0.85 + idle_phase) * 0.012, 1.0 - exp(-8.0 * delta))
	_apply_visuals(false)

func set_interactable(enabled: bool) -> void:
	interactable = enabled
	input_ray_pickable = enabled
	if not enabled:
		_hovered = false
		_pressed_down = false

func set_button_text(new_text: String) -> void:
	text = new_text
	if _label != null:
		_label.text = text

func _apply_layout() -> void:
	var block_mesh: BoxMesh = BoxMesh.new()
	block_mesh.size = block_size
	_block.mesh = block_mesh

	var accent_mesh: BoxMesh = BoxMesh.new()
	accent_mesh.size = Vector3(0.16, block_size.y * 0.82, block_size.z + 0.04)
	_accent.mesh = accent_mesh
	_accent.position = Vector3(-block_size.x * 0.5 + 0.13, 0.0, block_size.z * 0.5 + 0.025)

	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(block_size.x, block_size.y, block_size.z + 0.18)
	_shape.shape = box_shape

	_label.position = Vector3(-block_size.x * 0.41, -0.04, block_size.z * 0.5 + 0.08)
	_label.text = text
	_label.modulate = text_color
	_label.font_size = font_size
	_label.outline_size = outline_size
	_label.no_depth_test = true
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ensure_detail_materials()
	_apply_surface_detail()

func _ensure_detail_nodes() -> void:
	_detail_nodes.clear()
	for node_name in ["TopLip", "BottomShadow", "RightEdge", "ScratchA", "ScratchB", "ScratchC"]:
		_detail_nodes.append(_get_or_create_mesh(node_name))

func _get_or_create_mesh(node_name: String) -> MeshInstance3D:
	var mesh_node: MeshInstance3D = get_node_or_null(node_name) as MeshInstance3D
	if mesh_node != null:
		return mesh_node

	mesh_node = MeshInstance3D.new()
	mesh_node.name = node_name
	add_child(mesh_node)
	return mesh_node

func _apply_surface_detail() -> void:
	if _detail_nodes.size() < 6:
		return

	var front_z: float = block_size.z * 0.5 + 0.055
	_set_detail_box(_detail_nodes[0], Vector3(block_size.x * 0.92, 0.045, 0.04), Vector3(0.08, block_size.y * 0.5 - 0.075, front_z), _lip_material)
	_set_detail_box(_detail_nodes[1], Vector3(block_size.x * 0.92, 0.055, 0.045), Vector3(-0.02, -block_size.y * 0.5 + 0.08, front_z - 0.01), _shadow_material)
	_set_detail_box(_detail_nodes[2], Vector3(0.08, block_size.y * 0.78, 0.045), Vector3(block_size.x * 0.5 - 0.1, -0.01, front_z), _shadow_material)

	var scratch_alpha: float = clamp(texture_strength, 0.0, 1.0)
	_set_detail_box(_detail_nodes[3], Vector3(block_size.x * 0.2 * scratch_alpha, 0.018, 0.03), Vector3(-block_size.x * 0.02, block_size.y * 0.18, front_z + 0.012), _scratch_material)
	_set_detail_box(_detail_nodes[4], Vector3(block_size.x * 0.16 * scratch_alpha, 0.016, 0.03), Vector3(block_size.x * 0.18, -block_size.y * 0.04, front_z + 0.012), _scratch_material)
	_set_detail_box(_detail_nodes[5], Vector3(block_size.x * 0.1 * scratch_alpha, 0.014, 0.03), Vector3(-block_size.x * 0.22, -block_size.y * 0.2, front_z + 0.012), _scratch_material)

func _set_detail_box(mesh_node: MeshInstance3D, size: Vector3, local_position: Vector3, material: Material) -> void:
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_node.mesh = box_mesh
	mesh_node.position = local_position
	if material != null:
		mesh_node.set_surface_override_material(0, material)

func _apply_visuals(force: bool) -> void:
	if _block_material == null:
		_block_material = StandardMaterial3D.new()
		_block_material.roughness = 0.78
		_block_material.metallic = 0.0
		_block_material.emission_enabled = true
		_block_material.no_depth_test = true
		_block_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_block.set_surface_override_material(0, _block_material)
	if _accent_material == null:
		_accent_material = StandardMaterial3D.new()
		_accent_material.roughness = 0.58
		_accent_material.emission_enabled = true
		_accent_material.no_depth_test = true
		_accent.set_surface_override_material(0, _accent_material)
	_ensure_detail_materials()

	var target_color: Color = hover_color if _hovered and interactable else base_color
	var current_color: Color = target_color if force else _block_material.albedo_color.lerp(target_color, 0.22)
	_block_material.albedo_color = current_color
	_block_material.albedo_texture = _stone_texture
	_block_material.uv1_scale = Vector3(1.4, 1.4, 1.4)
	_block_material.emission = current_color * (0.34 if _hovered and interactable else 0.18)
	_accent_material.albedo_color = accent_color
	_accent_material.emission = accent_color * (0.42 if _hovered and interactable else 0.22)
	_lip_material.albedo_color = _shift_color(current_color, 0.12)
	_lip_material.emission = current_color * 0.18
	_shadow_material.albedo_color = _shift_color(current_color, -0.22)
	_shadow_material.emission = current_color * 0.04
	_scratch_material.albedo_color = _shift_color(current_color, 0.19)
	_scratch_material.emission = current_color * 0.1
	_label.modulate = text_color if interactable else Color(text_color.r, text_color.g, text_color.b, 0.42)
	if _icon_material != null:
		_icon_material.albedo_color = Color(1, 1, 1, 0.95) if interactable else Color(1, 1, 1, 0.35)
		_icon_material.emission = accent_color * (0.55 if _hovered and interactable else 0.28)

func _build_icon() -> void:
	for icon_node in _icon_nodes:
		if icon_node != null and is_instance_valid(icon_node):
			icon_node.queue_free()
	_icon_nodes.clear()

	if _icon_material == null:
		_icon_material = _make_detail_material()
		_icon_material.emission_enabled = true

	var front_z: float = block_size.z * 0.5 + 0.1
	var icon_root := Node3D.new()
	icon_root.name = "IconRoot"
	icon_root.position = Vector3(-block_size.x * 0.5 + 0.34, 0.0, front_z)
	add_child(icon_root)

	match icon_kind:
		&"play":
			_add_icon_box(icon_root, Vector3(0.16, 0.22, 0.05), Vector3(0.05, 0.0, 0.0))
			_add_icon_box(icon_root, Vector3(0.08, 0.18, 0.05), Vector3(-0.03, 0.0, 0.0))
			_add_icon_box(icon_root, Vector3(0.08, 0.18, 0.05), Vector3(-0.03, 0.18, 0.0), Vector3(0, 0, -0.72))
			_add_icon_box(icon_root, Vector3(0.08, 0.18, 0.05), Vector3(-0.03, -0.18, 0.0), Vector3(0, 0, 0.72))
		&"streamer":
			_add_icon_box(icon_root, Vector3(0.16, 0.16, 0.05), Vector3(0.0, 0.14, 0.0))
			_add_icon_box(icon_root, Vector3(0.28, 0.16, 0.05), Vector3(0.0, -0.1, 0.0))
		&"trophy":
			_add_icon_box(icon_root, Vector3(0.24, 0.08, 0.05), Vector3(0.0, 0.12, 0.0))
			_add_icon_box(icon_root, Vector3(0.16, 0.14, 0.05), Vector3(0.0, 0.02, 0.0))
			_add_icon_box(icon_root, Vector3(0.08, 0.12, 0.05), Vector3(0.0, -0.1, 0.0))
		&"gear":
			_add_icon_box(icon_root, Vector3(0.18, 0.18, 0.05), Vector3(0.0, 0.0, 0.0))
			_add_icon_box(icon_root, Vector3(0.08, 0.08, 0.06), Vector3(0.0, 0.0, 0.01))
			for angle_index in range(4):
				var angle: float = float(angle_index) * TAU / 4.0
				_add_icon_box(
					icon_root,
					Vector3(0.06, 0.06, 0.05),
					Vector3(cos(angle) * 0.14, sin(angle) * 0.14, 0.0)
				)
		&"exit":
			_add_icon_box(icon_root, Vector3(0.18, 0.04, 0.05), Vector3(0.0, 0.08, 0.0), Vector3(0, 0, 0.52))
			_add_icon_box(icon_root, Vector3(0.18, 0.04, 0.05), Vector3(0.0, -0.08, 0.0), Vector3(0, 0, -0.52))

func _add_icon_box(parent: Node3D, size: Vector3, local_position: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var icon_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	icon_node.mesh = mesh
	icon_node.position = local_position
	icon_node.rotation = rotation
	icon_node.material_override = _icon_material
	parent.add_child(icon_node)
	_icon_nodes.append(icon_node)

func _make_noise_texture(light: Color, dark: Color, size: int) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var n := abs(sin(float(x) * 0.17 + float(y) * 0.23) * 43758.5453)
			n -= floor(n)
			image.set_pixel(x, y, light.lerp(dark, n))
	return ImageTexture.create_from_image(image)

func _make_detail_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.roughness = 0.7
	material.metallic = 0.0
	material.emission_enabled = true
	material.no_depth_test = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material

func _ensure_detail_materials() -> void:
	if _lip_material == null:
		_lip_material = _make_detail_material()
	if _shadow_material == null:
		_shadow_material = _make_detail_material()
	if _scratch_material == null:
		_scratch_material = _make_detail_material()

func _shift_color(color: Color, amount: float) -> Color:
	return Color(
		clamp(color.r + amount, 0.0, 1.0),
		clamp(color.g + amount, 0.0, 1.0),
		clamp(color.b + amount, 0.0, 1.0),
		color.a
	)

func _on_mouse_entered() -> void:
	if not interactable:
		return
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
		pressed.emit(action_id)
