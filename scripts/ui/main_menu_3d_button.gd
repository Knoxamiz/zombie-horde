class_name MainMenu3DButton
extends Area3D

signal pressed(action_id: StringName)

@export var action_id: StringName = &""
@export var text: String = "BUTTON"
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

var _hovered: bool = false
var _pressed_down: bool = false
var _base_position: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _block_material: StandardMaterial3D
var _accent_material: StandardMaterial3D

@onready var _block: MeshInstance3D = get_node("Block") as MeshInstance3D
@onready var _accent: MeshInstance3D = get_node("Accent") as MeshInstance3D
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

func _apply_visuals(force: bool) -> void:
	if _block_material == null:
		_block_material = StandardMaterial3D.new()
		_block_material.roughness = 0.78
		_block_material.metallic = 0.0
		_block_material.emission_enabled = true
		_block_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_block.set_surface_override_material(0, _block_material)
	if _accent_material == null:
		_accent_material = StandardMaterial3D.new()
		_accent_material.roughness = 0.58
		_accent_material.emission_enabled = true
		_accent.set_surface_override_material(0, _accent_material)

	var target_color: Color = hover_color if _hovered and interactable else base_color
	var current_color: Color = target_color if force else _block_material.albedo_color.lerp(target_color, 0.22)
	_block_material.albedo_color = current_color
	_block_material.emission = current_color * (0.34 if _hovered and interactable else 0.18)
	_accent_material.albedo_color = accent_color
	_accent_material.emission = accent_color * (0.42 if _hovered and interactable else 0.22)
	_label.modulate = text_color if interactable else Color(text_color.r, text_color.g, text_color.b, 0.42)

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
