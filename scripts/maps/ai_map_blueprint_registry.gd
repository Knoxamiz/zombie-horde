class_name AIMapBlueprintRegistry
extends RefCounted

const Phase1BridgeRampTestBlueprint := preload(
	"res://scripts/maps/blueprints/phase1_bridge_ramp_test.gd"
)
const Phase2DropGapProbeBlueprint := preload(
	"res://scripts/maps/blueprints/phase2_drop_gap_probe.gd"
)
const SignatureDropBridgeBlueprint := preload(
	"res://scripts/maps/blueprints/signature_drop_bridge.gd"
)

const PROTOTYPE_ENTRIES: Array[Dictionary] = [
	{
		"blueprint_id": "phase1_bridge_ramp_test",
		"generated_map_id": "ai_generated_phase1_bridge_ramp_test",
		"scene_path": "res://scenes/maps/ai_generated_phase1_bridge_ramp_test.tscn",
		"definition_path": "res://resources/maps/ai_generated_phase1_bridge_ramp_test.tres",
	},
	{
		"blueprint_id": "phase2_drop_gap_probe",
		"generated_map_id": "ai_generated_phase2_drop_gap_probe",
		"scene_path": "res://scenes/maps/ai_generated_phase2_drop_gap_probe.tscn",
		"definition_path": "res://resources/maps/ai_generated_phase2_drop_gap_probe.tres",
	},
	{
		"blueprint_id": "signature_drop_bridge",
		"generated_map_id": "ai_generated_signature_drop_bridge",
		"scene_path": "res://scenes/maps/ai_generated_signature_drop_bridge.tscn",
		"definition_path": "res://resources/maps/ai_generated_signature_drop_bridge.tres",
	},
]


static func get_all_entries() -> Array[Dictionary]:
	return PROTOTYPE_ENTRIES.duplicate(true)


static func get_all_blueprint_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in PROTOTYPE_ENTRIES:
		ids.append(str(entry.get("blueprint_id", "")))
	return ids


static func get_all_generated_map_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in PROTOTYPE_ENTRIES:
		ids.append(str(entry.get("generated_map_id", "")))
	return ids


static func get_entry_by_blueprint_id(blueprint_id: String) -> Dictionary:
	var trimmed: String = blueprint_id.strip_edges()
	for entry in PROTOTYPE_ENTRIES:
		if str(entry.get("blueprint_id", "")) == trimmed:
			return entry.duplicate(true)
	return {}


static func get_entry_by_generated_map_id(generated_map_id: String) -> Dictionary:
	var trimmed: String = generated_map_id.strip_edges()
	for entry in PROTOTYPE_ENTRIES:
		if str(entry.get("generated_map_id", "")) == trimmed:
			return entry.duplicate(true)
	return {}


static func resolve_blueprint(blueprint_id: String):
	var trimmed: String = blueprint_id.strip_edges()
	match trimmed:
		"phase1_bridge_ramp_test":
			return Phase1BridgeRampTestBlueprint.create()
		"phase2_drop_gap_probe":
			return Phase2DropGapProbeBlueprint.create()
		"signature_drop_bridge":
			return SignatureDropBridgeBlueprint.create()
		_:
			return null


static func resolve_blueprint_for_generated_map(generated_map_id: String):
	var entry: Dictionary = get_entry_by_generated_map_id(generated_map_id)
	if entry.is_empty():
		return null
	return resolve_blueprint(str(entry.get("blueprint_id", "")))
