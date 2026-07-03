class_name MainMenu3DInfoPanel
extends Node3D

## Dark glass Twitch HUD panel — matches the keyed menu mockup.

@export var header_text: String = "PANEL"
@export var body_text: String = ""
@export var header_color: Color = Color(0.46, 0.92, 0.14, 1.0)
@export var body_color: Color = Color(0.88, 0.92, 1.0, 1.0)
@export var accent_color: Color = Color(0.58, 0.22, 0.92, 1.0)
@export var panel_size: Vector2 = Vector2(1.55, 1.05)
@export var header_font_size: int = 20
@export var body_font_size: int = 14
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
	var face: MeshInstance3D = _make_box(
		"Face",
		Vector3(panel_size.x, panel_size.y, 0.04),
		Vector3.ZERO,
		_make_glass_material()
	)

	_make_box(
		"BorderTop",
		Vector3(panel_size.x + 0.04, 0.03, 0.02),
		Vector3(0.0, panel_size.y * 0.5 + 0.015, 0.03),
		_make_border_material()
	)
	_make_box(
		"BorderBottom",
		Vector3(panel_size.x + 0.04, 0.03, 0.02),
		Vector3(0.0, -panel_size.y * 0.5 - 0.015, 0.03),
		_make_border_material()
	)
	_make_box(
		"BorderLeft",
		Vector3(0.03, panel_size.y + 0.04, 0.02),
		Vector3(-panel_size.x * 0.5 - 0.015, 0.0, 0.03),
		_make_border_material()
	)
	_make_box(
		"BorderRight",
		Vector3(0.03, panel_size.y + 0.04, 0.02),
		Vector3(panel_size.x * 0.5 + 0.015, 0.0, 0.03),
		_make_border_material()
	)

	_header_label = Label3D.new()
	_header_label.name = "Header"
	_header_label.text = header_text
	_header_label.font_size = header_font_size
	_header_label.outline_size = 6
	_header_label.modulate = header_color
	_header_label.render_priority = 8
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_label.position = Vector3(-panel_size.x * 0.44, panel_size.y * 0.34, face.position.z + 0.05)
	add_child(_header_label)

	_body_label = Label3D.new()
	_body_label.name = "Body"
	_body_label.text = body_text
	_body_label.font_size = body_font_size
	_body_label.outline_size = 4
	_body_label.modulate = body_color
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body_label.position = Vector3(-panel_size.x * 0.44, panel_size.y * 0.1, face.position.z + 0.05)
	add_child(_body_label)

	if mount_siren:
		var siren_dome: MeshInstance3D = _make_box(
			"SirenDome",
			Vector3(0.14, 0.14, 0.14),
			Vector3(panel_size.x * 0.44, panel_size.y * 0.5 + 0.12, 0.02),
			_make_siren_material()
		)
		_siren_light = OmniLight3D.new()
		_siren_light.name = "SirenLight"
		_siren_light.light_color = Color(1.0, 0.18, 0.12, 1.0)
		_siren_light.light_energy = 1.8
		_siren_light.omni_range = 1.6
		_siren_light.position = siren_dome.position
		add_child(_siren_light)

func _process(_delta: float) -> void:
	if _siren_light == null:
		return
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	_siren_light.light_energy = 0.8 + pulse * 1.4

func _make_box(node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = position
	mesh_node.material_override = material
	add_child(mesh_node)
	return mesh_node

func _make_glass_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.02, 0.05, 0.03, 0.78)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.92
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color(0.08, 0.18, 0.1, 1.0)
	material.emission_energy_multiplier = 0.18
	return material

func _make_border_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = accent_color
	material.roughness = 0.55
	material.metallic = 0.05
	material.emission_enabled = true
	material.emission = accent_color * 0.35
	return material

func _make_siren_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.82, 0.12, 0.08, 1.0)
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = Color(1.0, 0.2, 0.1, 1.0)
	material.emission_energy_multiplier = 1.2
	return material
