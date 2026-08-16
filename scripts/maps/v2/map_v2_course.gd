class_name MapV2Course
extends Resource

const PRIMITIVE_SCRIPT := preload("res://scripts/maps/v2/map_v2_primitive.gd")

@export var course_id: String = ""
@export var primitives: Array[Resource] = []


func validate() -> PackedStringArray:
	var failures := PackedStringArray()
	if course_id.strip_edges().is_empty():
		failures.append("course_id is empty")
	if primitives.is_empty():
		failures.append("%s has no primitives" % course_id)
	var seen_ids: Dictionary = {}
	for primitive in primitives:
		if primitive == null:
			failures.append("%s contains a null primitive" % course_id)
			continue
		failures.append_array(primitive.validate())
		if seen_ids.has(primitive.primitive_id):
			failures.append("duplicate primitive_id: %s" % primitive.primitive_id)
		seen_ids[primitive.primitive_id] = true
	return failures
