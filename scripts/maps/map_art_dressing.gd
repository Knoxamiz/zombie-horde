class_name MapArtDressing
extends Node3D

## Shared visual-only art direction for the playable map catalog.
##
## This component intentionally creates no collision, navigation, physics,
## lights, or gameplay nodes. Each map receives a small collection of reused
## primitive meshes and materials, keeping the presentation layer cheap enough
## for large zombie crowds while preserving a distinct visual identity.

enum Profile {
	SUBURBAN_OUTBREAK,
	COASTAL_EVACUATION,
	CRUMBLED_HIGHWAY,
	PARKING_GARAGE_CONSTRUCTION,
}

const VisualCollisionSanitizerScript := preload("res://scripts/core/visual_collision_sanitizer.gd")
const GERMAN_SHEPHERD_SCENE := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Characters/Characters_GermanShepherd.gltf"
)
const PUG_SCENE := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Characters/Characters_Pug.gltf"
)

@export var profile: Profile = Profile.SUBURBAN_OUTBREAK

static var _box_mesh: BoxMesh
static var _cylinder_mesh: CylinderMesh
static var _sphere_mesh: SphereMesh
static var _material_cache: Dictionary = {}


func _ready() -> void:
	_build_profile()
	VisualCollisionSanitizerScript.sanitize_subtree(self)


func _build_profile() -> void:
	match profile:
		Profile.SUBURBAN_OUTBREAK:
			_build_suburban_outbreak()
		Profile.COASTAL_EVACUATION:
			_build_coastal_evacuation()
		Profile.CRUMBLED_HIGHWAY:
			_build_crumbled_highway()
		Profile.PARKING_GARAGE_CONSTRUCTION:
			_build_parking_garage_construction()


func _build_suburban_outbreak() -> void:
	# Houses and yards sit beyond the race curb: recognizable suburb, zero gameplay cost.
	var homes: Array[Dictionary] = [
		{"x": -18.0, "z": -57.0, "color": "suburban_blue", "yaw": 0.0},
		{"x": 18.0, "z": -46.0, "color": "suburban_cream", "yaw": PI},
		{"x": -18.0, "z": -20.0, "color": "suburban_cream", "yaw": 0.0},
		{"x": 18.0, "z": -7.0, "color": "suburban_blue", "yaw": PI},
		{"x": -18.0, "z": 19.0, "color": "suburban_red", "yaw": 0.0},
		{"x": 18.0, "z": 34.0, "color": "suburban_cream", "yaw": PI},
		{"x": -18.0, "z": 61.0, "color": "suburban_blue", "yaw": 0.0},
		{"x": 18.0, "z": 72.0, "color": "suburban_red", "yaw": PI},
	]
	for index in range(homes.size()):
		var home: Dictionary = homes[index]
		_build_suburban_home(
			Vector3(float(home["x"]), 0.0, float(home["z"])),
			float(home["yaw"]),
			str(home["color"]),
			index
		)


func _build_suburban_home(position: Vector3, yaw: float, wall_material: String, index: int) -> void:
	var outward_sign: float = sign(position.x)
	_add_box("SuburbanLawn", Vector3(15.5, 0.14, 17.0), position + Vector3(outward_sign * 1.8, -0.24, 0.0), 0.0, "lawn")
	_add_box("SuburbanHouse", Vector3(8.2, 5.8, 7.0), position + Vector3(outward_sign * 3.8, 2.65, 1.2), yaw, wall_material)
	_add_box("SuburbanRoof", Vector3(9.0, 1.15, 7.9), position + Vector3(outward_sign * 3.8, 6.1, 1.2), yaw, "roof")
	_add_box("SuburbanPorch", Vector3(2.3, 0.4, 2.1), position + Vector3(outward_sign * 0.15, 0.18, -1.4), yaw, "concrete")
	_add_box("SuburbanDoor", Vector3(1.15, 2.0, 0.16), position + Vector3(outward_sign * 0.2, 1.2, -1.4), yaw, "door")
	_build_fence_line(position + Vector3(outward_sign * 0.9, 0.38, -6.2), 10.0, yaw)
	_build_mailbox(position + Vector3(outward_sign * 0.1, 0.0, -4.5), yaw)
	if index in [1, 3, 6]:
		_add_dog(position + Vector3(outward_sign * 2.0, 0.0, 3.4), yaw + 0.5, index % 2 == 0)


func _build_fence_line(position: Vector3, width: float, yaw: float) -> void:
	for post_index in range(5):
		var offset: float = -width * 0.5 + float(post_index) * width * 0.25
		var local_offset := Vector3(offset, 0.0, 0.0).rotated(Vector3.UP, yaw)
		_add_box("FencePost", Vector3(0.16, 1.15, 0.16), position + local_offset, yaw, "fence")
	for rail_y in [0.38, 0.78]:
		_add_box("FenceRail", Vector3(width, 0.1, 0.1), position + Vector3(0.0, rail_y, 0.0), yaw, "fence")


