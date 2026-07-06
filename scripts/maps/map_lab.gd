@tool
extends Node3D

@export_group("Blueprint")
@export var blueprint_id: String = "bridge_lab_test":
	set(value):
		blueprint_id = value
		if Engine.is_editor_hint():
			call_deferred("_request_editor_rebuild")

@export_group("Editor Preview")
@export_tool_button("Rebuild Preview", "editor_rebuild_preview")
var _editor_rebuild_preview_button

@export_tool_button("Clear Preview", "editor_clear_preview")
var _editor_clear_preview_button

@export var auto_preview_in_editor: bool = true

@export_group("Preview Display")
@export var debug_visible: bool = true:
	set(value):
		debug_visible = value
		if Engine.is_editor_hint():
			call_deferred("_request_editor_rebuild")

@export var show_safe_floor: bool = false:
	set(value):
		show_safe_floor = value
		if Engine.is_editor_hint():
			call_deferred("_request_editor_rebuild")

@export var show_hazards: bool = true:
	set(value):
		show_hazards = value
		if Engine.is_editor_hint():
			call_deferred("_request_editor_rebuild")

@export_group("Runtime")
@export var rebuild_on_ready: bool = true

var _builder: MapKitBuilder = MapKitBuilder.new()
var _active_blueprint: MapBlueprint
var _map_root: Node3D
var _preview_root: Node3D
var _origin_marker: Node3D
var _editor_rebuild_pending: bool = false


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		return
	call_deferred("_maybe_auto_preview_in_editor")


func _ready() -> void:
	_preview_root = get_node_or_null("PreviewRoot") as Node3D
	if Engine.is_editor_hint():
		return
	if rebuild_on_ready:
		_rebuild_preview(false)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_R:
			_rebuild_preview(false)
		KEY_D:
			debug_visible = not debug_visible
			_apply_debug_flags()
		KEY_H:
			show_hazards = not show_hazards
			_rebuild_preview(false)
		KEY_F:
			show_safe_floor = not show_safe_floor
			_rebuild_preview(false)


func editor_rebuild_preview() -> void:
	if not Engine.is_editor_hint():
		return
	_rebuild_preview(true)


func editor_clear_preview() -> void:
	if not Engine.is_editor_hint():
		return
	_clear_preview_root(true)


func rebuild_current_blueprint() -> void:
	_rebuild_preview(Engine.is_editor_hint())


func _request_editor_rebuild() -> void:
	if not Engine.is_editor_hint():
		return
	if _editor_rebuild_pending:
		return
	_editor_rebuild_pending = true
	call_deferred("_run_pending_editor_rebuild")


func _run_pending_editor_rebuild() -> void:
	_editor_rebuild_pending = false
	if not Engine.is_editor_hint():
		return
	_rebuild_preview(true)


func _maybe_auto_preview_in_editor() -> void:
	if not Engine.is_editor_hint() or not auto_preview_in_editor:
		return
	_preview_root = _get_preview_root()
	if _preview_root == null:
		return
	if _preview_root.get_child_count() > 0:
		return
	_rebuild_preview(true)


func _rebuild_preview(is_editor: bool) -> void:
	if is_editor:
		print("MapLab: editor preview rebuild started")
	else:
		print("MapLab: runtime preview rebuild started")

	_preview_root = _get_preview_root()
	if _preview_root == null:
		push_warning("MapLab: PreviewRoot child is missing.")
		return

	_clear_preview_root(is_editor)

	_active_blueprint = _resolve_blueprint(blueprint_id)
	if _active_blueprint == null:
		push_warning("MapLab: unknown blueprint_id=%s" % blueprint_id)
		return

	print("MapLab: loaded blueprint %s" % blueprint_id)

	var validation: Dictionary = MapValidator.validate_blueprint(_active_blueprint)
	if bool(validation.get("ok", false)):
		print("MapLab: validation passed")
	else:
		print("MapLab: validation failed")
	MapValidator.print_validation_report(validation)
	if not bool(validation.get("ok", false)):
		push_warning("MapLab: blueprint '%s' failed validation." % blueprint_id)
		return

	_builder.set_debug_visible(debug_visible)
	_builder.set_show_safe_floor(show_safe_floor)
	_builder.set_show_hazards(show_hazards)
	_map_root = _builder.build_from_blueprint(_active_blueprint, _preview_root)
	_apply_debug_flags()
	_ensure_origin_marker(is_editor)

	if is_editor:
		_assign_editor_owners(_preview_root)

	_log_preview_counts(is_editor)

	var scene_validation: Dictionary = MapValidator.validate_generated_scene(_map_root, _active_blueprint)
	MapValidator.print_validation_report(scene_validation)
	print(
		"MapLab: built blueprint '%s' (%s)"
		% [blueprint_id, _active_blueprint.display_name]
	)


