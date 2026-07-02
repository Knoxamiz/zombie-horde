class_name RoadMark
extends Node3D

@export var blood_material: Material
@export var scorch_material: Material
@export var scuff_material: Material

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _mark_mesh: MeshInstance3D = get_node("MarkMesh") as MeshInstance3D
@onready var _blood_variant_root: Node3D = get_node_or_null("BloodModels") as Node3D

func configure(mark_type: String, random_seed: int) -> void:
	_rng.seed = random_seed
	rotation_degrees.y = _rng.randf_range(0.0, 360.0)
	var radius: float = _get_radius_for_type(mark_type)
	scale = Vector3(radius * _rng.randf_range(0.78, 1.22), 1.0, radius * _rng.randf_range(0.72, 1.28))
	_set_blood_variant_visible(mark_type == "blood" or mark_type == "death_blood")

	if _mark_mesh != null:
		_mark_mesh.material_override = _get_material_for_type(mark_type)

func _get_radius_for_type(mark_type: String) -> float:
	match mark_type:
		"blood":
			return 1.1
		"death_blood":
			return 1.85
		"scorch":
			return 1.45
		"scuff":
			return 0.75
		_:
			return 0.9

func _get_material_for_type(mark_type: String) -> Material:
	match mark_type:
		"blood", "death_blood":
			return blood_material
		"scorch":
			return scorch_material
		"scuff":
			return scuff_material
		_:
			return scuff_material

func _set_blood_variant_visible(visible: bool) -> void:
	if _blood_variant_root == null:
		return

	var blood_variants: Array[Node3D] = []
	for child in _blood_variant_root.get_children():
		var variant: Node3D = child as Node3D
		if variant != null:
			variant.visible = false
			blood_variants.append(variant)

	if not visible or blood_variants.is_empty():
		return

	var selected_index: int = _rng.randi_range(0, blood_variants.size() - 1)
	blood_variants[selected_index].visible = true