func _build_mailbox(position: Vector3, yaw: float) -> void:
	_add_box("MailboxPost", Vector3(0.12, 0.95, 0.12), position + Vector3(0.0, 0.45, 0.0), yaw, "mailbox")
	_add_box("Mailbox", Vector3(0.58, 0.36, 0.44), position + Vector3(0.0, 0.93, 0.0), yaw, "mailbox")


func _build_coastal_evacuation() -> void:
	_add_box("CoastalWater", Vector3(124.0, 0.16, 220.0), Vector3(0.0, -6.4, 0.0), 0.0, "water")
	for side in [-1.0, 1.0]:
		for z in [-70.0, -28.0, 18.0, 63.0]:
			_build_coastal_boat(Vector3(side * 31.0, -5.8, z), 0.22 * side)
		for z in [-82.0, -42.0, 4.0, 47.0, 82.0]:
			_build_buoy(Vector3(side * 47.0, -5.9, z))
	_build_coastal_fadeout(Vector3(-42.0, 8.0, 95.0), 1.0)
	_build_coastal_fadeout(Vector3(42.0, 8.0, -95.0), -1.0)


func _build_coastal_boat(position: Vector3, yaw: float) -> void:
	_add_box("CoastalBoatHull", Vector3(3.6, 0.72, 8.0), position, yaw, "boat")
	_add_box("CoastalBoatCabin", Vector3(2.1, 1.15, 2.5), position + Vector3(0.0, 0.82, -0.5), yaw, "boat_cabin")
	_add_box("CoastalBoatMast", Vector3(0.1, 3.2, 0.1), position + Vector3(0.0, 2.15, 1.2), yaw, "steel")


func _build_buoy(position: Vector3) -> void:
	_add_cylinder("CoastalBuoy", 0.36, 1.15, position + Vector3.UP * 0.45, "buoy")
	_add_sphere("CoastalBuoyCap", 0.42, position + Vector3.UP * 1.08, "buoy")


func _build_coastal_fadeout(position: Vector3, sign_x: float) -> void:
	for index in range(4):
		var offset := Vector3(sign_x * float(index) * 8.0, float(index % 2) * 1.4, float(index) * 5.0)
		_add_box("CoastalWarehouse", Vector3(12.0, 12.0 + float(index % 2) * 6.0, 16.0), position + offset, 0.0, "coastal_building")


func _build_crumbled_highway() -> void:
	# Distant support columns and broken road fragments sell the collapse without blocking the course.
	for side in [-1.0, 1.0]:
		for z in [-72.0, -36.0, 6.0, 48.0, 84.0]:
			_add_box("HighwaySupport", Vector3(2.4, 17.0, 2.4), Vector3(side * 14.5, -6.2, z), 0.0, "concrete")
			_add_box("BrokenHighwayStub", Vector3(8.0, 0.8, 11.0), Vector3(side * 19.0, 2.3 + float(int(abs(z)) % 3), z + 4.0), 0.18 * side, "asphalt")
	for index in range(8):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		_add_box("CollapsedBarrier", Vector3(0.38, 0.62, 5.4), Vector3(side * 9.7, 1.0, -73.0 + float(index) * 21.0), 0.32 * side, "warning")
	for index in range(6):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		_add_box("HighwayCityBlock", Vector3(13.0, 20.0 + float(index % 3) * 8.0, 18.0), Vector3(side * 35.0, 9.0, -70.0 + float(index) * 30.0), 0.0, "city_dark")


func _build_parking_garage_construction() -> void:
	_build_construction_crane()
	for level_y in [0.0, 10.5, 21.0, 31.5, 42.0]:
		_build_garage_level_frame(level_y)
	for position in [
		Vector3(-67.0, 18.0, -67.0), Vector3(67.0, 18.0, -67.0),
		Vector3(67.0, 18.0, 67.0), Vector3(-67.0, 18.0, 67.0),
	]:
		_add_box("GarageCornerPillar", Vector3(2.8, 38.0, 2.8), position, 0.0, "concrete")
		_add_box("GaragePillarBase", Vector3(5.0, 0.8, 5.0), position + Vector3(0.0, -18.6, 0.0), 0.0, "concrete_dark")


func _build_construction_crane() -> void:
	_add_box("ConstructionCraneTower", Vector3(2.0, 45.0, 2.0), Vector3(0.0, 22.0, 0.0), 0.0, "construction_steel")
	_add_box("ConstructionCraneBoom", Vector3(46.0, 0.7, 1.1), Vector3(20.0, 43.8, 0.0), 0.0, "construction_yellow")
	_add_box("ConstructionCraneCounterweight", Vector3(7.0, 2.5, 3.4), Vector3(-7.5, 42.8, 0.0), 0.0, "concrete_dark")
	_add_box("ConstructionCraneCable", Vector3(0.08, 15.0, 0.08), Vector3(36.0, 36.0, 0.0), 0.0, "steel")
	_add_box("ConstructionCraneHook", Vector3(0.5, 0.7, 0.5), Vector3(36.0, 28.2, 0.0), 0.0, "construction_yellow")