func _clear_preview_root(immediate: bool) -> void:
	_preview_root = _get_preview_root()
	if _preview_root == null:
		return

	print("MapLab: clearing PreviewRoot")
	var children: Array[Node] = _preview_root.get_children()
	for child in children:
		_preview_root.remove_child(child)
		if immediate or Engine.is_editor_hint():
			child.free()
		else:
			child.queue_free()
	_origin_marker = null
	print("MapLab: PreviewRoot children count = %d" % _preview_root.get_child_count())


func _get_preview_root() -> Node3D:
	if _preview_root != null and is_instance_valid(_preview_root):
		return _preview_root
	return get_node_or_null("PreviewRoot") as Node3D


func _ensure_origin_marker(is_editor: bool) -> void:
	_preview_root = _get_preview_root()
	if _preview_root == null:
		return

	if _origin_marker != null and is_instance_valid(_origin_marker):
		_origin_marker.queue_free()

	var marker_root := Node3D.new()
	marker_root.name = "MapLabOriginMarker"
	_preview_root.add_child(marker_root)
	if is_editor:
		var scene_root: Node = get_tree().edited_scene_root
		if scene_root != null:
			marker_root.owner = scene_root

	var cube := MeshInstance3D.new()
	cube.name = "OriginCube"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 1.2, 1.2)
	cube.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.2, 0.95, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.15, 0.9, 1.0)
	material.emission_energy_multiplier = 1.6
	cube.material_override = material
	cube.position = Vector3(0.0, 0.8, 0.0)
	marker_root.add_child(cube)

	var label := Label3D.new()
	label.name = "OriginLabel"
	label.text = "MAP LAB PREVIEW"
	label.font_size = 36
	label.outline_size = 8
	label.modulate = Color(1.0, 0.85, 0.2, 1.0)
	label.position = Vector3(0.0, 2.2, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker_root.add_child(label)

	if is_editor:
		_assign_editor_owners(marker_root)

	_origin_marker = marker_root


func _assign_editor_owners(root: Node) -> void:
	if not Engine.is_editor_hint():
		return
	var scene_root: Node = get_tree().edited_scene_root
	if scene_root == null or root == null:
		return
	_set_owner_recursive(root, scene_root)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node == null:
		return
	if node != self:
		node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)


func _log_preview_counts(is_editor: bool) -> void:
	_preview_root = _get_preview_root()
	if _preview_root == null:
		return

	var visual_layer: Node = _map_root.get_node_or_null("VisualLayer") if _map_root != null else null
	var gameplay_layer: Node = _map_root.get_node_or_null("GameplayLayer") if _map_root != null else null
	var visual_count: int = _count_descendants(visual_layer)
	var gameplay_count: int = _count_descendants(gameplay_layer)

	print("MapLab: PreviewRoot children count = %d" % _preview_root.get_child_count())
	print("MapLab: VisualLayer node count = %d" % visual_count)
	print("MapLab: GameplayLayer node count = %d" % gameplay_count)
	if is_editor:
		print("MapLab: editor preview rebuild finished")


func _count_descendants(node: Node) -> int:
	if node == null:
		return 0
	var count: int = 1
	for child in node.get_children():
		count += _count_descendants(child)
	return count


func _resolve_blueprint(requested_id: String) -> MapBlueprint:
	match requested_id:
		"bridge_lab_test":
			return BridgeLabTestBlueprint.create()
		_:
			return null


func _apply_debug_flags() -> void:
	_builder.set_debug_visible(debug_visible)
	if _map_root != null:
		var debug_layer: Node3D = _map_root.get_node_or_null("DebugLayer") as Node3D
		if debug_layer != null:
			debug_layer.visible = debug_visible
