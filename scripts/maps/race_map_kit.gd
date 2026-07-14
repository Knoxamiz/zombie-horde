class_name RaceMapKit
extends RefCounted

enum StreetVariant { STRAIGHT, CRACK1, CRACK2 }
enum MapStyle { LONG_ROAD, BROKEN_BRIDGE }

const TILE_SIZE: float = 8.0
const TILE_HALF: float = TILE_SIZE * 0.5

const SCENE_STREET_STRAIGHT := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Street_Straight.gltf"
)
const SCENE_STREET_CRACK1 := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Street_Straight_Crack1.gltf"
)
const SCENE_STREET_CRACK2 := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Street_Straight_Crack2.gltf"
)
const SCENE_PLASTIC_BARRIER := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/PlasticBarrier.gltf"
)
const SCENE_TRAFFIC_BARRIER_1 := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/TrafficBarrier_1.gltf"
)
const SCENE_TRAFFIC_BARRIER_2 := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/TrafficBarrier_2.gltf"
)
const SCENE_TRAFFIC_CONE_1 := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/TrafficCone_1.gltf"
)
const SCENE_STREET_LIGHT := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/StreetLights.gltf"
)
const SCENE_PALLET_BROKEN := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Pallet_Broken.gltf"
)
const SCENE_PIPES := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Pipes.gltf"
)
const SCENE_CINDER_BLOCK := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/CinderBlock.gltf"
)
const SCENE_CONTAINER_RED := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Container_Red.gltf"
)
const SCENE_CONTAINER_GREEN := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Container_Green.gltf"
)

const MAT_SPAWN := preload("res://assets/materials/spawn_zone.tres")
const MAT_GOAL := preload("res://assets/materials/goal_zone.tres")
const MAT_CONCRETE := preload("res://assets/materials/base_concrete.tres")
const MAT_ARENA_GROUND := preload("res://assets/materials/arena_ground.tres")
const MAT_ROAD_ASPHALT := preload("res://assets/materials/road_asphalt.tres")
const MAT_ROAD_LINE := preload("res://assets/materials/road_line.tres")
const MAT_ROAD_SCUFF := preload("res://assets/materials/road_mark_scuff.tres")
const MAT_ROAD_SCORCH := preload("res://assets/materials/road_mark_scorch.tres")
const MAT_CITY_DARK := preload("res://assets/materials/city_building_dark.tres")
const MAT_CITY_MID := preload("res://assets/materials/city_building_mid.tres")
const MAT_CITY_WINDOW := preload("res://assets/materials/city_window_glow.tres")
const SURFACE_BUILDER := preload("res://scripts/maps/kit_map_surface_builder.gd")

var _root: Node3D
var _collision_root: Node3D
var _visual_root: Node3D
var _boundary_root: Node3D
var _style: MapStyle = MapStyle.LONG_ROAD
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _elevation_zones: Array[Dictionary] = []
var _path_half_width: float = 6.0
var _gap_crossing_width_ratio: float = SURFACE_BUILDER.DEFAULT_GAP_CROSSING_WIDTH_RATIO
var _water_y: float = -6.0
var _void_bed_y: float = NAN


func attach(root: Node3D, style: MapStyle, random_seed: int) -> void:
	_root = root
	_style = style
	_rng.seed = random_seed
	_collision_root = _make_child("Collision", root)
	_visual_root = _make_child("VisualKit", root)
	_boundary_root = _make_child("GameplayBoundaries", root)


func set_elevation_zones(zones: Array) -> void:
	_elevation_zones.clear()
	for zone in zones:
		if zone is Dictionary:
			_elevation_zones.append(zone)


func _surface_y_at(z: float) -> float:
	if _elevation_zones.is_empty():
		return 0.0
	for zone in _elevation_zones:
		var z0: float = float(zone.get("z0", 0.0))
		var z1: float = float(zone.get("z1", z0))
		if z < z0 or z > z1:
			continue
		if bool(zone.get("is_ramp", false)):
			var start_y: float = float(zone.get("start_y", 0.0))
			var end_y: float = float(zone.get("end_y", start_y))
			var t: float = 0.0 if z1 <= z0 else (z - z0) / (z1 - z0)
			return lerpf(start_y, end_y, t)
		return float(zone.get("y", 0.0))
	return 0.0


func set_path_half_width(half_width: float) -> void:
	_path_half_width = maxf(half_width, 1.0)


func set_gap_crossing_width_ratio(ratio: float) -> void:
	_gap_crossing_width_ratio = clampf(ratio, 0.25, 0.75)


func set_water_y(y: float) -> void:
	_water_y = y


func set_void_bed_y(y: float) -> void:
	_void_bed_y = y


func build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	sun.light_color = Color(0.64, 0.7, 0.82, 1.0)
	sun.light_energy = 0.48
	sun.shadow_enabled = true
	_root.add_child(sun)

	_add_omni("StartPoolLight", Vector3(0.0, 5.2, -76.0), Color(0.52, 1.0, 0.35, 1.0), 2.25, 36.0)
	_add_omni("FinishPoolLight", Vector3(0.0, 5.2, 76.0), Color(1.0, 0.32, 0.12, 1.0), 2.0, 36.0)
	_add_omni("RoadAmberLightA", Vector3(-14.0, 4.4, -20.0), Color(1.0, 0.64, 0.18, 1.0), 1.45, 24.0)
	_add_omni("RoadAmberLightB", Vector3(14.0, 4.4, 36.0), Color(1.0, 0.64, 0.18, 1.0), 1.35, 24.0)


func _reposition_environment_lights(spawn_z: float, goal_z: float) -> void:
	if _root == null:
		return
	var spawn_light_y: float = _surface_y_at(spawn_z) + 4.8
	var goal_light_y: float = _surface_y_at(goal_z) + 4.8
	for child in _root.get_children():
		match child.name:
			"StartPoolLight":
				child.position = Vector3(0.0, spawn_light_y, spawn_z + 4.0)
			"FinishPoolLight":
				child.position = Vector3(0.0, goal_light_y, goal_z - 4.0)
			"RoadAmberLightA":
				child.position.y = _surface_y_at(-20.0) + 3.8
			"RoadAmberLightB":
				child.position.y = _surface_y_at(36.0) + 3.8


func build_route_context(
	spawn_z: float,
	goal_z: float,
	start_gate_z: float,
	path_half_width: float,
	segments: Array[Dictionary],
	gaps: Array[Dictionary],
	void_width: float,
	track_length: float,
	surface_pieces: Array = [],
	gap_crossing_width_ratio: float = SURFACE_BUILDER.DEFAULT_GAP_CROSSING_WIDTH_RATIO,
	spawn_chute_half_width: float = -1.0
) -> void:
	var edge_x: float = 5.4 if _style == MapStyle.BROKEN_BRIDGE else 10.5
	var barrier_spacing: float = 5.0 if _style == MapStyle.BROKEN_BRIDGE else 6.5
	var lowest_y: float = _lowest_surface_y(surface_pieces)
	var bed_y: float
	if not is_nan(_void_bed_y):
		bed_y = _void_bed_y
	elif _style == MapStyle.BROKEN_BRIDGE and _water_y > -4.0:
		bed_y = _water_y - 2.75
	else:
		bed_y = lowest_y - 1.35
		if lowest_y <= 0.5:
			bed_y = minf(bed_y, -1.2)
	var chute_half_width: float = (
		spawn_chute_half_width if spawn_chute_half_width > 0.0 else path_half_width + 0.85
	)

	build_ground_bed(void_width, track_length, bed_y)
	if _style == MapStyle.BROKEN_BRIDGE:
		build_spawn_lane_bumpers(spawn_z, start_gate_z, chute_half_width)
	build_route_shoulders(spawn_z, goal_z, path_half_width, 3.2, bed_y + 0.08, gaps)
	build_continuous_guardrails(spawn_z, goal_z, edge_x, barrier_spacing)
	build_gap_guardrails(gaps, edge_x)
	if not gaps.is_empty() and _style == MapStyle.BROKEN_BRIDGE:
		build_gap_crossing_visuals(gaps, surface_pieces, path_half_width, gap_crossing_width_ratio)
		build_gap_void_visuals(gaps, path_half_width, surface_pieces, bed_y)
		build_gap_drop_walls(gaps, path_half_width, surface_pieces)
		build_gap_deck_lip_visuals(gaps, path_half_width, surface_pieces)
		build_gap_edge_shoulder_visuals(gaps, path_half_width, surface_pieces, bed_y + 0.08)
		build_deck_underside_visuals(surface_pieces, path_half_width * 2.0)
	if not gaps.is_empty():
		build_gap_support_piers(gaps, path_half_width, bed_y, surface_pieces)
	if not surface_pieces.is_empty():
		build_elevated_deck_supports(surface_pieces, path_half_width * 2.0, bed_y)
	_build_stage_atmosphere_context(void_width, track_length, bed_y)
	_reposition_environment_lights(spawn_z, goal_z)


