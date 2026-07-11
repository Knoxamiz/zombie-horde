class_name MapKitLayoutPresets
extends RefCounted

## Authored route presets for hazard-kit maps. Each preset defines a unique path shape.


static func get_preset(preset_id: String) -> Dictionary:
	match preset_id:
		"broken_bridge":
			return _broken_bridge()
		"mine_alley":
			return _mine_alley()
		"cone_slalom":
			return _cone_slalom()
		"vehicle_yard":
			return _vehicle_yard()
		"defender_gauntlet":
			return _defender_gauntlet()
		"boost_rush":
			return _boost_rush()
		_:
			push_warning("MapKitLayoutPresets: unknown preset '%s', using broken_bridge" % preset_id)
			return _broken_bridge()


static func _broken_bridge() -> Dictionary:
	var road_width: float = 9.0
	# 20 ft minimum clearance above water (1 ft margin for deck thickness).
	const FEET_TO_METERS: float = 0.3048
	const MIN_CLEARANCE_FT: float = 20.0
	var water_y: float = 0.0
	var deck_elevation: float = MIN_CLEARANCE_FT * FEET_TO_METERS + 0.35
	return {
		"style": RaceMapKit.MapStyle.BROKEN_BRIDGE,
		"seed": 8802,
		"deck_elevation": deck_elevation,
		"water_y": water_y,
		"bed_y": water_y - 2.75,
		"path_half_width": 4.5,
		"visual_width": 8.0,
		"void_width": 64.0,
		"track_length": 192.0,
		"spawn_z": -84.0,
		"goal_z": 84.0,
		"start_gate_z": -76.0,
		"finish_gate_z": 76.0,
		"segments": [
			{"z0": -84.0, "z1": -48.0},
			{"z0": -40.0, "z1": -8.0},
			{"z0": 0.0, "z1": 32.0},
			{"z0": 40.0, "z1": 84.0},
		],
		"gaps": [
			{"z0": -48.0, "z1": -40.0},
			{"z0": -8.0, "z1": 0.0},
			{"z0": 32.0, "z1": 40.0},
		],
		# Narrow plank (~38% of deck). Wider ratios let the full play lane walk across gaps.
		"gap_crossing_width_ratio": 0.38,
		"spawn_chute_half_width": 5.0,
		"surface_pieces": [
			{"shape": "deck", "z0": -84.0, "z1": -48.0, "top_y": 0.0, "width": road_width},
			{"shape": "ramp", "z0": -40.0, "z1": -32.0, "start_y": 0.0, "height_delta": 0.35, "width": road_width},
			{"shape": "deck", "z0": -32.0, "z1": -8.0, "top_y": 0.35, "width": road_width},
			{"shape": "deck", "z0": 0.0, "z1": 32.0, "top_y": 0.35, "width": road_width},
			{"shape": "ramp", "z0": 40.0, "z1": 48.0, "start_y": 0.35, "height_delta": -0.35, "width": road_width},
			{"shape": "deck", "z0": 48.0, "z1": 84.0, "top_y": 0.0, "width": road_width},
		],
	}


static func _mine_alley() -> Dictionary:
	var road_width: float = 11.0
	return {
		"style": RaceMapKit.MapStyle.LONG_ROAD,
		"seed": 4104,
		"path_half_width": 5.5,
		"visual_width": 11.0,
		"void_width": 48.0,
		"track_length": 176.0,
		"spawn_z": -76.0,
		"goal_z": 76.0,
		"start_gate_z": -68.0,
		"finish_gate_z": 68.0,
		"segments": [
			{"z0": -76.0, "z1": 76.0},
		],
		"gaps": [],
		"surface_pieces": [
			{"shape": "deck", "z0": -76.0, "z1": -40.0, "top_y": 0.0, "width": road_width},
			{"shape": "ramp", "z0": -40.0, "z1": -32.0, "start_y": 0.0, "height_delta": 0.8, "width": road_width},
			{"shape": "deck", "z0": -32.0, "z1": 32.0, "top_y": 0.8, "width": road_width},
			{"shape": "ramp", "z0": 32.0, "z1": 40.0, "start_y": 0.8, "height_delta": -0.8, "width": road_width},
			{"shape": "deck", "z0": 40.0, "z1": 76.0, "top_y": 0.0, "width": road_width},
		],
	}


