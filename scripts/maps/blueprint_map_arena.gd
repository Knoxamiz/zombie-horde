class_name BlueprintMapArena
extends Node3D

@export var blueprint_id: String = "bridge_lab_test"
@export var build_on_ready: bool = true
@export var show_debug_layer: bool = false
@export var show_safe_floor_debug: bool = false
@export var show_hazard_debug: bool = false

var _builder: MapKitBuilder = MapKitBuilder.new()
var _map_root: Node3D


func _ready() -> void:
	if build_on_ready:
		build_map()


func build_map() -> Node3D:
	_builder.clear_existing_generated_map(self)

	var blueprint: MapBlueprint = _resolve_blueprint(blueprint_id)
	if blueprint == null:
		push_warning("BlueprintMapArena: unknown blueprint_id=%s" % blueprint_id)
		return null

	var validation: Dictionary = MapValidator.validate_blueprint(blueprint)
	if bool(validation.get("ok", false)):
		print("BlueprintMapArena: validation passed for %s" % blueprint_id)
	else:
		print("BlueprintMapArena: validation failed for %s" % blueprint_id)
	MapValidator.print_validation_report(validation)
	if not bool(validation.get("ok", false)):
		push_warning("BlueprintMapArena: refusing to build invalid blueprint '%s'." % blueprint_id)
		return null

	_builder.set_debug_visible(show_debug_layer)
	_builder.set_show_debug_grid(false)
	_builder.set_show_safe_floor(show_safe_floor_debug)
	_builder.set_show_hazards(show_hazard_debug)
	_map_root = _builder.build_from_blueprint(blueprint, self)
	if _map_root == null:
		return null

	if not show_debug_layer:
		var debug_layer: Node3D = _map_root.get_node_or_null("DebugLayer") as Node3D
		if debug_layer != null:
			debug_layer.visible = false

	var scene_validation: Dictionary = MapValidator.validate_generated_scene(_map_root, blueprint)
	MapValidator.print_validation_report(scene_validation)
	print("BlueprintMapArena: built '%s' (%s)" % [blueprint_id, blueprint.display_name])
	return _map_root


func get_map_root() -> Node3D:
	return _map_root


func _resolve_blueprint(requested_id: String) -> MapBlueprint:
	match requested_id:
		"bridge_lab_test":
			return BridgeLabTestBlueprint.create()
		_:
			return null
