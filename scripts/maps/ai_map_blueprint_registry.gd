class_name AIMapBlueprintRegistry
extends RefCounted

## Blueprint registry for future AI-generated maps.
## No prototype maps are registered until real maps are authored and exported.

const PROTOTYPE_ENTRIES: Array[Dictionary] = []


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


static func resolve_blueprint(_blueprint_id: String):
	return null


static func resolve_blueprint_for_generated_map(_generated_map_id: String):
	return null
