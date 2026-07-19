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
const FIRE_HYDRANT_SCENE := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/FireHydrant.gltf"
)
const TRASH_BAG_SCENE := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/TrashBag_1.gltf"
)
const PICKUP_SCENE := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Vehicles/Vehicle_Pickup.gltf"
)
const SPORTS_CAR_SCENE := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Vehicles/Vehicle_Sports.gltf"
)
const WATER_TOWER_SCENE := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/WaterTower.gltf"
)

@export var profile: Profile = Profile.SUBURBAN_OUTBREAK

static var _box_mesh: BoxMesh
static var _cylinder_mesh: CylinderMesh
static var _sphere_mesh: SphereMesh
static var _material_cache: Dictionary = {}


func _ready() -> void:
	if profile == Profile.SUBURBAN_OUTBREAK:
		_remove_legacy_city_highway_dressing()
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
	# A complete neighborhood. The race road, hazards, navigation, and finish
	# remain authoritative; City Highway deliberately leaves its suburban edge
	# open so runners can spill into the fenced yards.
	_add_box("SuburbanGround", Vector3(112.0, 0.12, 184.0), Vector3(0.0, -0.26, 0.0), 0.0, "suburban_ground")
	_build_suburban_public_street_extensions()
	for side in [-1.0, 1.0]:
		# Neighborhood cross-section, from the race lane outward:
		# raised curb, narrow grass verge, raised sidewalk, fenced yard.
		# The central race course continues as a public street at both map ends.
		# The curb deliberately touches the 16 m Zombie track at x = +/-8.
		_add_box("SuburbanCurb", Vector3(0.28, 0.18, 176.0), Vector3(side * 8.14, 0.12, 0.0), 0.0, "curb")
		_add_box("SuburbanGrassVerge", Vector3(2.0, 0.12, 176.0), Vector3(side * 9.28, -0.14, 0.0), 0.0, "lawn")
		_add_box("SuburbanSidewalk", Vector3(3.2, 0.12, 176.0), Vector3(side * 11.88, 0.15, 0.0), 0.0, "sidewalk")
		_build_suburban_street_lamps(side)

	var homes: Array[Dictionary] = [
		{"x": -23.5, "z": -68.0, "style": "cottage", "color": "suburban_blue"},
		{"x": 23.5, "z": -56.0, "style": "family", "color": "suburban_cream"},
		{"x": -23.5, "z": -39.0, "style": "two_story", "color": "suburban_red"},
		{"x": 23.5, "z": -26.0, "style": "ranch", "color": "suburban_green"},
		{"x": -23.5, "z": -9.0, "style": "family", "color": "suburban_cream"},
		{"x": 23.5, "z": 6.0, "style": "cottage", "color": "suburban_blue"},
		{"x": -23.5, "z": 23.0, "style": "ranch", "color": "suburban_red"},
		{"x": 23.5, "z": 38.0, "style": "two_story", "color": "suburban_cream"},
		{"x": -23.5, "z": 55.0, "style": "cottage", "color": "suburban_green"},
		{"x": 23.5, "z": 69.0, "style": "family", "color": "suburban_blue"},
	]
	for index in range(homes.size()):
		var home: Dictionary = homes[index]
		_build_suburban_lot(
			Vector3(float(home["x"]), 0.0, float(home["z"])),
			str(home["style"]),
			str(home["color"]),
			index
		)
	_build_suburban_perimeter_privacy_fences()
	_build_neighborhood_endcaps()