func build_gap_crossing_visuals(
	gaps: Array[Dictionary],
	surface_pieces: Array,
	path_half_width: float,
	width_ratio: float = SURFACE_BUILDER.DEFAULT_GAP_CROSSING_WIDTH_RATIO
) -> void:
	var crossing_half_width: float = SURFACE_BUILDER.gap_crossing_half_width(path_half_width, width_ratio)
	for gap_index in range(gaps.size()):
		var gap: Dictionary = gaps[gap_index]
		var z0: float = float(gap["z0"])
		var z1: float = float(gap["z1"])
		var length: float = z1 - z0
		var center_z: float = (z0 + z1) * 0.5
		var top_y: float = SURFACE_BUILDER.get_gap_crossing_top_y(surface_pieces, z0, z1, _surface_y_at(center_z))
		var plank := MeshInstance3D.new()
		plank.name = "GapCrossingPlank_%d" % gap_index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(crossing_half_width * 2.0, 0.16, length * 0.92)
		plank.mesh = mesh
		plank.material_override = MAT_CONCRETE
		plank.position = Vector3(0.0, top_y - 0.04, center_z)
		_visual_root.add_child(plank)


func build_gap_void_visuals(
	gaps: Array[Dictionary],
	path_half_width: float,
	surface_pieces: Array,
	bed_y: float = -2.2
) -> void:
	if _style == MapStyle.BROKEN_BRIDGE and _water_y > -4.0:
		_build_elevated_gap_water_views(gaps, path_half_width, surface_pieces)
		return

	## Side chasm pits only — keep the narrow crossing lane visually open.
	var void_color := Color(0.04, 0.06, 0.09, 1.0)
	var crossing_half_width: float = SURFACE_BUILDER.gap_crossing_half_width(
		path_half_width, _gap_crossing_width_ratio
	)
	var side_span: float = maxf(path_half_width - crossing_half_width, 0.45)
	for gap_index in range(gaps.size()):
		var gap: Dictionary = gaps[gap_index]
		var z0: float = float(gap["z0"])
		var z1: float = float(gap["z1"])
		var length: float = z1 - z0
		var center_z: float = (z0 + z1) * 0.5
		var lip_y: float = SURFACE_BUILDER.get_gap_crossing_top_y(surface_pieces, z0, z1, _surface_y_at(center_z))
		var pit_depth: float = maxf(lip_y - bed_y + 1.2, 1.6)
		for side in [-1.0, 1.0]:
			var pit := MeshInstance3D.new()
			pit.name = "GapVoidSide_%d_%s" % [gap_index, "L" if side < 0.0 else "R"]
			var mesh := BoxMesh.new()
			mesh.size = Vector3(side_span * 2.0, pit_depth, length * 0.96)
			pit.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = void_color
			mat.roughness = 0.95
			pit.material_override = mat
			var x: float = side * (crossing_half_width + side_span)
			pit.position = Vector3(x, lip_y - pit_depth * 0.5 - 1.05, center_z)
			_visual_root.add_child(pit)


func _build_elevated_gap_water_views(
	gaps: Array[Dictionary],
	path_half_width: float,
	surface_pieces: Array
) -> void:
	## Open elevated gaps — water stays visible; no dark pits that hide vertical drop.
	var crossing_half_width: float = SURFACE_BUILDER.gap_crossing_half_width(
		path_half_width, _gap_crossing_width_ratio
	)
	var water_y: float = _water_y
	for gap_index in range(gaps.size()):
		var gap: Dictionary = gaps[gap_index]
		var z0: float = float(gap["z0"])
		var z1: float = float(gap["z1"])
		var length: float = z1 - z0
		var center_z: float = (z0 + z1) * 0.5
		var lip_y: float = SURFACE_BUILDER.get_gap_crossing_top_y(
			surface_pieces, z0, z1, _surface_y_at(center_z)
		)
		var drop_height: float = maxf(lip_y - water_y, 1.0)
		var side_span: float = maxf(path_half_width - crossing_half_width, 0.45)
		for side in [-1.0, 1.0]:
			var x: float = side * (crossing_half_width + side_span * 0.5)
			var basin := MeshInstance3D.new()
			basin.name = "GapWaterBasin_%d_%s" % [gap_index, "L" if side < 0.0 else "R"]
			var mesh := BoxMesh.new()
			mesh.size = Vector3(side_span * 2.0, 0.08, length * 0.94)
			basin.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.05, 0.24, 0.46, 0.92)
			mat.emission_enabled = true
			mat.emission = Color(0.03, 0.12, 0.24, 1.0)
			mat.emission_energy_multiplier = 0.55
			basin.material_override = mat
			basin.position = Vector3(x, water_y + 0.02, center_z)
			_visual_root.add_child(basin)

			var wall := MeshInstance3D.new()
			wall.name = "GapSideWall_%d_%s" % [gap_index, "L" if side < 0.0 else "R"]
			var wall_mesh := BoxMesh.new()
			wall_mesh.size = Vector3(0.28, drop_height, length * 0.96)
			wall.mesh = wall_mesh
			wall.material_override = MAT_CONCRETE
			var inner_x: float = side * crossing_half_width
			wall.position = Vector3(inner_x + side * 0.14, water_y + drop_height * 0.5, center_z)
			_visual_root.add_child(wall)


func build_gap_drop_walls(
	gaps: Array[Dictionary],
	path_half_width: float,
	surface_pieces: Array
) -> void:
	if _style != MapStyle.BROKEN_BRIDGE or _water_y <= -4.0:
		return
	var road_width: float = path_half_width * 2.0
	var water_y: float = _water_y
	for gap_index in range(gaps.size()):
		var gap: Dictionary = gaps[gap_index]
		var z0: float = float(gap["z0"])
		var z1: float = float(gap["z1"])
		var center_z: float = (z0 + z1) * 0.5
		var lip_y: float = SURFACE_BUILDER.get_gap_crossing_top_y(
			surface_pieces, z0, z1, _surface_y_at(center_z)
		)
		var drop_height: float = maxf(lip_y - water_y, 1.0)
		for edge_z in [z0, z1]:
			var wall := MeshInstance3D.new()
			wall.name = "GapDropWall_%d_%s" % [gap_index, "entry" if edge_z <= z0 else "exit"]
			var mesh := BoxMesh.new()
			mesh.size = Vector3(road_width, drop_height, 0.42)
			wall.mesh = mesh
			wall.material_override = MAT_CONCRETE
			wall.position = Vector3(0.0, water_y + drop_height * 0.5, edge_z)
			_visual_root.add_child(wall)


func build_deck_underside_visuals(surface_pieces: Array, road_width: float) -> void:
	if _style != MapStyle.BROKEN_BRIDGE or _water_y <= -4.0:
		return
	var thickness: float = 0.55
	for raw_spec in surface_pieces:
		if raw_spec is not Dictionary:
			continue
		var spec: Dictionary = raw_spec
		if str(spec.get("shape", "deck")) != "deck":
			continue
		var z0: float = float(spec.get("z0", 0.0))
		var z1: float = float(spec.get("z1", z0))
		if z1 <= z0:
			continue
		var top_y: float = float(spec.get("top_y", 0.0))
		var length: float = z1 - z0
		var center_z: float = (z0 + z1) * 0.5
		var width: float = float(spec.get("width", road_width))
		var underside := MeshInstance3D.new()
		underside.name = "DeckUnderside"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, thickness, length * 0.98)
		underside.mesh = mesh
		underside.material_override = MAT_CONCRETE
		underside.position = Vector3(0.0, top_y - thickness * 0.5 - 0.06, center_z)
		_visual_root.add_child(underside)


func build_gap_deck_lip_visuals(
	gaps: Array[Dictionary],
	path_half_width: float,
	surface_pieces: Array
) -> void:
	## Full-width cracked deck caps at each gap boundary — visual only, no walk collision.
	var road_width: float = path_half_width * 2.0
	var lip_depth: float = 0.14
	for gap_index in range(gaps.size()):
		var gap: Dictionary = gaps[gap_index]
		var z0: float = float(gap["z0"])
		var z1: float = float(gap["z1"])
		for edge_z in [z0 - TILE_HALF, z1 + TILE_HALF]:
			var lip_y: float = SURFACE_BUILDER.get_gap_crossing_top_y(
				surface_pieces, z0, z1, _surface_y_at(edge_z)
			)
			var lip := MeshInstance3D.new()
			lip.name = "GapDeckLip_%d_%s" % [gap_index, "entry" if edge_z < z0 else "exit"]
			var mesh := BoxMesh.new()
			mesh.size = Vector3(road_width, lip_depth, TILE_SIZE * 0.92)
			lip.mesh = mesh
			lip.material_override = MAT_CONCRETE
			lip.position = Vector3(0.0, lip_y - lip_depth * 0.5 + 0.02, edge_z)
			_visual_root.add_child(lip)


