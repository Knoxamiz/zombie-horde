class_name WorldTextBoard
extends Node3D

@export var title_text: String = "BOARD"
@export_multiline var body_text: String = ""
@export var board_size: Vector2 = Vector2(4.8, 2.8)
@export var board_depth: float = 0.18
@export var title_font_size: int = 30
@export var body_font_size: int = 18
@export var title_outline_size: int = 7
@export var body_outline_size: int = 5
@export var face_color: Color = Color(0.015, 0.02, 0.012, 0.94)
@export var frame_color: Color = Color(1.0, 0.48, 0.08, 1.0)
@export var title_color: Color = Color(0.88, 1.0, 0.34, 1.0)
@export var body_color: Color = Color(1.0, 0.94, 0.74, 1.0)
@export var glow_strength: float = 0.18
@export_range(0.0, 1.0, 0.05) var texture_strength: float = 0.75
@export var title_z: float = 0.16
@export var body_z: float = 0.17

var _face_material: StandardMaterial3D
var _frame_material: StandardMaterial3D
var _detail_material: StandardMaterial3D
var _shadow_material: StandardMaterial3D
var _face_detail_nodes: Array[MeshInstance3D] = []
var _bolt_nodes: Array[MeshInstance3D] = []

@onready var _face: MeshInstance3D = get_node_or_null("Face") as MeshInstance3D
@onready var _top_rim: MeshInstance3D = get_node_or_null("TopRim") as MeshInstance3D
@onready var _bottom_rim: MeshInstance3D = get_node_or_null("BottomRim") as MeshInstance3D
@onready var _left_rim: MeshInstance3D = get_node_or_null("LeftRim") as MeshInstance3D
@onready var _right_rim: MeshInstance3D = get_node_or_null("RightRim") as MeshInstance3D
@onready var _title_label: Label3D = get_node_or_null("TitleLabel") as Label3D
@onready var _body_label: Label3D = get_node_or_null("BodyLabel") as Label3D

func _ready() -> void:
	_ensure_nodes()
	_apply_layout()
	_apply_text()

func set_board_text(new_title: String, new_body: String) -> void:
	title_text = new_title
	body_text = new_body
	_apply_text()

func set_title(new_title: String) -> void:
	title_text = new_title
	_apply_text()

func set_body(new_body: String) -> void:
	body_text = new_body
	_apply_text()

func set_board_visible(enabled: bool) -> void:
	visible = enabled

func _ensure_nodes() -> void:
	_face = _get_or_create_mesh("Face")
	_top_rim = _get_or_create_mesh("TopRim")
	_bottom_rim = _get_or_create_mesh("BottomRim")
	_left_rim = _get_or_create_mesh("LeftRim")
	_right_rim = _get_or_create_mesh("RightRim")
	_title_label = _get_or_create_label("TitleLabel")
	_body_label = _get_or_create_label("BodyLabel")
	_ensure_detail_nodes()

func _ensure_detail_nodes() -> void:
	_face_detail_nodes.clear()
	for index in range(5):
		_face_detail_nodes.append(_get_or_create_mesh("FaceScuff%d" % index))

	_bolt_nodes.clear()
	for index in range(4):
		_bolt_nodes.append(_get_or_create_mesh("CornerPlate%d" % index))

func _get_or_create_mesh(node_name: String) -> MeshInstance3D:
	var mesh_node: MeshInstance3D = get_node_or_null(node_name) as MeshInstance3D
	if mesh_node != null:
		return mesh_node

	mesh_node = MeshInstance3D.new()
	mesh_node.name = node_name
	add_child(mesh_node)
	return mesh_node

func _get_or_create_label(node_name: String) -> Label3D:
	var label: Label3D = get_node_or_null(node_name) as Label3D
	if label != null:
		return label

	label = Label3D.new()
	label.name = node_name
	label.texture_filter = 4
	label.no_depth_test = true
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	add_child(label)
	return label