func _build_suburban_public_street_extensions() -> void:
	# RoadArena's gameplay road spans z = -44..44. Continue that asphalt all the
	# way to the neighborhood endcaps so the gates sit within a coherent street,
	# rather than directly in front of a grass gap. These meshes stay visual-only;
	# NeighborhoodWalkableGround remains the walk-collision authority off-track.
	for side in [-1.0, 1.0]:
		var extension_center_z: float = side * 66.0
		_add_box(
			"SuburbanStreetExtension",
			Vector3(16.0, 0.12, 44.0),
			Vector3(0.0, 0.0, extension_center_z),
			0.0,
			"asphalt"
		)
		_add_box(
			"SuburbanStreetCenterLine",
			Vector3(0.18, 0.04, 43.8),
			Vector3(0.0, 0.09, extension_center_z),
			0.0,
			"road_marking"
		)
		for edge_x in [-6.75, 6.75]:
			_add_box(
				"SuburbanStreetEdgeLine",
				Vector3(0.18, 0.05, 43.8),
				Vector3(edge_x, 0.10, extension_center_z),
				0.0,
				"road_marking"
			)


func _remove_legacy_city_highway_dressing() -> void:
	var arena: Node = get_parent()
	if arena == null:
		return
	var core_road: Node = arena.get_node_or_null("CoreRoad")
	if core_road == null:
		return
	# CityBackdrop owns the black towers, water tower, and industrial side props.
	# SetDressing owns the remaining old road-side visual package. Remove both
	# only for City Highway; neither node participates in course gameplay.
	for node_name in ["CityBackdrop", "SetDressing"]:
		var legacy_dressing: Node3D = core_road.get_node_or_null(node_name) as Node3D
		if legacy_dressing != null:
			legacy_dressing.visible = false
			legacy_dressing.queue_free()
	# City Highway is an open neighborhood map. Remove the legacy course rails
	# completely: yards and their picket fences provide the readable edge instead.
	for mesh_path in ["LeftRail/LeftRailMesh", "RightRail/RightRailMesh"]:
		var rail_mesh: MeshInstance3D = core_road.get_node_or_null(mesh_path) as MeshInstance3D
		if rail_mesh != null:
			rail_mesh.visible = false
	for collision_path in ["LeftRail/LeftRailCollision", "RightRail/RightRailCollision"]:
		var rail_collision: CollisionShape3D = core_road.get_node_or_null(collision_path) as CollisionShape3D
		if rail_collision != null:
			rail_collision.disabled = true


func _build_suburban_lot(position: Vector3, style: String, wall_material: String, index: int) -> void:
	var outward_sign: float = sign(position.x)
	var house_position := position + Vector3(outward_sign * 3.6, 0.0, 1.2)
	_add_box("SuburbanLot", Vector3(19.2, 0.14, 19.0), position, 0.0, "lawn")
	_add_box("SuburbanDriveway", Vector3(23.0, 0.1, 4.4), Vector3(outward_sign * 19.8, 0.215, position.z - 4.35), 0.0, "driveway")
	_build_suburban_house(house_position, outward_sign, style, wall_material)
	_build_fence_line(Vector3(outward_sign * 13.8, 0.0, position.z), 18.0, PI * 0.5, position.z - 4.35)
	_build_mailbox(Vector3(outward_sign * 13.45, 0.0, position.z - 7.1), 0.0)
	_build_tree(position + Vector3(outward_sign * 6.7, 0.0, 5.3), index)
	_build_hedge(position + Vector3(outward_sign * 8.0, 0.0, -6.6), outward_sign)
	_build_yard_detail(position, outward_sign, index)
	if index in [1, 4, 7]:
		_add_dog(position + Vector3(outward_sign * 5.5, 0.0, 4.1), -outward_sign * 0.4, index % 2 == 0)
	if index in [1, 3, 6, 9]:
		_add_suburban_vehicle(Vector3(outward_sign * 25.0, 0.0, position.z - 4.2), outward_sign, index)