func build_gap_edge_shoulder_visuals(
	gaps: Array[Dictionary],
	path_half_width: float,
	surface_pieces: Array,
	shoulder_y: float
) -> void:
	## Grey shoulder strips at gap entry/exit only — fills missing slabs without bridging the void.
	var shoulder_width: float = 3.2
	var strip_length: float = TILE_SIZE * 0.9
	for gap in gaps:
		var z0: float = float(gap["z0"])
		var z1: float = float(gap["z1"])
		var lip_y: float = SURFACE_BUILDER.get_gap_crossing_top_y(
			surface_pieces, z0, z1, _surface_y_at((z0 + z1) * 0.5)
		)
		for edge_z in [z0 - TILE_HALF * 0.5, z1 + TILE_HALF * 0.5]:
			var surface_y: float = maxf(shoulder_y, maxf(lip_y, _surface_y_at(edge_z)) - 0.18)
			for side in [-1.0, 1.0]:
				var shoulder := MeshInstance3D.new()
				shoulder.name = "GapEdgeShoulder_%d_%s" % [int(edge_z * 10.0), "L" if side < 0.0 else "R"]
				var mesh := BoxMesh.new()
				mesh.size = Vector3(shoulder_width, 0.1, strip_length)
				shoulder.mesh = mesh
				shoulder.material_override = MAT_ARENA_GROUND
				var x: float = side * (path_half_width + shoulder_width * 0.5 + 0.35)
				shoulder.position = Vector3(x, surface_y, edge_z)
				_visual_root.add_child(shoulder)


func build_ground_bed(width: float, length: float, y: float = -1.35) -> void:
	var bed := MeshInstance3D.new()
	bed.name = "GroundBed"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width + 20.0, 0.22, length + 24.0)
	bed.mesh = mesh
	bed.position = Vector3(0.0, y, 0.0)
	bed.material_override = MAT_ARENA_GROUND
	_root.add_child(bed)


func build_route_shoulders(
	z_start: float,
	z_end: float,
	road_half_width: float,
	shoulder_width: float,
	shoulder_y: float,
	gaps: Array[Dictionary] = []
) -> void:
	var strip_length: float = 6.0
	var z: float = z_start
	while z < z_end:
		var center_z: float = min(z + strip_length * 0.5, z_end - strip_length * 0.5)
		if not _z_in_gap_ranges(center_z, gaps):
			var surface_y: float = _surface_y_at(center_z)
			var y: float = max(shoulder_y, surface_y - 0.18)
			for side in [-1.0, 1.0]:
				var shoulder := MeshInstance3D.new()
				shoulder.name = "RouteShoulder_%d_%s" % [int(center_z * 10.0), "L" if side < 0.0 else "R"]
				var mesh := BoxMesh.new()
				mesh.size = Vector3(shoulder_width, 0.1, strip_length)
				shoulder.mesh = mesh
				shoulder.material_override = MAT_ARENA_GROUND
				var x: float = side * (road_half_width + shoulder_width * 0.5 + 0.35)
				shoulder.position = Vector3(x, y, center_z)
				_visual_root.add_child(shoulder)
		z += strip_length


func build_spawn_lane_bumpers(spawn_z: float, start_gate_z: float, chute_half_width: float) -> void:
	if _boundary_root == null:
		return

	var z_back: float = spawn_z - 4.0
	var z_front: float = start_gate_z + 10.0
	var run_length: float = maxf(z_front - z_back, 4.0)
	var center_z: float = (z_back + z_front) * 0.5
	var deck_y: float = _surface_y_at(spawn_z)
	var wall_height: float = 2.75
	var wall_thickness: float = 0.6
	var wall_y: float = deck_y + wall_height * 0.5 - 0.08

	for side in [-1.0, 1.0]:
		var wall_x: float = side * (chute_half_width + wall_thickness * 0.5)
		_add_boundary_wall(
			"SpawnBumperSide",
			Vector3(wall_thickness, wall_height, run_length),
			Vector3(wall_x, wall_y, center_z)
		)
		var prop_z: float = z_back + 1.5
		while prop_z < z_front - 1.0:
			_place_prop(
				SCENE_PLASTIC_BARRIER,
				Vector3(wall_x, deck_y, prop_z),
				1.45,
				90.0 if side < 0.0 else -90.0
			)
			prop_z += 3.25

	_add_boundary_wall(
		"SpawnBumperBack",
		Vector3(chute_half_width * 2.0 + wall_thickness * 2.0, wall_height, wall_thickness),
		Vector3(0.0, wall_y, z_back - wall_thickness * 0.5)
	)
	for back_x in [-chute_half_width * 0.55, 0.0, chute_half_width * 0.55]:
		_place_prop(SCENE_TRAFFIC_BARRIER_1, Vector3(back_x, deck_y, z_back - 0.4), 1.35, 0.0)


func _z_in_gap_ranges(z: float, gaps: Array[Dictionary]) -> bool:
	for gap in gaps:
		var z0: float = float(gap.get("z0", 0.0))
		var z1: float = float(gap.get("z1", z0))
		if z >= z0 - 0.05 and z <= z1 + 0.05:
			return true
	return false


func build_continuous_guardrails(
	z_start: float,
	z_end: float,
	edge_x: float,
	spacing: float
) -> void:
	var z: float = z_start + 2.0
	while z < z_end - 1.5:
		_place_traffic_barrier(z, -edge_x, false)
		_place_traffic_barrier(z + spacing * 0.45, edge_x, true)
		if _hashf(int(z * 10.0), 57) > 0.55:
			_place_plastic_barrier(z + 1.2, -edge_x - 0.55)
		z += spacing + _hashf(int(z), 3) * 1.5


func build_gap_guardrails(gaps: Array[Dictionary], edge_x: float) -> void:
	for gap in gaps:
		var z0: float = float(gap["z0"])
		var z1: float = float(gap["z1"])
		var gap_center: float = (z0 + z1) * 0.5
		for edge_z in [z0 + 0.35, z1 - 0.35]:
			_place_traffic_barrier(edge_z, -edge_x, false)
			_place_traffic_barrier(edge_z, edge_x, true)
			_place_cone(edge_z, -edge_x * 0.42)
			_place_cone(edge_z, edge_x * 0.42)
		_place_plastic_barrier(gap_center, -edge_x - 0.4)
		_place_plastic_barrier(gap_center, edge_x + 0.4)


func build_gap_support_piers(
	gaps: Array[Dictionary],
	path_half_width: float,
	bed_y: float,
	surface_pieces: Array
) -> void:
	for gap_index in range(gaps.size()):
		var gap: Dictionary = gaps[gap_index]
		var z0: float = float(gap["z0"])
		var z1: float = float(gap["z1"])
		var gap_center: float = (z0 + z1) * 0.5
		var deck_y: float = SURFACE_BUILDER.get_gap_crossing_top_y(surface_pieces, z0, z1, _surface_y_at(gap_center))
		var pier_base_y: float = _water_y if (_water_y > -4.0) else bed_y
		var pier_height: float = maxf(deck_y - pier_base_y - 0.25, 1.0)
		var pier_center_y: float = pier_base_y + pier_height * 0.5
		var pier_size: float = 1.35 if _water_y > -4.0 else 0.85
		for pier_z in [z0 + 0.5, gap_center, z1 - 0.5]:
			for side in [-1.0, 1.0]:
				var pier := MeshInstance3D.new()
				pier.name = "GapPier"
				var mesh := BoxMesh.new()
				mesh.size = Vector3(pier_size, pier_height, pier_size)
				pier.mesh = mesh
				pier.material_override = MAT_CONCRETE
				pier.position = Vector3(side * (path_half_width + 0.9), pier_center_y, pier_z)
				_visual_root.add_child(pier)


func build_elevated_deck_supports(
	surface_pieces: Array,
	road_width: float,
	bed_y: float
) -> void:
	for raw_spec in surface_pieces:
		if raw_spec is not Dictionary:
			continue
		var spec: Dictionary = raw_spec
		if str(spec.get("shape", "deck")) != "deck":
			continue
		var top_y: float = float(spec.get("top_y", 0.0))
		if top_y < 0.25:
			continue
		var z0: float = float(spec.get("z0", 0.0))
		var z1: float = float(spec.get("z1", z0))
		var center_z: float = (z0 + z1) * 0.5
		var length: float = z1 - z0
		var strut_height: float = maxf(top_y - (_water_y if _water_y > -4.0 else bed_y) - 0.2, 0.6)
		var strut_y: float = (_water_y if _water_y > -4.0 else bed_y) + strut_height * 0.5
		var edge_x: float = road_width * 0.5 + 0.55
		var strut_width: float = 0.75 if _water_y > -4.0 else 0.55
		for side in [-1.0, 1.0]:
			var strut := MeshInstance3D.new()
			strut.name = "DeckSupport"
			var mesh := BoxMesh.new()
			mesh.size = Vector3(strut_width, strut_height, minf(length * 0.85, 18.0))
			strut.mesh = mesh
			strut.material_override = MAT_CONCRETE
			strut.position = Vector3(side * edge_x, strut_y, center_z)
			_visual_root.add_child(strut)


func _lowest_surface_y(surface_pieces: Array) -> float:
	if surface_pieces.is_empty():
		return 0.0
	return SURFACE_BUILDER.get_lowest_top_y(surface_pieces, 0.0)


