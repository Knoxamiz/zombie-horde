class_name MainMenu3DInfoPanel
extends Node3D

## Mounted 3D info board with frame, backing plate, and Label3D copy.

@export var header_text: String = "PANEL"
@export var body_text: String = ""
@export var header_color: Color = Color(1.0, 0.32, 0.22, 1.0)
@export var body_color: Color = Color(0.82, 1.0, 0.3, 1.0)
@export var frame_color: Color = Color(0.72, 0.28, 0.06, 1.0)
@export var face_color: Color = Color(0.018, 0.035, 0.02, 1.0)
@export var panel_size: Vector2 = Vector2(3.0, 1.85)
@export var frame_thickness: float = 0.16
@export var header_font_size: int = 30
@export var body_font_size: int = 22
@export var mount_pole: bool = false
@export var mount_siren: bool = false

var _body_label: Label3D
var _header_label: Label3D
var _siren_light: OmniLight3D

func _ready() -> void:
	_build()
	_apply_text()

func set_panel_text(header: String, body: String) -> void:
	header_text = header
	body_text = body
	_apply_text()

func _apply_text() -> void:
	if _header_label != null:
		_header_label.text = header_text
	if _body_label != null:
		_body_label.text = body_text

func _build() -> void:
	var face := _make_box(
		"Face",
		Vector3(panel_size.x, panel_size.y, 0.12),
		Vector3.ZERO,
		_make_face_material()
	)

	_make_box(
		"RimTop",
		Vector3(panel_size.x + frame_thickness * 0.35, frame_thickness, frame_thickness),
		Vector3(0.0, panel_size.y * 0.5 + frame_thickness * 0.45, 0.04),
		_make_frame_material()
	)
	_make_box(
		"RimBottom",
		Vector3(panel_size.x + frame_thickness * 0.35, frame_thickness, frame_thickness),
		Vector3(0.0, -panel_size.y * 0.5 - frame_thickness * 0.45, 0.04),
		_make_frame_material()
	)
	_make_box(
		"RimLeft",
		Vector3(frame_thickness, panel_size.y + frame_thickness * 0.35, frame_thickness),
		Vector3(-panel_size.x * 0.5 - frame_thickness * 0.45, 0.0, 0.04),
		_make_frame_material()
	)
	_make_box(
		"RimRight",
		Vector3(frame_thickness, panel_size.y + frame_thickness * 0.35, frame_thickness),
		Vector3(panel_size.x * 0.5 + frame_thickness * 0.45, 0.0, 0.04),
		_make_frame_material()
	)

	for bolt_index in range(4):
		var bolt_x: float = panel_size.x * 0.42 if bolt_index % 2 == 0 else -panel_size.x * 0.42
		var bolt_y: float = panel_size.y * 0.38 if bolt_index < 2 else -panel_size.y * 0.38
		_make_box(
			"Bolt_%d" % bolt_index,
			Vector3(0.12, 0.12, 0.05),
			Vector3(bolt_x, bolt_y, 0.12),
			_make_frame_material()
		)

	_header_label = Label3D.new()
	_header_label.name = "Header"
	_header_label.text = header_text
	_header_label.font_size = header_font_size
	_header_label.outline_size = 7
	_header_label.modulate = header_color
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_label.position = Vector3(-panel_size.x * 0.44, panel_size.y * 0.34, face.position.z + 0.08)
	add_child(_header_label)

	_body_label = Label3D.new()
	_body_label.name = "Body"
	_body_label.text = body_text
	_body_label.font_size = body_font_size
	_body_label.outline_size = 5
	_body_label.modulate = body_color
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body_label.position = Vector3(-panel_size.x * 0.44, panel_size.y * 0.08, face.position.z + 0.08)
	add_child(_body_label)

	if mount_pole:
		_make_box(
			"Pole",
			Vector3(0.14, 1.35, 0.14),
			Vector3(panel_size.x * 0.52, -panel_size.y * 0.5 - 0.78, -0.08),
			_make_frame_material()
		)

	if mount_siren:
		var siren_base := _make_box(
			"SirenBase",
			Vector3(0.34, 0.18, 0.34),
			Vector3(panel_size.x * 0.52, panel_size.y * 0.5 + 0.22, 0.02),
			_make_frame_material()
		)
		var siren_dome := _make_box(
			"SirenDome",
			Vector3(0.28, 0.22, 0.28),
			Vector3(panel_size.x * 0.52, panel_size.y * 0.5 + 0.38, 0.02),
			_make_siren_material()
		)
		_siren_light = OmniLight3D.new()
		_siren_light.name = "SirenLight"
		_siren_light.light_color = Color(1.0, 0.18, 0.12, 1.0)
		_siren_light.light_energy = 2.4
		_siren_light.omni_range = 2.8
		_siren_light.position = siren_dome.position
		add_child(_siren_light)

func _process(delta: float) -> void:
	if _siren_light == null:
		return
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	_siren_light.light_energy = 1.2 + pulse * 2.2

func _make_box(node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = position
	mesh_node.material_override = material
	add_child(mesh_node)
	return mesh_node

func _make_face_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = face_color
	material.roughness = 0.72
	material.metallic = 0.0
	material.emission_enabled = true
	material.emission = Color(0.09, 0.45, 0.13, 1.0)
	material.emission_energy_multiplier = 0.28
	return material

func _make_frame_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = frame_color
	material.roughness = 0.62
	material.metallic = 0.08
	material.emission_enabled = true
	material.emission = frame_color * 0.22
	return material

func _make_siren_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.82, 0.12, 0.08, 1.0)
	material.roughness = 0.35
	material.metallic = 0.1
	material.emission_enabled = true
	material.emission = Color(1.0, 0.2, 0.1, 1.0)
	material.emission_energy_multiplier = 1.4
	return material
