class_name JoinSourceHub
extends JoinSource

@export var source_parent_path: NodePath = NodePath("..")

var _sources: Array[JoinSource] = []

func _ready() -> void:
	_wire_sources_from_parent()

func get_debug_source() -> DebugJoinSource:
	for source in _sources:
		var debug_source: DebugJoinSource = source as DebugJoinSource
		if debug_source != null:
			return debug_source
	return null

func _wire_sources_from_parent() -> void:
	var source_parent: Node = get_node_or_null(source_parent_path)
	if source_parent == null:
		return

	for child in source_parent.get_children():
		if child == self:
			continue

		var source: JoinSource = child as JoinSource
		if source != null:
			_register_source(source)

func _register_source(source: JoinSource) -> void:
	if _sources.has(source):
		return

	_sources.append(source)
	source.participant_join_requested.connect(_on_source_participant_join_requested)

func _on_source_participant_join_requested(display_name: String) -> void:
	submit_join(display_name)