func build_water(width: float, length: float, y: float = -6.0) -> void:
	_water_y = y
	var water := MeshInstance3D.new()
	water.name = "Water"
	var mesh := BoxMesh.new()
	var is_bridge_water: bool = _style == MapStyle.BROKEN_BRIDGE and y > -4.0
	mesh.size = Vector3(width + 16.0, 0.35 if is_bridge_water else 0.06, length + 16.0)
	water.mesh = mesh
	water.position = Vector3(0.0, y - (0.12 if is_bridge_water else 0.0), 0.0)
	var water_mat := StandardMaterial3D.new()
	if is_bridge_water:
		water_mat.albedo_color = Color(0.06, 0.28, 0.52, 0.94)
		water_mat.emission_enabled = true
		water_mat.emission = Color(0.04, 0.16, 0.32, 1.0)
		water_mat.emission_energy_multiplier = 0.85
		water_mat.metallic = 0.15
		water_mat.roughness = 0.12
	else:
		water_mat.albedo_color = Color(0.02, 0.06, 0.1, 0.95)
		water_mat.metallic = 0.3
		water_mat.roughness = 0.2
		water_mat.emission_enabled = true
		water_mat.emission = Color(0.02, 0.07, 0.12, 1.0)
		water_mat.emission_energy_multiplier = 0.28
	water.material_override = water_mat
	_root.add_child(water)
	_build_stage_atmosphere_context(width, length, y)

	if is_bridge_water:
		var deep := MeshInstance3D.new()
		deep.name = "WaterDeep"
		var deep_mesh := BoxMesh.new()
		deep_mesh.size = Vector3(width + 20.0, 1.2, length + 20.0)
		deep.mesh = deep_mesh
		deep.position = Vector3(0.0, y - 1.35, 0.0)
		var deep_mat := StandardMaterial3D.new()
		deep_mat.albedo_color = Color(0.01, 0.05, 0.12, 1.0)
		deep_mat.emission_enabled = true
		deep_mat.emission = Color(0.01, 0.04, 0.1, 1.0)
		deep_mat.emission_energy_multiplier = 0.35
		deep.material_override = deep_mat
		_root.add_child(deep)
		_build_bridge_river_city_context(width, length, y)


func _build_bridge_river_city_context(width: float, length: float, water_y: float) -> void:
	if _visual_root == null:
		return
	var context_root := Node3D.new()
	context_root.name = "BridgeRiverCityContext"
	_visual_root.add_child(context_root)

	var water_edge_x: float = (width + 16.0) * 0.5
	var bank_x: float = water_edge_x + 11.0
	var bank_y: float = water_y + 0.16
	for side in [-1.0, 1.0]:
		var signed_bank_x: float = side * bank_x
		_add_bridge_box(
			context_root,
			"RiverBank",
			Vector3(20.0, 0.24, length + 30.0),
			Vector3(signed_bank_x, bank_y, 0.0),
			MAT_ARENA_GROUND
		)
		_add_bridge_box(
			context_root,
			"QuayWall",
			Vector3(0.72, 3.2, length + 24.0),
			Vector3(side * (water_edge_x + 0.36), water_y + 1.45, 0.0),
			MAT_CONCRETE
		)
		_add_bridge_box(
			context_root,
			"BankRoadStrip",
			Vector3(10.5, 0.08, length + 12.0),
			Vector3(signed_bank_x + side * 1.25, bank_y + 0.14, 0.0),
			MAT_ROAD_ASPHALT
		)
		_place_bridge_skyline_side(context_root, side, bank_x + 18.0, length, water_y)

	_place_bridge_end_city(context_root, length, water_y)


func _place_bridge_skyline_side(
	parent: Node3D,
	side: float,
	x: float,
	length: float,
	water_y: float
) -> void:
	var z: float = -length * 0.46
	var building_index: int = 0
	while z <= length * 0.46:
		var height: float = 8.0 + _hashf(building_index, int(side * 19.0)) * 14.0
		var building_width: float = 7.0 + _hashf(building_index, 31) * 5.0
		var depth: float = 9.0 + _hashf(building_index, 37) * 6.0
		var material: Material = MAT_CITY_DARK if building_index % 2 == 0 else MAT_CITY_MID
		var block_x: float = side * (x + _hashf(building_index, 41) * 8.0)
		_add_bridge_box(
			parent,
			"RiverCityBlock",
			Vector3(building_width, height, depth),
			Vector3(block_x, water_y + height * 0.5, z),
			material
		)
		if building_index % 2 == 0:
			var window_x: float = block_x - side * (building_width * 0.5 + 0.05)
			_add_bridge_box(
				parent,
				"RiverCityWindowStrip",
				Vector3(0.08, 0.26, depth * 0.62),
				Vector3(window_x, water_y + height * 0.55, z),
				MAT_CITY_WINDOW
			)
			_add_bridge_box(
				parent,
				"RiverCityWindowStrip",
				Vector3(0.08, 0.22, depth * 0.42),
				Vector3(window_x, water_y + height * 0.78, z + depth * 0.12),
				MAT_CITY_WINDOW
			)
		z += depth + 8.0 + _hashf(building_index, 43) * 7.0
		building_index += 1


func _place_bridge_end_city(parent: Node3D, length: float, water_y: float) -> void:
	for end_side in [-1.0, 1.0]:
		var z: float = end_side * (length * 0.5 + 18.0)
		for column in range(5):
			var x: float = -30.0 + float(column) * 15.0
			var height: float = 10.0 + _hashf(column, int(end_side * 53.0)) * 16.0
			var depth: float = 9.0 + _hashf(column, 59) * 5.0
			_add_bridge_box(
				parent,
				"EndCitySilhouette",
				Vector3(10.0, height, depth),
				Vector3(x, water_y + height * 0.5, z + end_side * _hashf(column, 61) * 10.0),
				MAT_CITY_DARK if column % 2 == 0 else MAT_CITY_MID
			)
			if column % 2 == 1:
				_add_bridge_box(
					parent,
					"EndCityWindowStrip",
					Vector3(5.2, 0.22, 0.08),
					Vector3(x, water_y + height * 0.62, z - end_side * (depth * 0.5 + 0.05)),
					MAT_CITY_WINDOW
				)


func _build_stage_atmosphere_context(width: float, length: float, base_y: float) -> void:
	if _visual_root == null:
		return
	if _visual_root.get_node_or_null("StageAtmosphereContext") != null:
		return

	var stage_root: Node3D = Node3D.new()
	stage_root.name = "StageAtmosphereContext"
	_visual_root.add_child(stage_root)

	var horizon_mat: StandardMaterial3D = _make_stage_scrim_material(
		Color(0.02, 0.105, 0.09, 0.42),
		Color(0.0, 0.24, 0.12, 1.0),
		0.12
	)
	var distant_mat: StandardMaterial3D = _make_stage_scrim_material(
		Color(0.018, 0.032, 0.06, 0.58),
		Color(0.04, 0.08, 0.12, 1.0),
		0.18
	)
	var haze_mat: StandardMaterial3D = _make_stage_scrim_material(
		Color(0.08, 0.22, 0.16, 0.28),
		Color(0.08, 0.36, 0.2, 1.0),
		0.08
	)

	var side_x: float = width * 0.5 + 18.0
	var end_z: float = length * 0.5 + 22.0
	var wall_height: float = 34.0
	var wall_y: float = base_y + wall_height * 0.5 + 2.0
	_add_bridge_box(
		stage_root,
		"StageHorizonBack",
		Vector3(width + 64.0, wall_height, 0.32),
		Vector3(0.0, wall_y, end_z),
		distant_mat
	)
	_add_bridge_box(
		stage_root,
		"StageHorizonFront",
		Vector3(width + 64.0, wall_height * 0.72, 0.32),
		Vector3(0.0, wall_y - 3.5, -end_z),
		horizon_mat
	)
	for side in [-1.0, 1.0]:
		_add_bridge_box(
			stage_root,
			"StageSideScrim",
			Vector3(0.32, wall_height * 0.86, length + 52.0),
			Vector3(side * side_x, wall_y - 1.8, 0.0),
			horizon_mat
		)
		_add_bridge_box(
			stage_root,
			"StageHazeBand",
			Vector3(0.34, 8.0, length + 42.0),
			Vector3(side * (side_x - 1.4), base_y + 7.0, 0.0),
			haze_mat
		)


func build_continuous_play_surface(
	road_width: float,
	z_start: float,
	z_end: float,
	y: float = 0.0,
	thickness: float = 0.12
) -> void:
	var length: float = z_end - z_start
	var center_z: float = (z_start + z_end) * 0.5
	_add_invisible_collision_box(
		"PlaySurface",
		Vector3(road_width, thickness, length),
		Vector3(0.0, y, center_z)
	)


