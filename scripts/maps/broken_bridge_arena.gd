class_name BrokenBridgeArena
extends Node3D

const PLAY_WIDTH: float = 32.0
const VISUAL_WIDTH: float = 12.0
const VOID_WIDTH: float = 64.0
const TRACK_LENGTH: float = 192.0
const SPAWN_Z: float = -84.0
const GOAL_Z: float = 84.0

const KIT_SCRIPT := preload("res://scripts/maps/race_map_kit.gd")

var _segments: Array[Dictionary] = [
	{"z0": -84.0, "z1": -48.0},
	{"z0": -40.0, "z1": -8.0},
	{"z0": 0.0, "z1": 32.0},
	{"z0": 40.0, "z1": 84.0},
]

var _gaps: Array[Dictionary] = [
	{"z0": -48.0, "z1": -40.0},
	{"z0": -8.0, "z1": 0.0},
	{"z0": 32.0, "z1": 40.0},
]

var _kit: RaceMapKit


func _ready() -> void:
	_kit = KIT_SCRIPT.new()
	_kit.attach(self, RaceMapKit.MapStyle.BROKEN_BRIDGE, 8802)
	_kit.build_environment()
	_kit.build_water(VOID_WIDTH, TRACK_LENGTH)
	_kit.build_continuous_play_surface(PLAY_WIDTH, -84.0, 84.0)
	_kit.compose_map(_segments, _gaps)
	_kit.build_markers(VISUAL_WIDTH, SPAWN_Z, GOAL_Z, -76.0, 76.0)
