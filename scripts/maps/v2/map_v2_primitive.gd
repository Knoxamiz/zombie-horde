class_name MapV2Primitive
extends Resource

## One authoritative gray-box course primitive. The V2 builder derives both
## visible playable geometry and gameplay collision from these exact values.

enum Kind {
	DECK,
	RAMP,
	GAP,
	BOUNDARY,
}

@export var primitive_id: String = ""
@export var kind: Kind = Kind.DECK
@export var origin: Vector3 = Vector3.ZERO
@export var width: float = 8.0
@export var length: float = 8.0
@export var height_delta: float = 0.0
@export var thickness: float = 0.12
@export var visual_color: Color = Color("777f8c")


func validate() -> PackedStringArray:
	var failures := PackedStringArray()
	if primitive_id.strip_edges().is_empty():
		failures.append("primitive_id is empty")
	if width <= 0.0:
		failures.append("%s width must be positive" % primitive_id)
	if length <= 0.0:
		failures.append("%s length must be positive" % primitive_id)
	if thickness <= 0.0:
		failures.append("%s thickness must be positive" % primitive_id)
	if kind != Kind.RAMP and absf(height_delta) > 0.001:
		failures.append("%s height_delta is only valid for ramps" % primitive_id)
	return failures