func build_broken_bridge_play_surface(
	segments: Array[Dictionary],
	gaps: Array[Dictionary],
	path_half_width: float,
	y: float = 0.0,
	thickness: float = 0.12,
	gap_crossing_width_ratio: float = SURFACE_BUILDER.DEFAULT_GAP_CROSSING_WIDTH_RATIO
) -> void:
	var gap_crossing_half_width: float = SURFACE_BUILDER.gap_crossing_half_width(
		path_half_width, gap_crossing_width_ratio
	)
	for segment_index in range(segments.size()):
		var segment: Dictionary = segments[segment_index]
		var length: float = float(segment["z1"]) - float(segment["z0"])
		var center_z: float = (float(segment["z0"]) + float(segment["z1"])) * 0.5
		_add_invisible_collision_box(
			"BridgeDeck_%d" % segment_index,
			Vector3(path_half_width * 2.0, thickness, length),
			Vector3(0.0, y, center_z)
		)

	for gap_index in range(gaps.size()):
		var gap: Dictionary = gaps[gap_index]
		var length: float = float(gap["z1"]) - float(gap["z0"])
		var center_z: float = (float(gap["z0"]) + float(gap["z1"])) * 0.5
		_add_invisible_collision_box(
			"BridgeGapCrossing_%d" % gap_index,
			Vector3(gap_crossing_half_width * 2.0, thickness, length),
			Vector3(0.0, y, center_z)
		)


func build_bridge_fall_zones(
	segments: Array[Dictionary],
	gaps: Array[Dictionary],
	path_half_width: float,
	void_half_width: float,
	gap_crossing_width_ratio: float = SURFACE_BUILDER.DEFAULT_GAP_CROSSING_WIDTH_RATIO
) -> void:
	var kill_height: float = 8.0
	var kill_y: float = -2.5
	var lateral_half: float = max(void_half_width * 0.5, path_half_width + 8.0)
	var gap_crossing_half_width: float = SURFACE_BUILDER.gap_crossing_half_width(
		path_half_width, gap_crossing_width_ratio
	)

	for segment in segments:
		var z0: float = float(segment["z0"])
		var z1: float = float(segment["z1"])
		var length: float = z1 - z0
		var center_z: float = (z0 + z1) * 0.5
		_add_bridge_side_void_kill(
			path_half_width, lateral_half, length + 2.0, center_z, kill_y, kill_height
		)

	for gap in gaps:
		var z0: float = float(gap["z0"])
		var z1: float = float(gap["z1"])
		var length: float = z1 - z0
		var center_z: float = (z0 + z1) * 0.5
		_add_bridge_side_void_kill(
			gap_crossing_half_width, lateral_half, length + 1.0, center_z, kill_y, kill_height
		)


func _add_bridge_side_void_kill(
	inner_half_width: float,
	outer_half_width: float,
	length: float,
	center_z: float,
	kill_y: float,
	kill_height: float
) -> void:
	var side_width: float = outer_half_width - inner_half_width
	if side_width <= 0.5:
		return
	var side_center_x: float = inner_half_width + side_width * 0.5
	_add_bridge_void_kill_box(
		Vector3(side_width, kill_height, length),
		Vector3(-side_center_x, kill_y, center_z)
	)
	_add_bridge_void_kill_box(
		Vector3(side_width, kill_height, length),
		Vector3(side_center_x, kill_y, center_z)
	)


func compose_map(segments: Array[Dictionary], gaps: Array[Dictionary]) -> void:
	match _style:
		MapStyle.BROKEN_BRIDGE:
			_compose_broken_bridge(segments, gaps)
		_:
			_compose_long_road(segments, gaps)


func build_markers(
	visual_width: float,
	spawn_z: float,
	goal_z: float,
	start_gate_z: float,
	finish_gate_z: float
) -> void:
	var gate_half: float = max(visual_width * 0.5 - 1.0, 6.0)
	var spawn_y: float = _surface_y_at(spawn_z)
	var goal_y: float = _surface_y_at(goal_z)
	var start_y: float = _surface_y_at(start_gate_z)
	var finish_y: float = _surface_y_at(finish_gate_z)
	_add_marker_box("SpawnZone", Vector3(visual_width, 0.06, 8.0), Vector3(0.0, spawn_y + 0.12, spawn_z), MAT_SPAWN)
	_add_marker_box("GoalGuide", Vector3(visual_width, 0.06, 8.0), Vector3(0.0, goal_y + 0.13, goal_z), MAT_GOAL)
	_add_marker_box("StartLine", Vector3(visual_width, 0.07, 0.45), Vector3(0.0, start_y + 0.12, start_gate_z), MAT_SPAWN)
	_add_marker_box("FinishLine", Vector3(visual_width, 0.07, 0.45), Vector3(0.0, finish_y + 0.12, finish_gate_z), MAT_GOAL)
	_add_gate(
		Vector3(-gate_half, start_y + 1.6, start_gate_z),
		Vector3(gate_half, start_y + 1.6, start_gate_z),
		MAT_SPAWN
	)
	_add_gate(
		Vector3(-gate_half, finish_y + 1.6, finish_gate_z),
		Vector3(gate_half, finish_y + 1.6, finish_gate_z),
		MAT_GOAL
	)


func _compose_long_road(segments: Array[Dictionary], gaps: Array[Dictionary]) -> void:
	var lane_columns: PackedFloat32Array = PackedFloat32Array([-8.0, 0.0, 8.0])
	var edge_x: float = 10.5
	var light_x: float = 15.0

	for segment in segments:
		_tile_authored_range(
			float(segment["z0"]),
			float(segment["z1"]),
			lane_columns,
			0.04,
			0.0,
			false
		)
		_place_sparse_shoulders(float(segment["z0"]), float(segment["z1"]), 11.5, 0.22)

	_compose_gap_visuals(gaps, edge_x, false)
	_place_street_lights_authored(-72.0, 72.0, light_x, 28.0, 5.0)
	_place_scattered_props(
		[
			{"scene": SCENE_CONTAINER_RED, "pos": Vector3(-26.0, 0.0, -58.0), "scale": 1.1, "yaw": 14.0},
			{"scene": SCENE_CONTAINER_GREEN, "pos": Vector3(27.0, 0.0, 52.0), "scale": 1.05, "yaw": -12.0},
		]
	)


func _compose_broken_bridge(segments: Array[Dictionary], gaps: Array[Dictionary]) -> void:
	var deck_columns: PackedFloat32Array = PackedFloat32Array([0.0])
	var side_column: float = 4.0
	var edge_x: float = 5.4
	var damage_clusters: Array[Dictionary] = [
		{"z": -62.0, "radius": 10.0, "side_loss": 0.82, "crack": 0.78},
		{"z": -24.0, "radius": 12.0, "side_loss": 0.9, "crack": 0.92},
		{"z": 16.0, "radius": 11.0, "side_loss": 0.86, "crack": 0.88},
		{"z": 58.0, "radius": 9.0, "side_loss": 0.8, "crack": 0.74},
	]

	for segment in segments:
		_tile_authored_range(
			float(segment["z0"]),
			float(segment["z1"]),
			deck_columns,
			0.16,
			0.0,
			true,
			damage_clusters
		)
		_place_bridge_side_shreds(
			float(segment["z0"]),
			float(segment["z1"]),
			side_column,
			damage_clusters
		)

	_compose_bridge_gap_visuals(gaps)
	_place_bridge_lane_guides(segments, gaps)
	_place_bridge_surface_wear(segments, gaps)
	_place_suspension_bridge_dressing(segments, edge_x)
	_place_bridge_void_props(damage_clusters)


func _place_bridge_surface_wear(segments: Array[Dictionary], gaps: Array[Dictionary]) -> void:
	if _visual_root == null:
		return
	for segment_index in range(segments.size()):
		var segment: Dictionary = segments[segment_index]
		var z: float = float(segment["z0"]) + 5.0
		var z_end: float = float(segment["z1"]) - 3.0
		while z < z_end:
			if not _z_in_gap_ranges(z, gaps):
				var surface_y: float = _surface_y_at(z)
				var patch_width: float = 1.9 + _hashf(int(z * 10.0), segment_index + 3) * 1.4
				var patch_length: float = 2.2 + _hashf(int(z * 9.0), segment_index + 9) * 2.2
				var patch_x: float = lerpf(-2.0, 2.0, _hashf(int(z * 11.0), segment_index + 17))
				_add_bridge_box(
					_visual_root,
					"BridgeAsphaltPatch",
					Vector3(patch_width, 0.035, patch_length),
					Vector3(patch_x, surface_y + 0.075, z),
					MAT_ROAD_ASPHALT
				)
				if _hashf(int(z * 13.0), segment_index + 23) > 0.45:
					_add_bridge_box(
						_visual_root,
						"BridgeRoadScuff",
						Vector3(0.55, 0.03, patch_length * 0.85),
						Vector3(patch_x + 0.45, surface_y + 0.1, z + 0.2),
						MAT_ROAD_SCUFF
					)
				if _hashf(int(z * 15.0), segment_index + 29) > 0.72:
					_add_bridge_box(
						_visual_root,
						"BridgeScorchMark",
						Vector3(1.25, 0.032, 1.55),
						Vector3(patch_x - 0.35, surface_y + 0.105, z - 0.6),
						MAT_ROAD_SCORCH
					)
			z += 7.5

	for gap in gaps:
		for edge_z in [float(gap["z0"]) - 2.2, float(gap["z1"]) + 2.2]:
			var surface_y: float = _surface_y_at(edge_z)
			_add_bridge_box(
				_visual_root,
				"BrokenBridgeWarningStripe",
				Vector3(6.6, 0.04, 0.24),
				Vector3(0.0, surface_y + 0.13, edge_z),
				MAT_ROAD_LINE
			)


