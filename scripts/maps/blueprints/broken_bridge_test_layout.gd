class_name BrokenBridgeTestLayout
extends RefCounted

const BRIDGE_DECK_Y: float = 4.0
const ZOMBIE_SPAWN_CLEARANCE: float = 0.8
const ZOMBIE_SPAWN_Y: float = BRIDGE_DECK_Y + ZOMBIE_SPAWN_CLEARANCE
const FLOOR_THICKNESS: float = 0.16
const RIVER_VOID_Y: float = 0.0
const WATER_SURFACE_THICKNESS: float = 0.08
const WATER_WIDTH_SCALE: float = 20.0
const PILLAR_EDGE_X: float = 6.8
const PILLAR_SPACING_Z: float = 14.0
const PILLAR_SIZE: float = 1.05
const PARAPET_HEIGHT: float = 1.05
const PARAPET_THICKNESS: float = 0.22


static func get_safe_floor_body_y() -> float:
	return BRIDGE_DECK_Y - FLOOR_THICKNESS * 0.5


static func get_spawn_origin() -> Vector3:
	return Vector3(0.0, ZOMBIE_SPAWN_Y, -44.0)


static func get_goal_position() -> Vector3:
	return Vector3(0.0, ZOMBIE_SPAWN_Y, 44.0)


static func get_base_position() -> Vector3:
	return Vector3(0.0, BRIDGE_DECK_Y, 44.0)


static func get_minigun_position() -> Vector3:
	return Vector3(0.0, BRIDGE_DECK_Y, 40.0)