static func _cone_slalom() -> Dictionary:
	var road_width: float = 14.0
	return {
		"style": RaceMapKit.MapStyle.LONG_ROAD,
		"seed": 5205,
		"path_half_width": 7.0,
		"visual_width": 18.0,
		"void_width": 56.0,
		"track_length": 200.0,
		"spawn_z": -88.0,
		"goal_z": 88.0,
		"start_gate_z": -80.0,
		"finish_gate_z": 80.0,
		"segments": [
			{"z0": -88.0, "z1": -56.0},
			{"z0": -48.0, "z1": -16.0},
			{"z0": -8.0, "z1": 24.0},
			{"z0": 32.0, "z1": 64.0},
			{"z0": 72.0, "z1": 88.0},
		],
		"gaps": [
			{"z0": -56.0, "z1": -48.0},
			{"z0": -16.0, "z1": -8.0},
			{"z0": 24.0, "z1": 32.0},
			{"z0": 64.0, "z1": 72.0},
		],
		"surface_pieces": [
			{"shape": "deck", "z0": -88.0, "z1": -56.0, "top_y": 0.0, "width": road_width},
			{"shape": "ramp", "z0": -56.0, "z1": -48.0, "start_y": 0.0, "height_delta": 0.5, "width": road_width},
			{"shape": "deck", "z0": -48.0, "z1": -16.0, "top_y": 0.5, "width": road_width},
			{"shape": "ramp", "z0": -16.0, "z1": -8.0, "start_y": 0.5, "height_delta": -0.5, "width": road_width},
			{"shape": "deck", "z0": -8.0, "z1": 24.0, "top_y": 0.0, "width": road_width},
			{"shape": "ramp", "z0": 24.0, "z1": 32.0, "start_y": 0.0, "height_delta": 0.6, "width": road_width},
			{"shape": "deck", "z0": 32.0, "z1": 64.0, "top_y": 0.6, "width": road_width},
			{"shape": "ramp", "z0": 64.0, "z1": 72.0, "start_y": 0.6, "height_delta": -0.6, "width": road_width},
			{"shape": "deck", "z0": 72.0, "z1": 88.0, "top_y": 0.0, "width": road_width},
		],
	}


static func _vehicle_yard() -> Dictionary:
	var road_width: float = 17.0
	return {
		"style": RaceMapKit.MapStyle.BROKEN_BRIDGE,
		"seed": 6306,
		"path_half_width": 8.5,
		"visual_width": 14.0,
		"void_width": 72.0,
		"track_length": 200.0,
		"spawn_z": -88.0,
		"goal_z": 88.0,
		"start_gate_z": -80.0,
		"finish_gate_z": 80.0,
		"segments": [
			{"z0": -88.0, "z1": -28.0},
			{"z0": 12.0, "z1": 88.0},
		],
		"gaps": [
			{"z0": -28.0, "z1": 12.0},
		],
		"surface_pieces": [
			{"shape": "deck", "z0": -88.0, "z1": -28.0, "top_y": 1.2, "width": road_width},
			{"shape": "deck", "z0": 12.0, "z1": 88.0, "top_y": 1.2, "width": road_width},
		],
	}


static func _defender_gauntlet() -> Dictionary:
	var road_width: float = 10.0
	return {
		"style": RaceMapKit.MapStyle.BROKEN_BRIDGE,
		"seed": 7407,
		"path_half_width": 5.0,
		"visual_width": 9.0,
		"void_width": 60.0,
		"track_length": 184.0,
		"spawn_z": -84.0,
		"goal_z": 84.0,
		"start_gate_z": -76.0,
		"finish_gate_z": 76.0,
		"segments": [
			{"z0": -84.0, "z1": -64.0},
			{"z0": -56.0, "z1": -36.0},
			{"z0": -28.0, "z1": -8.0},
			{"z0": 4.0, "z1": 24.0},
			{"z0": 36.0, "z1": 56.0},
			{"z0": 68.0, "z1": 84.0},
		],
		"gaps": [
			{"z0": -64.0, "z1": -56.0},
			{"z0": -36.0, "z1": -28.0},
			{"z0": -8.0, "z1": 4.0},
			{"z0": 24.0, "z1": 36.0},
			{"z0": 56.0, "z1": 68.0},
		],
		"surface_pieces": [
			{"shape": "deck", "z0": -84.0, "z1": -64.0, "top_y": 0.45, "width": road_width},
			{"shape": "deck", "z0": -56.0, "z1": -36.0, "top_y": 0.45, "width": road_width},
			{"shape": "deck", "z0": -28.0, "z1": -8.0, "top_y": 0.45, "width": road_width},
			{"shape": "deck", "z0": 4.0, "z1": 24.0, "top_y": 0.45, "width": road_width},
			{"shape": "deck", "z0": 36.0, "z1": 56.0, "top_y": 0.45, "width": road_width},
			{"shape": "deck", "z0": 68.0, "z1": 84.0, "top_y": 0.45, "width": road_width},
		],
	}


static func _boost_rush() -> Dictionary:
	var road_width: float = 18.0
	return {
		"style": RaceMapKit.MapStyle.LONG_ROAD,
		"seed": 8508,
		"path_half_width": 9.0,
		"visual_width": 22.0,
		"void_width": 64.0,
		"track_length": 208.0,
		"spawn_z": -92.0,
		"goal_z": 92.0,
		"start_gate_z": -84.0,
		"finish_gate_z": 84.0,
		"segments": [
			{"z0": -92.0, "z1": 92.0},
		],
		"gaps": [],
		"surface_pieces": [
			{"shape": "deck", "z0": -92.0, "z1": -58.0, "top_y": 0.0, "width": road_width},
			{"shape": "ramp", "z0": -58.0, "z1": -50.0, "start_y": 0.0, "height_delta": -1.0, "width": road_width},
			{"shape": "deck", "z0": -50.0, "z1": 50.0, "top_y": -1.0, "width": road_width},
			{"shape": "ramp", "z0": 50.0, "z1": 58.0, "start_y": -1.0, "height_delta": 1.0, "width": road_width},
			{"shape": "deck", "z0": 58.0, "z1": 92.0, "top_y": 0.0, "width": road_width},
		],
	}