func _build_suburban_house(position: Vector3, outward_sign: float, style: String, wall_material: String) -> void:
	var body_size := Vector3(8.0, 5.5, 7.2)
	var garage_size := Vector3(3.5, 3.1, 4.0)
	var roof_height := 6.0
	var house_name := "SuburbanHouseFamily"
	match style:
		"cottage":
			body_size = Vector3(6.7, 4.6, 6.4)
			garage_size = Vector3(0.0, 0.0, 0.0)
			roof_height = 5.05
			house_name = "SuburbanHouseCottage"
		"two_story":
			body_size = Vector3(7.8, 8.0, 7.0)
			garage_size = Vector3(3.25, 3.1, 4.0)
			roof_height = 8.55
			house_name = "SuburbanHouseTwoStory"
		"ranch":
			body_size = Vector3(10.3, 4.4, 7.4)
			garage_size = Vector3(4.3, 3.1, 4.0)
			roof_height = 4.9
			house_name = "SuburbanHouseRanch"
	_add_box(house_name, body_size, position + Vector3.UP * (body_size.y * 0.5 - 0.18), 0.0, wall_material)
	_add_box("SuburbanRoof", body_size + Vector3(0.85, 0.9, 0.85), position + Vector3.UP * roof_height, 0.0, "roof")
	var front := position - Vector3(outward_sign * (body_size.x * 0.5 + 0.08), 0.0, 0.0)
	_add_box("SuburbanPorch", Vector3(1.65, 0.3, 2.15), front + Vector3(0.0, 0.14, 1.5), 0.0, "concrete")
	_add_box("SuburbanDoor", Vector3(0.14, 2.0, 1.15), front + Vector3(0.0, 1.18, 1.5), 0.0, "door")
	for window_z in [-1.3, 3.0]:
		_add_box("SuburbanWindow", Vector3(0.12, 1.1, 1.28), front + Vector3(0.0, 3.1, window_z), 0.0, "window")
	if style == "two_story":
		for window_z in [-1.3, 3.0]:
			_add_box("SuburbanWindow", Vector3(0.12, 1.1, 1.28), front + Vector3(0.0, 5.85, window_z), 0.0, "window")
	if garage_size.x > 0.0:
		var garage_position := position + Vector3(0.0, garage_size.y * 0.5 - 0.18, -5.0)
		_add_box("SuburbanGarage", garage_size, garage_position, 0.0, wall_material)
		_add_box("SuburbanGarageRoof", garage_size + Vector3(0.45, 0.65, 0.5), garage_position + Vector3.UP * (garage_size.y * 0.5 + 0.3), 0.0, "roof")
		var garage_front := garage_position - Vector3(outward_sign * (garage_size.x * 0.5 + 0.08), 0.0, 0.0)
		_add_box("SuburbanGarageDoor", Vector3(0.14, 2.15, 2.5), garage_front + Vector3(0.0, 0.1, 0.0), 0.0, "garage_door")
	_add_box("SuburbanChimney", Vector3(0.7, 2.1, 0.7), position + Vector3(outward_sign * 2.25, roof_height + 0.8, -1.75), 0.0, "brick")


func _build_yard_detail(position: Vector3, outward_sign: float, index: int) -> void:
	_add_box("SuburbanPlanter", Vector3(1.3, 0.55, 1.3), position + Vector3(outward_sign * 6.3, 0.25, -0.8), 0.0, "planter")
	_add_sphere("SuburbanFlowerBush", 0.7, position + Vector3(outward_sign * 6.3, 0.75, -0.8), "flower")
	if index % 2 == 0:
		_add_box("SuburbanTrashBin", Vector3(0.65, 1.05, 0.72), position + Vector3(outward_sign * 8.1, 0.48, 6.1), 0.0, "trash_bin")
	else:
		_add_scene_prop("YardTrashBag", TRASH_BAG_SCENE, position + Vector3(outward_sign * 7.8, 0.0, 6.0), 0.15 * outward_sign, 0.95)
	if index in [0, 5, 8]:
		_add_scene_prop("SuburbanFireHydrant", FIRE_HYDRANT_SCENE, Vector3(outward_sign * 11.4, 0.0, position.z + 5.8), 0.0, 1.0)


func _add_suburban_vehicle(position: Vector3, outward_sign: float, index: int) -> void:
	var vehicle_scene: PackedScene = PICKUP_SCENE if index % 2 == 0 else SPORTS_CAR_SCENE
	_add_scene_prop("SuburbanParkedCar", vehicle_scene, position, 90.0 * outward_sign, 0.92)