func _place_suspension_bridge_dressing(
	segments: Array[Dictionary],
	edge_x: float
) -> void:
	if _visual_root == null or segments.is_empty():
		return
	var z_start: float = float(segments.front().get("z0", -84.0))
	var z_end: float = float(segments.back().get("z1", 84.0))
	var tower_z_values: PackedFloat32Array = PackedFloat32Array([
		lerpf(z_start, z_end, 0.18),
		lerpf(z_start, z_end, 0.82),
	])
	var side_x: float = edge_x + 2.4
	var steel_mat: StandardMaterial3D = _make_bridge_steel_material()
	var cable_mat: StandardMaterial3D = _make_bridge_cable_material()
	var dressing_root := Node3D.new()
	dressing_root.name = "SuspensionBridgeDressing"
	_visual_root.add_child(dressing_root)

	_add_suspension_deck_structure(dressing_root, segments, side_x, steel_mat)

	for tower_z in tower_z_values:
		_add_bridge_tower_frame(dressing_root, tower_z, side_x, steel_mat)

	for side in [-1.0, 1.0]:
		_add_bridge_cable_anchor(
			dressing_root,
			Vector3(side * side_x, _surface_y_at(z_start) + 2.3, z_start + 3.0),
			steel_mat
		)
		_add_bridge_cable_anchor(
			dressing_root,
			Vector3(side * side_x, _surface_y_at(z_end) + 2.3, z_end - 3.0),
			steel_mat
		)
		var cable_points: Array[Vector3] = _build_suspension_cable_points(
			side * side_x,
			z_start,
			z_end,
			tower_z_values[0],
			tower_z_values[1]
		)
		for point_index in range(cable_points.size() - 1):
			_add_beam_between(
				dressing_root,
				"MainCable",
				cable_points[point_index],
				cable_points[point_index + 1],
				Vector2(0.16, 0.16),
				cable_mat
			)
		for cable_point in cable_points:
			var deck_y: float = _surface_y_at(cable_point.z)
			_add_bridge_box(
				dressing_root,
				"HangerCable",
				Vector3(0.09, maxf(cable_point.y - deck_y - 1.25, 0.5), 0.09),
				Vector3(cable_point.x, (cable_point.y + deck_y + 1.25) * 0.5, cable_point.z),
				cable_mat
			)
			_add_bridge_box(
				dressing_root,
				"DeckTie",
				Vector3(0.55, 0.28, 0.62),
				Vector3(cable_point.x, deck_y + 1.12, cable_point.z),
				steel_mat
			)


func _add_suspension_deck_structure(
	parent: Node3D,
	segments: Array[Dictionary],
	side_x: float,
	steel_mat: Material
) -> void:
	var z_start: float = float(segments.front().get("z0", -84.0))
	var z_end: float = float(segments.back().get("z1", 84.0))
	var truss_step: float = 8.0
	var z: float = z_start
	while z < z_end - 0.01:
		var next_z: float = minf(z + truss_step, z_end)
		var center_z: float = (z + next_z) * 0.5
		var deck_y: float = _surface_y_at(center_z)
		var run_length: float = next_z - z
		for side in [-1.0, 1.0]:
			var x: float = side * side_x
			_add_bridge_box(
				parent,
				"SideBoxGirder",
				Vector3(0.48, 0.42, run_length + 0.05),
				Vector3(x, deck_y + 0.82, center_z),
				steel_mat
			)
			_add_bridge_box(
				parent,
				"UpperSideRail",
				Vector3(0.24, 0.24, run_length + 0.05),
				Vector3(x, deck_y + 1.72, center_z),
				steel_mat
			)
			_add_beam_between(
				parent,
				"SideTrussBrace",
				Vector3(x, deck_y + 0.74, z),
				Vector3(x, deck_y + 1.72, next_z),
				Vector2(0.15, 0.15),
				steel_mat
			)
			_add_beam_between(
				parent,
				"SideTrussBrace",
				Vector3(x, deck_y + 1.72, z),
				Vector3(x, deck_y + 0.74, next_z),
				Vector2(0.15, 0.15),
				steel_mat
			)
		z = next_z


func _add_bridge_tower_frame(
	parent: Node3D,
	tower_z: float,
	side_x: float,
	steel_mat: Material
) -> void:
	var deck_y: float = _surface_y_at(tower_z)
	var tower_height: float = 13.5
	var tower_y: float = deck_y + tower_height * 0.5
	var post_size: Vector3 = Vector3(0.58, tower_height, 0.58)
	for side in [-1.0, 1.0]:
		var x: float = side * side_x
		_add_bridge_box(parent, "SuspensionTowerPost", post_size, Vector3(x, tower_y, tower_z), steel_mat)
		_add_bridge_box(
			parent,
			"SuspensionTowerFoot",
			Vector3(1.7, 0.45, 1.35),
			Vector3(x, deck_y + 0.2, tower_z),
			steel_mat
		)
	var top_y: float = deck_y + tower_height - 0.6
	var mid_y: float = deck_y + tower_height * 0.58
	var span_width: float = side_x * 2.0 + 0.8
	_add_bridge_box(
		parent,
		"TowerTopCrossbeam",
		Vector3(span_width, 0.48, 0.5),
		Vector3(0.0, top_y, tower_z),
		steel_mat
	)
	_add_bridge_box(
		parent,
		"TowerMidCrossbeam",
		Vector3(span_width, 0.34, 0.4),
		Vector3(0.0, mid_y, tower_z),
		steel_mat
	)
	_add_beam_between(
		parent,
		"TowerXBrace",
		Vector3(-side_x, deck_y + 1.4, tower_z),
		Vector3(side_x, top_y - 0.4, tower_z),
		Vector2(0.16, 0.16),
		steel_mat
	)
	_add_beam_between(
		parent,
		"TowerXBrace",
		Vector3(side_x, deck_y + 1.4, tower_z),
		Vector3(-side_x, top_y - 0.4, tower_z),
		Vector2(0.16, 0.16),
		steel_mat
	)


func _add_bridge_cable_anchor(parent: Node3D, position: Vector3, steel_mat: Material) -> void:
	_add_bridge_box(parent, "CableAnchor", Vector3(1.25, 1.1, 1.8), position, steel_mat)
	_add_bridge_box(
		parent,
		"CableAnchorCap",
		Vector3(1.7, 0.32, 2.1),
		position + Vector3(0.0, 0.68, 0.0),
		steel_mat
	)


func _build_suspension_cable_points(
	x: float,
	z_start: float,
	z_end: float,
	tower_start_z: float,
	tower_end_z: float
) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var point_count: int = 19
	var anchor_start_z: float = z_start + 5.0
	var anchor_end_z: float = z_end - 5.0
	for index in range(point_count):
		var t: float = float(index) / float(point_count - 1)
		var z: float = lerpf(anchor_start_z, anchor_end_z, t)
		var deck_y: float = _surface_y_at(z)
		var offset_y: float = 8.6
		if z < tower_start_z:
			var approach_t: float = inverse_lerp(anchor_start_z, tower_start_z, z)
			offset_y = lerpf(4.8, 13.4, clampf(approach_t, 0.0, 1.0))
		elif z > tower_end_z:
			var exit_t: float = inverse_lerp(tower_end_z, anchor_end_z, z)
			offset_y = lerpf(13.4, 4.8, clampf(exit_t, 0.0, 1.0))
		else:
			var span_t: float = inverse_lerp(tower_start_z, tower_end_z, z)
			var centered: float = absf(span_t - 0.5) * 2.0
			offset_y = 8.6 + centered * centered * 4.8
		var cable_y: float = deck_y + offset_y
		points.append(Vector3(x, cable_y, z))
	return points


func _add_bridge_box(
	parent: Node3D,
	box_name: String,
	size: Vector3,
	position: Vector3,
	material: Material
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = box_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_beam_between(
	parent: Node3D,
	beam_name: String,
	start: Vector3,
	end: Vector3,
	cross_section: Vector2,
	material: Material
) -> void:
	var delta: Vector3 = end - start
	var length: float = delta.length()
	if length <= 0.01:
		return
	var beam: MeshInstance3D = _add_bridge_box(
		parent,
		beam_name,
		Vector3(cross_section.x, cross_section.y, length),
		(start + end) * 0.5,
		material
	)
	beam.look_at(end, Vector3.UP)


func _make_bridge_steel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.31, 0.29, 1.0)
	mat.metallic = 0.75
	mat.roughness = 0.42
	mat.emission_enabled = true
	mat.emission = Color(0.03, 0.06, 0.05, 1.0)
	mat.emission_energy_multiplier = 0.18
	return mat


func _make_bridge_cable_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.55, 0.52, 1.0)
	mat.metallic = 0.9
	mat.roughness = 0.34
	mat.emission_enabled = true
	mat.emission = Color(0.04, 0.05, 0.05, 1.0)
	mat.emission_energy_multiplier = 0.12
	return mat