func _apply_layout() -> void:
	_face_material = _make_material(face_color, glow_strength)
	_frame_material = _make_material(frame_color, glow_strength * 1.8)
	_detail_material = _make_material(_shift_color(face_color, 0.055), glow_strength * 0.7)
	_shadow_material = _make_material(_shift_color(frame_color, -0.24), glow_strength * 0.9)

	_set_box(_face, Vector3(board_size.x, board_size.y, board_depth), Vector3.ZERO, _face_material)
	_set_box(_top_rim, Vector3(board_size.x + 0.18, 0.13, board_depth + 0.08), Vector3(0.0, board_size.y * 0.5 + 0.06, 0.03), _frame_material)
	_set_box(_bottom_rim, Vector3(board_size.x + 0.18, 0.13, board_depth + 0.08), Vector3(0.0, -board_size.y * 0.5 - 0.06, 0.03), _frame_material)
	_set_box(_left_rim, Vector3(0.13, board_size.y + 0.18, board_depth + 0.08), Vector3(-board_size.x * 0.5 - 0.06, 0.0, 0.03), _frame_material)
	_set_box(_right_rim, Vector3(0.13, board_size.y + 0.18, board_depth + 0.08), Vector3(board_size.x * 0.5 + 0.06, 0.0, 0.03), _frame_material)
	_apply_surface_detail()

	var left_edge: float = -board_size.x * 0.43
	_title_label.position = Vector3(left_edge, board_size.y * 0.4, board_depth * 0.5 + title_z)
	_body_label.position = Vector3(left_edge, board_size.y * 0.22, board_depth * 0.5 + body_z)

func _apply_surface_detail() -> void:
	var detail_alpha: float = clamp(texture_strength, 0.0, 1.0)
	var detail_z: float = board_depth * 0.5 + 0.014
	for index in range(_face_detail_nodes.size()):
		var width: float = board_size.x * (0.2 + float(index % 3) * 0.09)
		var x_offset: float = board_size.x * (-0.18 + float(index) * 0.09)
		var y_offset: float = board_size.y * (0.26 - float(index) * 0.12)
		var scuff_size: Vector3 = Vector3(width * detail_alpha, 0.018, 0.012)
		_set_box(_face_detail_nodes[index], scuff_size, Vector3(x_offset, y_offset, detail_z), _detail_material)

	var bolt_margin_x: float = board_size.x * 0.5 - 0.18
	var bolt_margin_y: float = board_size.y * 0.5 - 0.18
	var bolt_positions: Array[Vector3] = [
		Vector3(-bolt_margin_x, bolt_margin_y, detail_z + 0.018),
		Vector3(bolt_margin_x, bolt_margin_y, detail_z + 0.018),
		Vector3(-bolt_margin_x, -bolt_margin_y, detail_z + 0.018),
		Vector3(bolt_margin_x, -bolt_margin_y, detail_z + 0.018),
	]
	for index in range(_bolt_nodes.size()):
		_set_box(_bolt_nodes[index], Vector3(0.13, 0.13, 0.055), bolt_positions[index], _shadow_material)

func _set_box(mesh_node: MeshInstance3D, size: Vector3, local_position: Vector3, material: Material) -> void:
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_node.mesh = box_mesh
	mesh_node.position = local_position
	mesh_node.set_surface_override_material(0, material)

func _make_material(color: Color, emission_scale: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	material.metallic = 0.0
	material.emission_enabled = true
	material.emission = color * emission_scale
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material

func _shift_color(color: Color, amount: float) -> Color:
	return Color(
		clamp(color.r + amount, 0.0, 1.0),
		clamp(color.g + amount, 0.0, 1.0),
		clamp(color.b + amount, 0.0, 1.0),
		color.a
	)

func _apply_text() -> void:
	if _title_label == null or _body_label == null:
		return

	_title_label.text = title_text
	_title_label.modulate = title_color
	_title_label.font_size = title_font_size
	_title_label.outline_size = title_outline_size
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_body_label.text = body_text
	_body_label.modulate = body_color
	_body_label.font_size = body_font_size
	_body_label.outline_size = body_outline_size
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