func _build_neighborhood_endcaps() -> void:
	for side in [-1.0, 1.0]:
		var sign_position := Vector3(side * 17.0, 0.0, 86.0)
		_add_box("NeighborhoodEntryPost", Vector3(0.22, 2.4, 0.22), sign_position + Vector3.UP * 1.2, 0.0, "fence")
		_add_box("NeighborhoodEntrySign", Vector3(4.3, 0.95, 0.16), sign_position + Vector3(0.0, 2.0, 0.0), 0.0, "neighborhood_sign")
		_build_tree(Vector3(side * 45.0, 0.0, 80.0), int(side + 1.0))
	_add_scene_prop("SuburbanWaterTower", WATER_TOWER_SCENE, Vector3(-48.0, 0.0, -73.0), 12.0, 1.45)


func _build_fence_line(position: Vector3, width: float, yaw: float, gate_z: float) -> void:
	# With a 90 degree fence rotation, local +X maps to world -Z.
	var gate_local := position.z - gate_z
	var gate_half_width := 2.5
	for post_index in range(6):
		var offset: float = -width * 0.5 + float(post_index) * width * 0.2
		if absf(offset - gate_local) < gate_half_width:
			continue
		var local_offset := Vector3(offset, 0.0, 0.0).rotated(Vector3.UP, yaw)
		_add_box("FencePost", Vector3(0.18, 1.3, 0.18), position + local_offset + Vector3.UP * 0.58, yaw, "picket_wood")
	for rail_y in [0.38, 0.78]:
		_add_box("PicketFenceRail", Vector3(gate_local - gate_half_width + width * 0.5, 0.1, 0.12), position + Vector3((gate_local - gate_half_width - width * 0.5) * 0.5, rail_y, 0.0).rotated(Vector3.UP, yaw), yaw, "picket_wood")
		_add_box("PicketFenceRail", Vector3(width * 0.5 - gate_local - gate_half_width, 0.1, 0.12), position + Vector3((gate_local + gate_half_width + width * 0.5) * 0.5, rail_y, 0.0).rotated(Vector3.UP, yaw), yaw, "picket_wood")
	for picket_index in range(19):
		var picket_offset: float = -width * 0.5 + 0.45 + float(picket_index) * 0.95
		if absf(picket_offset - gate_local) < gate_half_width:
			continue
		var local_picket_offset := Vector3(picket_offset, 0.0, 0.0).rotated(Vector3.UP, yaw)
		_add_box("PicketFenceSlat", Vector3(0.1, 1.05, 0.2), position + local_picket_offset + Vector3.UP * 0.56, yaw, "picket_wood")


func _build_backyard_privacy_fence(position: Vector3, width: float, yaw: float) -> void:
	# One continuous neighborhood perimeter. It stays visual-only; City Highway's
	# definition begins lateral OOB immediately outside this property line.
	var panel_count := int(ceil(width / 3.5))
	var panel_width := width / float(panel_count)
	for post_index in range(panel_count + 1):
		if post_index % 4 != 0 and post_index != panel_count:
			continue
		var post_offset: float = -width * 0.5 + float(post_index) * panel_width
		var local_post := Vector3(post_offset, 0.0, 0.0).rotated(Vector3.UP, yaw)
		_add_box("BackyardPrivacyFencePost", Vector3(0.22, 2.75, 0.22), position + local_post + Vector3.UP * 1.2, yaw, "privacy_wood")
	for panel_index in range(panel_count):
		var panel_offset: float = -width * 0.5 + panel_width * 0.5 + float(panel_index) * panel_width
		var local_panel := Vector3(panel_offset, 0.0, 0.0).rotated(Vector3.UP, yaw)
		_add_box("BackyardPrivacyFence", Vector3(panel_width - 0.08, 2.35, 0.16), position + local_panel + Vector3.UP * 1.06, yaw, "privacy_wood")


