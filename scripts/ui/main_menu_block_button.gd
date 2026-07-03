class_name MainMenuBlockButton
extends Area3D

signal pressed(action_id: StringName)

@export var action_id: StringName = &""
@export var text: String = "BUTTON"
@export var base_color: Color = Color(0.4, 0.75, 0.18, 1.0)
@export var hover_color: Color = Color(0.55, 0.92, 0.28, 1.0)
@export var text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var block_size: Vector3 = Vector3(2.0, 0.44, 0.18)
@export var font_size: int = 26
@export var hover_lift: float = 0.08
@export var press_depth: float = 0.05
@export var idle_phase: float = 0.0
@export var interactable: bool = true

var _hovered: bool = false
var _pressed_down: bool = false
var _base_position: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _face_material: StandardMaterial3D
var _edge_material: StandardMaterial3D

@onready var _face: MeshInstance3D = get_node("Face") as MeshInstance3D
@onready var _edge: MeshInstance3D = get_node("Edge") as MeshInstance3D
@onready var _label: Label3D = get_node("Label") as Label3D
@onready var _shape: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D

func _ready() -> void:
	input_ray_pickable = interactable
	_base_position = position
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	_apply_layout()
	_apply_visuals(true)

func _process(delta: float) -> void:
	_time += delta
	var hover_offset: float = hover_lift if _hovered and interactable else 0.0
	var press_offset: float = -press_depth if _pressed_down and interactable else 0.0
	var float_offset: float = sin(_time * 1.1 + idle_phase) * 0.008
	var target_position: Vector3 = _base_position + Vector3(0.0, float_offset, hover_offset + press_offset)
	position = position.lerp(target_position, 1.0 - exp(-16.0 * delta))
	_apply_visuals(false)

func set_interactable(enabled: bool) -> void:
	interactable = enabled
	input_ray_pickable = enabled
	if not enabled:
		_hovered = false
		_pressed_down = false

func _apply_layout() -> void:
	var face_mesh: BoxMesh = BoxMesh.new()
	face_mesh.size = block_size
	_face.mesh = face_mesh

	var edge_mesh: BoxMesh = BoxMesh.new()
	edge_mesh.size = Vector3(block_size.x, 0.06, block_size.z + 0.02)
	_edge.mesh = edge_mesh
	_edge.position = Vector3(0.0, block_size.y * 0.5 + 0.03, 0.0)

	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(block_size.x, block_size.y + 0.08, block_size.z + 0.12)
	_shape.shape = box_shape

	_label.text = text
	_label.modulate = text_color
	_label.font_size = _fit_font_size()
	_label.outline_size = 6
	_label.outline_modulate = Color(0.04, 0.04, 0.04, 0.9)
	_label.position = Vector3(0.0, 0.0, block_size.z * 0.5 + 0.08)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.no_depth_test = true
	_label.render_priority = 10

func _apply_visuals(force: bool) -> void:
	if _face_material == null:
		_face_material = StandardMaterial3D.new()
		_face_material.roughness = 0.42
		_face_material.metallic = 0.0
		_face_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_face.set_surface_override_material(0, _face_material)
	if _edge_material == null:
		_edge_material = StandardMaterial3D.new()
		_edge_material.roughness = 0.35
		_edge_material.metallic = 0.0
		_edge.set_surface_override_material(0, _edge_material)

	var target: Color = hover_color if _hovered and interactable else base_color
	var current: Color = target if force else _face_material.albedo_color.lerp(target, 0.25)
	_face_material.albedo_color = current
	_face_material.emission_enabled = true
	_face_material.emission = current * (0.22 if _hovered and interactable else 0.12)
	_edge_material.albedo_color = _brighten(current, 0.18)
	_edge_material.emission_enabled = true
	_edge_material.emission = _brighten(current, 0.18) * 0.15
	_label.modulate = text_color if interactable else Color(text_color.r, text_color.g, text_color.b, 0.45)

func _fit_font_size() -> int:
	var fitted: int = font_size
	var max_width: float = block_size.x * 0.88
	while fitted > 14 and float(text.length()) * float(fitted) * 0.016 > max_width:
		fitted -= 1
	return fitted

func _brighten(color: Color, amount: float) -> Color:
	return Color(
		clampf(color.r + amount, 0.0, 1.0),
		clampf(color.g + amount, 0.0, 1.0),
		clampf(color.b + amount, 0.0, 1.0),
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
		pressed.emit(action_id)
