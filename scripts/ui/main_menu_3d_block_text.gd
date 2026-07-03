class_name MainMenu3DBlockText
extends Node3D

## Builds chunky extruded block letters from box meshes — no sprites, no Label3D title cheats.

const LETTER_WIDTH: int = 5
const LETTER_HEIGHT: int = 7

const GLYPHS: Dictionary = {
	"A": [
		"01110",
		"10001",
		"10001",
		"11111",
		"10001",
		"10001",
		"10001",
	],
	"B": [
		"11110",
		"10001",
		"10001",
		"11110",
		"10001",
		"10001",
		"11110",
	],
	"C": [
		"01111",
		"10000",
		"10000",
		"10000",
		"10000",
		"10000",
		"01111",
	],
	"D": [
		"11110",
		"10001",
		"10001",
		"10001",
		"10001",
		"10001",
		"11110",
	],
	"E": [
		"11111",
		"10000",
		"10000",
		"11110",
		"10000",
		"10000",
		"11111",
	],
	"H": [
		"10001",
		"10001",
		"10001",
		"11111",
		"10001",
		"10001",
		"10001",
	],
	"I": [
		"11111",
		"00100",
		"00100",
		"00100",
		"00100",
		"00100",
		"11111",
	],
	"M": [
		"10001",
		"11011",
		"10101",
		"10001",
		"10001",
		"10001",
		"10001",
	],
	"N": [
		"10001",
		"11001",
		"10101",
		"10011",
		"10001",
		"10001",
		"10001",
	],
	"O": [
		"01110",
		"10001",
		"10001",
		"10001",
		"10001",
		"10001",
		"01110",
	],
	"R": [
		"11110",
		"10001",
		"10001",
		"11110",
		"10100",
		"10010",
		"10001",
	],
	"S": [
		"01111",
		"10000",
		"10000",
		"01110",
		"00001",
		"00001",
		"11110",
	],
	"T": [
		"11111",
		"00100",
		"00100",
		"00100",
		"00100",
		"00100",
		"00100",
	],
	"Z": [
		"11111",
		"00001",
		"00010",
		"00100",
		"01000",
		"10000",
		"11111",
	],
	"(": [
		"0010",
		"0100",
		"1000",
		"1000",
		"1000",
		"0100",
		"0010",
	],
	")": [
		"0100",
		"0010",
		"0001",
		"0001",
		"0001",
		"0010",
		"0100",
	],
}

@export var lines: PackedStringArray = PackedStringArray(["ZOMBIE", "(CHAT)", "HORDE"])
@export var line_colors: PackedColorArray = PackedColorArray([
	Color(0.46, 0.92, 0.14, 1.0),
	Color(1.0, 0.58, 0.08, 1.0),
	Color(0.58, 0.22, 0.92, 1.0),
])
@export var block_size: Vector3 = Vector3(0.34, 0.34, 0.52)
@export var letter_spacing: float = 0.12
@export var line_spacing: float = 0.38
@export var depth_layers: int = 3
@export var idle_sway_strength: float = 0.018
@export_range(0.0, 1.0, 0.05) var crack_strength: float = 0.72
@export_range(0.0, 1.0, 0.05) var drip_strength: float = 0.55

var _line_roots: Array[Node3D] = []
var _drip_nodes: Array[MeshInstance3D] = []
var _time: float = 0.0
var _stone_texture: Texture2D
var _blood_texture: Texture2D

func _ready() -> void:
	_stone_texture = _make_noise_texture(Color(0.42, 0.4, 0.36), Color(0.18, 0.16, 0.14), 96)
	_blood_texture = _make_noise_texture(Color(0.72, 0.08, 0.06), Color(0.32, 0.02, 0.02), 64)
	_rebuild()

func _process(delta: float) -> void:
	_time += delta
	for index in range(_line_roots.size()):
		var line_root: Node3D = _line_roots[index]
		if line_root == null:
			continue
		var phase: float = float(index) * 0.7
		line_root.position.y = sin(_time * 0.82 + phase) * idle_sway_strength
		line_root.rotation.z = sin(_time * 0.55 + phase) * 0.008

	for drip_index in range(_drip_nodes.size()):
		var drip: MeshInstance3D = _drip_nodes[drip_index]
		if drip == null:
			continue
		var drip_phase: float = float(drip_index) * 0.41
		drip.position.y = drip.position.y + sin(_time * 1.35 + drip_phase) * 0.0008
		drip.scale.y = 1.0 + sin(_time * 1.1 + drip_phase) * 0.06

