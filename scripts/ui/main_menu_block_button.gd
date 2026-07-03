class_name MainMenuBlockButton
extends Area3D

signal pressed(action_id: StringName)

const MENU_FONT: FontFile = preload("res://assets/fonts/bangers.ttf")

@export var action_id: StringName = &""
@export var text: String = "BUTTON"
@export var base_color: Color = Color(0.4, 0.75, 0.18, 1.0)
@export var hover_color: Color = Color(0.55, 0.92, 0.28, 1.0)
@export var text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var block_size: Vector3 = Vector3(1.6, 0.32, 0.14)
@export var font_size: int = 22
@export var horizontal_padding: float = 0.22
@export var vertical_padding: float = 0.08
@export var min_block_width: float = 1.05
@export var autofit_block: bool = true
@export var hover_lift: float = 0.12
@export var hover_scale: float = 1.06
@export var press_depth: float = 0.09
@export var press_scale: float = 0.94
@export var idle_phase: float = 0.0
@export var interactable: bool = true

var _hovered: bool = false
var _pressed_down: bool = false
var _base_position: Vector3 = Vector3.ZERO
var _base_scale: Vector3 = Vector3.ONE
var _time: float = 0.0
var _face_material: StandardMaterial3D
var _edge_material: StandardMaterial3D
var _highlight_material: StandardMaterial3D

@onready var _face: MeshInstance3D = get_node("Face") as MeshInstance3D
@onready var _edge: MeshInstance3D = get_node("Edge") as MeshInstance3D
@onready var _highlight: MeshInstance3D = get_node("Highlight") as MeshInstance3D
@onready var _label: Label3D = get_node("Label") as Label3D
@onready var _shape: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D

func _ready() -> void:
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
	var float_offset: float = sin(_time * 1.1 + idle_phase) * 0.004
	var target_position: Vector3 = _base_position + Vector3(0.0, float_offset, hover_offset + press_offset)
	position = position.lerp(target_position, 1.0 - exp(-18.0 * delta))

	var target_scale_factor: float = 1.0
	if _pressed_down and interactable:
		target_scale_factor = press_scale
	elif _hovered and interactable:
		target_scale_factor = hover_scale
	var target_scale: Vector3 = _base_scale * target_scale_factor
	scale = scale.lerp(target_scale, 1.0 - exp(-20.0 * delta))

	_apply_visuals(false)

func set_interactable(enabled: bool) -> void:
	interactable = enabled
	input_ray_pickable = enabled
	if not enabled:
		_hovered = false
		_pressed_down = false

func _apply_layout() -> void:
	if autofit_block:
		block_size = _compute_block_size()

	var face_mesh: BoxMesh = BoxMesh.new()
	face_mesh.size = block_size
	_face.mesh = face_mesh

	var edge_mesh: BoxMesh = BoxMesh.new()
	edge_mesh.size = Vector3(block_size.x + 0.02, 0.045, block_size.z + 0.02)
	_edge.mesh = edge_mesh
	_edge.position = Vector3(0.0, block_size.y * 0.5 + 0.022, 0.0)

	var highlight_mesh: BoxMesh = BoxMesh.new()
	highlight_mesh.size = Vector3(block_size.x + 0.05, block_size.y + 0.05, 0.02)
	_highlight.mesh = highlight_mesh
	_highlight.position = Vector3(0.0, 0.0, block_size.z * 0.5 + 0.01)

	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(block_size.x + 0.06, block_size.y + 0.08, block_size.z + 0.14)
	_shape.shape = box_shape

	_label.font = MENU_FONT
	_label.text = text
	_label.modulate = text_color
	_label.font_size = font_size
	_label.outline_size = 8
	_label.outline_modulate = Color(0.05, 0.05, 0.05, 1.0)
	_label.position = Vector3(0.0, 0.0, block_size.z * 0.5 + 0.07)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.no_depth_test = true
	_label.render_priority = 10

func _compute_block_size() -> Vector3:
	var text_width_px: float = MENU_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_height_px: float = MENU_FONT.get_height(font_size)
	var width_scale: float = 0.0036
	var height_scale: float = 0.0031
	var fitted_width: float = maxf(min_block_width, text_width_px * width_scale + horizontal_padding)
	var fitted_height: float = maxf(0.28, text_height_px * height_scale + vertical_padding)
	return Vector3(fitted_width, fitted_height, block_size.z)

func _apply_visuals(force: bool) -> void:
	if _face_material == null:
		_face_material = StandardMaterial3D.new()
		_face_material.roughness = 0.38
		_face_material.metallic = 0.0
		_face_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_face.set_surface_override_material(0, _face_material)
	if _edge_material == null:
		_edge_material = StandardMaterial3D.new()
		_edge_material.roughness = 0.3
		_edge_material.metallic = 0.0
		_edge.set_surface_override_material(0, _edge_material)
	if _highlight_material == null:
		_highlight_material = StandardMaterial3D.new()
		_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_highlight_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_highlight.set_surface_override_material(0, _highlight_material)

	var target: Color = hover_color if _hovered and interactable else base_color
	var blend_speed: float = 1.0 if force else 0.3
	var current: Color = target if force else _face_material.albedo_color.lerp(target, blend_speed)
	_face_material.albedo_color = current

	var emission_strength: float = 0.1
	if _pressed_down and interactable:
		emission_strength = 0.08
	elif _hovered and interactable:
		emission_strength = 0.42
	_face_material.emission_enabled = true
	_face_material.emission = _brighten(current, 0.12) * emission_strength

	_edge_material.albedo_color = _brighten(current, 0.22 if _hovered else 0.14)
	_edge_material.emission_enabled = true
	_edge_material.emission = _brighten(current, 0.2) * (0.28 if _hovered and interactable else 0.1)

	var highlight_alpha: float = 0.0
	var highlight_color: Color = Color(1.0, 1.0, 1.0, 0.0)
	if _hovered and interactable and not _pressed_down:
		highlight_alpha = 0.22
		highlight_color = Color(1.0, 1.0, 0.85, highlight_alpha)
	elif _pressed_down and interactable:
		highlight_alpha = 0.08
		highlight_color = Color(0.0, 0.0, 0.0, highlight_alpha)
	_highlight_material.albedo_color = highlight_color
	_highlight.visible = highlight_alpha > 0.0

	var label_target: Color = text_color
	if _hovered and interactable:
		label_target = _brighten(text_color, 0.08)
	_label.modulate = label_target if interactable else Color(text_color.r, text_color.g, text_color.b, 0.45)

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