func _build_garage_level_frame(level_y: float) -> void:
	var outer: float = 67.0
	for side in [-1.0, 1.0]:
		_add_box("GarageEdgeBeam", Vector3(10.0, 0.55, 126.0), Vector3(side * outer, level_y + 0.7, 0.0), 0.0, "concrete")
		_add_box("GarageEdgeBeam", Vector3(126.0, 0.55, 10.0), Vector3(0.0, level_y + 0.7, side * outer), 0.0, "concrete")
	for index in range(4):
		var x: float = -54.0 + float(index) * 36.0
		_add_box("GarageTemporaryRail", Vector3(0.18, 1.15, 14.0), Vector3(x, level_y + 1.05, -61.5), 0.0, "construction_yellow")


func _add_dog(position: Vector3, yaw: float, shepherd: bool) -> void:
	var dog_scene: PackedScene = GERMAN_SHEPHERD_SCENE if shepherd else PUG_SCENE
	var dog: Node3D = dog_scene.instantiate() as Node3D
	if dog == null:
		return
	dog.name = "YardDog"
	dog.position = position
	dog.rotation.y = yaw
	dog.scale = Vector3.ONE * (0.9 if shepherd else 1.15)
	add_child(dog)


func _add_box(node_name: String, size: Vector3, position: Vector3, yaw: float, material_key: String) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = _get_box_mesh()
	mesh_instance.position = position
	mesh_instance.rotation.y = yaw
	mesh_instance.scale = size
	mesh_instance.material_override = _get_material(material_key)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


func _add_cylinder(node_name: String, radius: float, height: float, position: Vector3, material_key: String) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = _get_cylinder_mesh()
	mesh_instance.position = position
	mesh_instance.scale = Vector3(radius * 2.0, height, radius * 2.0)
	mesh_instance.material_override = _get_material(material_key)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


func _add_sphere(node_name: String, radius: float, position: Vector3, material_key: String) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = _get_sphere_mesh()
	mesh_instance.position = position
	mesh_instance.scale = Vector3.ONE * radius * 2.0
	mesh_instance.material_override = _get_material(material_key)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


static func _get_box_mesh() -> BoxMesh:
	if _box_mesh == null:
		_box_mesh = BoxMesh.new()
		_box_mesh.size = Vector3.ONE
	return _box_mesh


static func _get_cylinder_mesh() -> CylinderMesh:
	if _cylinder_mesh == null:
		_cylinder_mesh = CylinderMesh.new()
		_cylinder_mesh.top_radius = 0.5
		_cylinder_mesh.bottom_radius = 0.5
		_cylinder_mesh.height = 1.0
		_cylinder_mesh.radial_segments = 10
	return _cylinder_mesh


static func _get_sphere_mesh() -> SphereMesh:
	if _sphere_mesh == null:
		_sphere_mesh = SphereMesh.new()
		_sphere_mesh.radius = 0.5
		_sphere_mesh.height = 1.0
		_sphere_mesh.radial_segments = 10
		_sphere_mesh.rings = 6
	return _sphere_mesh


static func _get_material(key: String) -> StandardMaterial3D:
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = _get_material_color(key)
	material.roughness = 0.78
	material.metallic = 0.0
	if key in ["water", "window", "construction_yellow"]:
		material.emission_enabled = key != "water"
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 0.28 if key == "construction_yellow" else 0.5
	if key in ["steel", "construction_steel"]:
		material.metallic = 0.68
		material.roughness = 0.48
	_material_cache[key] = material
	return material


static func _get_material_color(key: String) -> Color:
	match key:
		"lawn": return Color("477a38")
		"suburban_blue": return Color("6b91a6")
		"suburban_cream": return Color("c6b78b")
		"suburban_red": return Color("9b5a4c")
		"roof": return Color("3e4048")
		"door": return Color("3a2820")
		"fence": return Color("ddd1b1")
		"mailbox": return Color("334a61")
		"water": return Color("1b5279")
		"boat": return Color("d9d5c9")
		"boat_cabin": return Color("c45442")
		"buoy": return Color("d3533d")
		"coastal_building": return Color("475661")
		"asphalt": return Color("25282b")
		"warning": return Color("d59a27")
		"city_dark": return Color("28323b")
		"concrete": return Color("7b807c")
		"concrete_dark": return Color("505652")
		"construction_steel": return Color("435258")
		"construction_yellow": return Color("d8a82a")
		"steel": return Color("39464b")
		_: return Color("777777")