func set_lines(new_lines: PackedStringArray, colors: PackedColorArray = PackedColorArray()) -> void:
	lines = new_lines
	if not colors.is_empty():
		line_colors = colors
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_line_roots.clear()
	_drip_nodes.clear()

	var total_height: float = float(max(lines.size() - 1, 0)) * (float(LETTER_HEIGHT) * block_size.y + line_spacing)
	var y_cursor: float = total_height * 0.5

	for line_index in range(lines.size()):
		var line_text: String = lines[line_index].to_upper()
		var line_color: Color = line_colors[line_index] if line_index < line_colors.size() else Color.WHITE
		var line_root: Node3D = Node3D.new()
		line_root.name = "Line_%d" % line_index
		add_child(line_root)
		_line_roots.append(line_root)

		var letter_cursor_x: float = -_measure_line_width(line_text) * 0.5
		for character_index in range(line_text.length()):
			var glyph_key: String = line_text.substr(character_index, 1)
			if not GLYPHS.has(glyph_key):
				letter_cursor_x += block_size.x * 2.2 + letter_spacing
				continue

			var glyph: PackedStringArray = _get_glyph_rows(glyph_key)
			var glyph_width: int = glyph[0].length()
			_build_glyph(line_root, glyph, glyph_width, letter_cursor_x, y_cursor, line_color)
			letter_cursor_x += float(glyph_width) * block_size.x + letter_spacing + block_size.x * 0.55

		y_cursor -= float(LETTER_HEIGHT) * block_size.y + line_spacing

func _get_glyph_rows(glyph_key: String) -> PackedStringArray:
	var rows: Array = GLYPHS[glyph_key] as Array
	var packed: PackedStringArray = PackedStringArray()
	for row in rows:
		packed.append(String(row))
	return packed

func _measure_line_width(line_text: String) -> float:
	var width: float = 0.0
	for character_index in range(line_text.length()):
		var glyph_key: String = line_text.substr(character_index, 1)
		if not GLYPHS.has(glyph_key):
			width += block_size.x * 2.2 + letter_spacing
			continue
		var glyph: PackedStringArray = _get_glyph_rows(glyph_key)
		width += float(glyph[0].length()) * block_size.x + letter_spacing + block_size.x * 0.55
	return width

func _build_glyph(
	parent: Node3D,
	glyph: PackedStringArray,
	glyph_width: int,
	origin_x: float,
	origin_y: float,
	tint: Color
) -> void:
	for row in range(glyph.size()):
		var row_text: String = glyph[row]
		for column in range(row_text.length()):
			if row_text[column] != "1":
				continue

			var local_x: float = origin_x + float(column) * block_size.x
			var local_y: float = origin_y - float(row) * block_size.y
			_add_block(parent, Vector3(local_x, local_y, 0.0), tint, row, column, glyph_width)

func _add_block(
	parent: Node3D,
	position: Vector3,
	tint: Color,
	row: int,
	column: int,
	glyph_width: int
) -> void:
	for layer in range(depth_layers):
		var block: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = block_size
		block.mesh = mesh
		block.position = position + Vector3(0.0, 0.0, -float(layer) * block_size.z * 0.34)
		block.material_override = _make_block_material(tint, row, column, layer, glyph_width)
		parent.add_child(block)

	if drip_strength <= 0.0:
		return
	if (row + column + glyph_width) % 3 != 0:
		return

	var drip: MeshInstance3D = MeshInstance3D.new()
	var drip_mesh: BoxMesh = BoxMesh.new()
	var drip_height: float = block_size.y * randf_range(0.35, 0.95) * drip_strength
	drip_mesh.size = Vector3(block_size.x * 0.42, drip_height, block_size.z * 0.36)
	drip.mesh = drip_mesh
	drip.position = position + Vector3(0.0, -block_size.y * 0.5 - drip_height * 0.5, block_size.z * 0.18)
	drip.material_override = _make_drip_material(tint)
	parent.add_child(drip)
	_drip_nodes.append(drip)

func _make_block_material(
	tint: Color,
	row: int,
	column: int,
	layer: int,
	glyph_width: int
) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var shade: float = 0.82 - float(layer) * 0.12 + float(row) * 0.012 - float(column) * 0.004
	var base: Color = Color(
		clampf(tint.r * shade, 0.0, 1.0),
		clampf(tint.g * shade, 0.0, 1.0),
		clampf(tint.b * shade, 0.0, 1.0),
		1.0
	)
	material.albedo_color = base
	material.albedo_texture = _stone_texture
	material.uv1_scale = Vector3(1.6, 1.6, 1.6)
	material.roughness = 0.84
	material.metallic = 0.02
	material.emission_enabled = true
	material.emission = base * (0.12 + float(layer) * 0.03)
	material.emission_energy_multiplier = 0.7
	if crack_strength > 0.0 and (row + column + glyph_width + layer) % 4 == 0:
		material.roughness = 0.95
		material.albedo_color = base.darkened(0.08 * crack_strength)
	return material

func _make_drip_material(tint: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var blood: Color = Color(0.78, 0.08, 0.05, 1.0).lerp(tint, 0.18)
	material.albedo_color = blood
	material.albedo_texture = _blood_texture
	material.roughness = 0.42
	material.metallic = 0.0
	material.emission_enabled = true
	material.emission = blood * 0.22
	return material

func _make_noise_texture(light: Color, dark: Color, size: int) -> Texture2D:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var n: float = _hash_noise(float(x) * 0.11, float(y) * 0.11)
			var n2: float = _hash_noise(float(x) * 0.23 + 4.0, float(y) * 0.19 + 2.0)
			var blend: float = clampf(n * 0.65 + n2 * 0.35, 0.0, 1.0)
			image.set_pixel(x, y, light.lerp(dark, blend))
	return ImageTexture.create_from_image(image)

func _hash_noise(x: float, y: float) -> float:
	var n: float = sin(x * 12.9898 + y * 78.233) * 43758.5453
	return n - floor(n)