func _build_suburban_perimeter_privacy_fences() -> void:
	for side in [-1.0, 1.0]:
		_build_backyard_privacy_fence(Vector3(side * 33.25, 0.0, 0.0), 176.0, PI * 0.5)


func _build_mailbox(position: Vector3, yaw: float) -> void:
	_add_box("MailboxPost", Vector3(0.12, 0.95, 0.12), position + Vector3(0.0, 0.45, 0.0), yaw, "mailbox")
	_add_box("Mailbox", Vector3(0.58, 0.36, 0.44), position + Vector3(0.0, 0.93, 0.0), yaw, "mailbox")


func _build_tree(position: Vector3, index: int) -> void:
	_add_cylinder("SuburbanTreeTrunk", 0.32, 3.6, position + Vector3.UP * 1.8, "tree_trunk")
	var canopy_material: String = "tree_light" if index % 2 == 0 else "tree_dark"
	_add_sphere("SuburbanTreeCanopy", 2.1, position + Vector3.UP * 4.0, canopy_material)
	_add_sphere("SuburbanTreeCanopy", 1.55, position + Vector3(1.15, 4.75, 0.35), canopy_material)


func _build_hedge(position: Vector3, side: float) -> void:
	_add_box("SuburbanHedge", Vector3(3.8, 1.05, 0.72), position + Vector3(0.0, 0.5, 0.0), 0.0, "hedge")
	_add_box("SuburbanHedge", Vector3(0.72, 1.05, 4.0), position + Vector3(side * 1.55, 0.5, 1.65), 0.0, "hedge")


func _build_suburban_street_lamps(side: float) -> void:
	for z in [-63.0, -19.0, 25.0, 67.0]:
		var position := Vector3(side * 9.4, 0.0, z)
		_add_box("SuburbanStreetLampPost", Vector3(0.16, 5.4, 0.16), position + Vector3.UP * 2.7, 0.0, "street_lamp")
		_add_box("SuburbanStreetLampArm", Vector3(1.25, 0.12, 0.12), position + Vector3(-side * 0.58, 5.1, 0.0), 0.0, "street_lamp")
		_add_box("SuburbanStreetLampHead", Vector3(0.48, 0.2, 0.34), position + Vector3(-side * 1.14, 5.0, 0.0), 0.0, "lamp_glow")


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


func _add_scene_prop(node_name: String, scene: PackedScene, position: Vector3, yaw_degrees: float, scale_factor: float) -> void:
	var prop: Node3D = scene.instantiate() as Node3D
	if prop == null:
		return
	prop.name = node_name
	prop.position = position
	prop.rotation_degrees.y = yaw_degrees
	prop.scale = Vector3.ONE * scale_factor
	add_child(prop)


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
	if key in ["water", "window", "lamp_glow", "construction_yellow"]:
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
		"suburban_ground": return Color("5f7d46")
		"sidewalk": return Color("b8b4aa")
		"curb": return Color("8f948c")
		"suburban_blue": return Color("6b91a6")
		"suburban_cream": return Color("c6b78b")
		"suburban_red": return Color("9b5a4c")
		"suburban_green": return Color("7a9b71")
		"roof": return Color("3e4048")
		"door": return Color("3a2820")
		"window": return Color("a4d7e7")
		"brick": return Color("8b483b")
		"fence": return Color("ddd1b1")
		"picket_wood": return Color("e6d3ad")
		"privacy_wood": return Color("765037")
		"mailbox": return Color("334a61")
		"driveway": return Color("6d6e6c")
		"road_marking": return Color("e5dca9")
		"garage_door": return Color("b9bfc0")
		"planter": return Color("ae7259")
		"flower": return Color("d56d88")
		"trash_bin": return Color("445b4c")
		"neighborhood_sign": return Color("5a7546")
		"hedge": return Color("35613a")
		"tree_trunk": return Color("69472d")
		"tree_light": return Color("4c813c")
		"tree_dark": return Color("2d5d38")
		"street_lamp": return Color("3f4749")
		"lamp_glow": return Color("ffe5a3")
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