func _make_stage_scrim_material(
	albedo: Color,
	emission: Color,
	emission_energy: float
) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = emission_energy
	mat.roughness = 1.0
	return mat


func _place_bridge_side_shreds(
	z_start: float,
	z_end: float,
	side_x: float,
	damage_clusters: Array[Dictionary]
) -> void:
	var z: float = z_start + TILE_HALF
	while z < z_end - TILE_HALF:
		for side in [-1.0, 1.0]:
			var x: float = side * side_x
			if _should_skip_tile(x, z, PackedFloat32Array([0.0, side_x]), 0.68, damage_clusters):
				continue
			if _hashf(int(z * 2.0), int(x * 5.0) + 101) > 0.42:
				var variant: StreetVariant = (
					StreetVariant.CRACK1
					if _hashf(int(z), int(x)) > 0.55
					else StreetVariant.CRACK2
				)
				_place_street_tile(x, 0.0, z, variant)
		z += TILE_SIZE


func _compose_bridge_gap_visuals(gaps: Array[Dictionary]) -> void:
	var deck_columns: PackedFloat32Array = PackedFloat32Array([-4.0, 0.0, 4.0])
	for gap_index in range(gaps.size()):
		var gap: Dictionary = gaps[gap_index]
		var z0: float = float(gap["z0"])
		var z1: float = float(gap["z1"])
		var gap_center: float = (z0 + z1) * 0.5

		# Cracked deck lips on the segment side only — align to the 8m tile grid like long-road gaps.
		for edge_z in [z0 - TILE_HALF, z1 + TILE_HALF]:
			for x in deck_columns:
				var lip_variant: StreetVariant = (
					StreetVariant.CRACK1
					if _hashf(int(edge_z + x), 41 + gap_index) > 0.5
					else StreetVariant.CRACK2
				)
				_place_street_tile(x, 0.0, edge_z, lip_variant)

		# GapCrossingPlank (built in build_route_context) is the only walk visual in the void.
		# Do not place 8m street tiles here — they read as a full-width invisible bridge.

		for guide_z in [z0 + 0.8, gap_center, z1 - 0.8]:
			var cone_x: float = (
				SURFACE_BUILDER.gap_crossing_half_width(_path_half_width, _gap_crossing_width_ratio) + 0.55
			)
			_place_cone(guide_z, -cone_x)
			_place_cone(guide_z, cone_x)

		if gap_index % 2 == 0:
			_place_prop(SCENE_PALLET_BROKEN, Vector3(-14.0, 0.0, gap_center + 1.2), 1.15, 36.0)
		else:
			_place_prop(SCENE_CINDER_BLOCK, Vector3(14.5, 0.0, gap_center - 1.4), 1.1, -14.0)


func _place_bridge_lane_guides(segments: Array[Dictionary], gaps: Array[Dictionary]) -> void:
	for segment in segments:
		var z: float = float(segment["z0"]) + 4.0
		var z_end: float = float(segment["z1"]) - 3.0
		while z < z_end:
			if _hashf(int(z), 97) > 0.22:
				_place_cone(z, -2.4)
				_place_cone(z + 1.4, 2.4)
			z += 10.0 + _hashf(int(z), 7) * 3.0

	for gap in gaps:
		var z0: float = float(gap["z0"])
		var z1: float = float(gap["z1"])
		_place_traffic_barrier(z0 + 0.6, -3.2, false)
		_place_traffic_barrier(z1 - 0.6, 3.2, true)


func _tile_authored_range(
	z_start: float,
	z_end: float,
	columns: PackedFloat32Array,
	base_crack_density: float,
	side_tile_loss: float,
	is_bridge: bool,
	damage_clusters: Array[Dictionary] = []
) -> void:
	var z: float = z_start
	var row_index: int = 0
	while z < z_end - 0.01:
		var tile_center_z: float = z + TILE_HALF
		for column_index in range(columns.size()):
			var x: float = columns[column_index]
			if _should_skip_tile(x, tile_center_z, columns, side_tile_loss, damage_clusters):
				continue
			var crack_density: float = _cluster_crack_density(
				tile_center_z, base_crack_density, damage_clusters
			)
			var variant: StreetVariant = _pick_authored_variant(
				row_index, column_index, tile_center_z, crack_density, is_bridge
			)
			_place_street_tile(x, 0.0, tile_center_z, variant)
		z += TILE_SIZE
		row_index += 1


func _place_sparse_shoulders(z_start: float, z_end: float, shoulder_x: float, chance: float) -> void:
	var z: float = z_start + 4.0
	while z < z_end - 4.0:
		if _hashf(int(z), 17) < chance:
			for side in [-1.0, 1.0]:
				if _hashf(int(z + side * 3.0), 23) < chance * 0.85:
					_place_street_tile(side * shoulder_x, 0.0, z, StreetVariant.STRAIGHT)
		z += TILE_SIZE * 2.0


func _compose_gap_visuals(gaps: Array[Dictionary], edge_x: float, heavy: bool) -> void:
	for gap_index in range(gaps.size()):
		var gap: Dictionary = gaps[gap_index]
		var z0: float = float(gap["z0"])
		var z1: float = float(gap["z1"])
		var gap_center: float = (z0 + z1) * 0.5
		var lane_offsets: PackedFloat32Array = (
			PackedFloat32Array([-8.0, 0.0, 8.0])
			if _style == MapStyle.LONG_ROAD
			else PackedFloat32Array([-4.0, 0.0, 4.0])
		)

		for edge_z in [z0 - TILE_HALF, z1 + TILE_HALF]:
			for x in lane_offsets:
				var variant: StreetVariant = (
					StreetVariant.CRACK1 if _hashf(int(edge_z + x), 41 + gap_index) > 0.5 else StreetVariant.CRACK2
				)
				_place_street_tile(x, 0.0, edge_z, variant)

		_place_cone(z0 - 0.5, -2.5)
		_place_cone(z0 - 0.5, 2.5)
		_place_cone(z1 + 0.5, -2.5)
		_place_cone(z1 + 0.5, 2.5)
		_place_plastic_barrier(gap_center, -edge_x)
		_place_plastic_barrier(gap_center, edge_x)

		if heavy:
			_place_prop(SCENE_PIPES, Vector3(-edge_x - 5.5, 0.0, gap_center), 1.45, 88.0)
			_place_prop(SCENE_PIPES, Vector3(edge_x + 5.5, 0.0, gap_center), 1.4, -92.0)
			if gap_index % 2 == 0:
				_place_prop(SCENE_PALLET_BROKEN, Vector3(-edge_x - 3.0, 0.0, gap_center + 1.5), 1.2, 30.0)
				_place_prop(SCENE_CINDER_BLOCK, Vector3(edge_x + 3.5, 0.0, gap_center - 1.0), 1.15, -20.0)


func _place_edge_guides(
	segments: Array[Dictionary],
	edge_x: float,
	spacing: float,
	skip_chance: float
) -> void:
	for segment in segments:
		var z: float = float(segment["z0"]) + 3.0
		var z_end: float = float(segment["z1"]) - 2.0
		while z < z_end:
			if _hashf(int(z * 10.0), 57) > skip_chance:
				_place_traffic_barrier(z, -edge_x, false)
				if _hashf(int(z * 7.0), 61) > 0.25:
					_place_traffic_barrier(z + 2.2, edge_x, true)
			z += spacing + _hashf(int(z), 3) * 2.0


func _place_bridge_edge_rails(segments: Array[Dictionary], edge_x: float) -> void:
	for segment in segments:
		var z: float = float(segment["z0"]) + 2.0
		var z_end: float = float(segment["z1"]) - 1.5
		while z < z_end:
			if _hashf(int(z), 71) > 0.38:
				_place_traffic_barrier(z, -edge_x, false)
			if _hashf(int(z + 3.0), 73) > 0.42:
				_place_traffic_barrier(z + 2.4, edge_x, true)
			if _hashf(int(z), 75) > 0.7:
				_place_plastic_barrier(z + 4.0, -edge_x - 0.6)
			z += 7.5 + _hashf(int(z), 5) * 2.0


func _place_street_lights_authored(
	z_start: float,
	z_end: float,
	light_x: float,
	spacing: float,
	jitter: float
) -> void:
	var z: float = z_start + 6.0
	var side_toggle: bool = false
	while z < z_end:
		var offset: float = (_hashf(int(z), 11) - 0.5) * jitter * 2.0
		var x: float = -light_x if side_toggle else light_x
		_place_street_light(z + offset, x, 90.0 if x < 0.0 else -90.0)
		side_toggle = not side_toggle
		z += spacing + _hashf(int(z), 19) * 3.0


