extends Node3D

@export var blueprint_id: String = "bridge_lab_test"
@export var debug_visible: bool = false
@export var show_safe_floor: bool = false
@export var show_hazards: bool = false
@export var rebuild_on_ready: bool = true

var _builder: MapKitBuilder = MapKitBuilder.new()
var _active_blueprint: MapBlueprint
var _map_root: Node3D


func _ready() -> void:
	if rebuild_on_ready:
		rebuild_current_blueprint()


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_R:
			rebuild_current_blueprint()
		KEY_D:
			debug_visible = not debug_visible
			_apply_debug_flags()
		KEY_H:
			show_hazards = not show_hazards
			rebuild_current_blueprint()
		KEY_F:
			show_safe_floor = not show_safe_floor
			rebuild_current_blueprint()


func rebuild_current_blueprint() -> void:
	_active_blueprint = _resolve_blueprint(blueprint_id)
	if _active_blueprint == null:
		push_warning("MapLab: unknown blueprint_id=%s" % blueprint_id)
		return

	var validation: Dictionary = MapValidator.validate_blueprint(_active_blueprint)
	MapValidator.print_validation_report(validation)
	if not bool(validation.get("ok", false)):
		push_warning("MapLab: blueprint '%s' failed validation." % blueprint_id)
		return

	_builder.set_debug_visible(debug_visible)
	_builder.set_show_safe_floor(show_safe_floor)
	_builder.set_show_hazards(show_hazards)
	_map_root = _builder.build_from_blueprint(_active_blueprint, self)
	_apply_debug_flags()

	var scene_validation: Dictionary = MapValidator.validate_generated_scene(_map_root, _active_blueprint)
	MapValidator.print_validation_report(scene_validation)
	print("MapLab: built blueprint '%s' (%s)" % [blueprint_id, _active_blueprint.display_name])


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
