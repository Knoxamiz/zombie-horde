class_name AIGeneratedMapArena
extends Node3D

const AIMapBlueprintBuilderScript := preload("res://scripts/maps/ai_map_blueprint_builder.gd")
const AIMapBlueprintRegistryScript := preload("res://scripts/maps/ai_map_blueprint_registry.gd")
const AIMapCollisionAuditScript := preload("res://scripts/maps/ai_map_collision_audit.gd")
const VisualCollisionSanitizerScript := preload("res://scripts/core/visual_collision_sanitizer.gd")

@export var ai_blueprint_id: String = "phase1_bridge_ramp_test"

var _builder: RefCounted = AIMapBlueprintBuilderScript.new()
var _map_root: Node3D


func _ready() -> void:
	pass


func build_map() -> Node3D:
	_builder.clear_existing(self)

	var blueprint = _resolve_blueprint(ai_blueprint_id)
	if blueprint == null:
		push_error("AIGeneratedMapArena: unknown ai_blueprint_id=%s" % ai_blueprint_id)
		return null

	_map_root = _builder.build_prototype(self, blueprint)
	if _map_root == null:
		push_error("AIGeneratedMapArena: build_prototype failed for '%s'" % ai_blueprint_id)
		return null

	_sanitize_visual_layer_collision()
	AIMapCollisionAuditScript.ensure_gameplay_collision_enabled(_map_root)
	print("AIGeneratedMapArena: built '%s' (%s)" % [ai_blueprint_id, blueprint.display_name])
	return _map_root


func _sanitize_visual_layer_collision() -> void:
	if _map_root == null:
		return
	var visual_layer: Node = _map_root.get_node_or_null("VisualLayer")
	if visual_layer != null:
		VisualCollisionSanitizerScript.sanitize_subtree(visual_layer)


func get_map_root() -> Node3D:
	return _map_root


func get_ai_blueprint_id() -> String:
	return ai_blueprint_id


static func _resolve_blueprint(blueprint_id: String):
	return AIMapBlueprintRegistryScript.resolve_blueprint(blueprint_id)