func _place_bridge_void_props(damage_clusters: Array[Dictionary]) -> void:
	_place_scattered_props(
		[
			{"scene": SCENE_CONTAINER_RED, "pos": Vector3(-24.0, 0.0, -36.0), "scale": 1.0, "yaw": 18.0},
			{"scene": SCENE_CONTAINER_GREEN, "pos": Vector3(25.0, 0.0, 28.0), "scale": 0.95, "yaw": -16.0},
			{"scene": SCENE_PALLET_BROKEN, "pos": Vector3(-21.0, 0.0, 44.0), "scale": 1.15, "yaw": 40.0},
			{"scene": SCENE_PIPES, "pos": Vector3(22.0, 0.0, -52.0), "scale": 1.25, "yaw": -78.0},
		]
	)
	for cluster in damage_clusters:
		var cluster_z: float = float(cluster["z"])
		if _hashf(int(cluster_z), 29) > 0.35:
			_place_prop(SCENE_CINDER_BLOCK, Vector3(-17.0, 0.0, cluster_z + 3.0), 1.05, 12.0)
		if _hashf(int(cluster_z), 31) > 0.4:
			_place_prop(SCENE_CINDER_BLOCK, Vector3(17.5, 0.0, cluster_z - 2.0), 1.05, -8.0)
		if _hashf(int(cluster_z), 33) > 0.55:
			_place_prop(SCENE_PALLET_BROKEN, Vector3(-18.5, 0.0, cluster_z - 1.5), 1.1, 22.0)


func _place_deck_supports(segments: Array[Dictionary], edge_x: float) -> void:
	for segment in segments:
		var center_z: float = (float(segment["z0"]) + float(segment["z1"])) * 0.5
		for side in [-1.0, 1.0]:
			_place_prop(SCENE_CINDER_BLOCK, Vector3(side * (edge_x + 1.2), -0.5, center_z), 1.35, 0.0)
			_place_prop(SCENE_CINDER_BLOCK, Vector3(side * (edge_x + 1.2), -0.5, center_z + 14.0), 1.2, 15.0)


func _place_scattered_props(entries: Array[Dictionary]) -> void:
	for entry in entries:
		_place_prop(
			entry.get("scene") as PackedScene,
			entry.get("pos", Vector3.ZERO) as Vector3,
			float(entry.get("scale", 1.0)),
			float(entry.get("yaw", 0.0))
		)


func _should_skip_tile(
	x: float,
	z: float,
	columns: PackedFloat32Array,
	side_tile_loss: float,
	damage_clusters: Array[Dictionary]
) -> bool:
	if columns.size() <= 0:
		return true
	var outer_x: float = columns[columns.size() - 1]
	var is_outer: bool = abs(x) >= abs(outer_x) - 0.1
	var is_center: bool = abs(x) < 0.1
	if is_center:
		for cluster in damage_clusters:
			if abs(z - float(cluster["z"])) <= float(cluster["radius"]) * 0.35:
				return _hashf(int(z * 2.0), int(x * 10.0) + 97) < 0.12
		return false
	if not is_outer:
		return false
	var loss: float = side_tile_loss
	for cluster in damage_clusters:
		var dist: float = abs(z - float(cluster["z"]))
		if dist <= float(cluster["radius"]):
			loss = max(loss, float(cluster["side_loss"]))
	if loss <= 0.0:
		return false
	return _hashf(int(z * 3.0), int(x * 7.0) + 13) < loss


func _cluster_crack_density(z: float, base_density: float, damage_clusters: Array[Dictionary]) -> float:
	var density: float = base_density
	for cluster in damage_clusters:
		var dist: float = abs(z - float(cluster["z"]))
		var radius: float = float(cluster["radius"])
		if dist <= radius:
			var falloff: float = 1.0 - clamp(dist / radius, 0.0, 1.0)
			density = max(density, float(cluster["crack"]) * falloff)
	return density


func _pick_authored_variant(
	row_index: int,
	column_index: int,
	z: float,
	crack_density: float,
	is_bridge: bool
) -> StreetVariant:
	if is_bridge and column_index == 1 and _hashf(row_index + int(z), 47) < 0.08:
		return StreetVariant.STRAIGHT
	if crack_density <= 0.0:
		return StreetVariant.STRAIGHT
	var roll: float = _hashf(row_index + column_index + int(z * 0.5), 53)
	if roll > crack_density:
		return StreetVariant.STRAIGHT
	return StreetVariant.CRACK1 if _hashf(row_index + int(z), 59) > 0.5 else StreetVariant.CRACK2


func _hashf(a: int, b: int = 0) -> float:
	var hashed: int = int(hash(int(a * 374761393 + b * 668265263))) & 0x7fffffff
	return float(hashed % 1000) / 1000.0


func _place_street_tile(x: float, y: float, z: float, variant: StreetVariant) -> void:
	_place_prop(_scene_for_variant(variant), Vector3(x, y + _surface_y_at(z), z), 1.0, 0.0)


func _scene_for_variant(variant: StreetVariant) -> PackedScene:
	match variant:
		StreetVariant.CRACK1:
			return SCENE_STREET_CRACK1
		StreetVariant.CRACK2:
			return SCENE_STREET_CRACK2
		_:
			return SCENE_STREET_STRAIGHT


func _place_plastic_barrier(z: float, x: float) -> void:
	var y: float = _surface_y_at(z)
	_place_prop(SCENE_PLASTIC_BARRIER, Vector3(x, y, z), 1.4, 90.0 if x < 0.0 else -90.0)


func _place_traffic_barrier(z: float, x: float, flip: bool) -> void:
	var y: float = _surface_y_at(z)
	var scene: PackedScene = SCENE_TRAFFIC_BARRIER_1 if _hashf(int(z), 67) > 0.5 else SCENE_TRAFFIC_BARRIER_2
	_place_prop(scene, Vector3(x, y, z), 1.3, 90.0 if flip else -90.0)


func _place_cone(z: float, x: float) -> void:
	var y: float = _surface_y_at(z)
	_place_prop(SCENE_TRAFFIC_CONE_1, Vector3(x, y, z), 1.15, _hashf(int(z + x), 73) * 40.0)


func _place_street_light(z: float, x: float, yaw_degrees: float) -> void:
	var y: float = _surface_y_at(z)
	_place_prop(SCENE_STREET_LIGHT, Vector3(x, y, z), 1.3, yaw_degrees)


func build_ramp_visuals(ramp_specs: Array, road_width: float) -> void:
	for raw_spec in ramp_specs:
		if raw_spec is not Dictionary:
			continue
		var spec: Dictionary = raw_spec
		var z0: float = float(spec.get("z0", 0.0))
		var z1: float = float(spec.get("z1", z0))
		if z1 <= z0:
			continue
		var length: float = z1 - z0
		var center_z: float = (z0 + z1) * 0.5
		var start_y: float = float(spec.get("start_y", 0.0))
		var height_delta: float = float(spec.get("height_delta", 0.0))
		var slope_angle: float = atan2(height_delta, length)
		var ramp_span: float = sqrt(length * length + height_delta * height_delta)
		var center_y: float = start_y + height_delta * 0.5

		var ramp_mesh := MeshInstance3D.new()
		ramp_mesh.name = "RampVisual"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(road_width, 0.14, maxf(ramp_span, 0.5))
		ramp_mesh.mesh = mesh
		ramp_mesh.material_override = MAT_CONCRETE
		ramp_mesh.position = Vector3(0.0, center_y, center_z)
		ramp_mesh.rotation.x = -slope_angle
		_visual_root.add_child(ramp_mesh)


func _place_prop(scene: PackedScene, position: Vector3, scale_value: float, yaw_degrees: float) -> void:
	if scene == null or _visual_root == null:
		return
	var instance: Node3D = scene.instantiate() as Node3D
	if instance == null:
		return
	instance.position = position
	instance.scale = Vector3.ONE * scale_value
	instance.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	_visual_root.add_child(instance)


func _add_boundary_wall(wall_name: String, size: Vector3, position: Vector3) -> void:
	if _boundary_root == null:
		return
	var body := StaticBody3D.new()
	body.name = wall_name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("map_boundary_walls")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_boundary_root.add_child(body)


func _add_invisible_collision_box(box_name: String, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_collision_root.add_child(body)


func _add_bridge_void_kill_box(size: Vector3, position: Vector3) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "VoidKillMarker"
	var mesh := BoxMesh.new()
	mesh.size = size
	marker.mesh = mesh
	marker.position = position
	marker.visible = false
	_collision_root.add_child(marker)


func _add_marker_box(box_name: String, size: Vector3, position: Vector3, material: Material) -> void:
	var marker := MeshInstance3D.new()
	marker.name = box_name
	var mesh := BoxMesh.new()
	mesh.size = size
	marker.mesh = mesh
	marker.position = position
	marker.material_override = material
	_root.add_child(marker)


func _add_gate(left_pos: Vector3, right_pos: Vector3, accent: Material) -> void:
	_add_marker_box("GatePost", Vector3(0.28, 3.2, 0.28), left_pos, MAT_CONCRETE)
	_add_marker_box("GatePost", Vector3(0.28, 3.2, 0.28), right_pos, MAT_CONCRETE)
	var center := (left_pos + right_pos) * 0.5
	center.y = max(left_pos.y, right_pos.y) + 1.55
	var header_width: float = abs(right_pos.x - left_pos.x) + 0.8
	_add_marker_box("GateHeader", Vector3(header_width, 0.42, 0.42), center, accent)


func _add_omni(light_name: String, position: Vector3, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	_root.add_child(light)


func _make_child(child_name: String, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name = child_name
	parent.add_child(node)
	return node
