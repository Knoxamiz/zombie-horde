extends SceneTree

const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Map Lab material UID smoke test ===")
	var builder := MapKitBuilder.new()
	var blueprint: MapBlueprint = BridgeLabTestBlueprint.create()
	var root := Node3D.new()
	root.name = "MapLabUidSmokeRoot"
	var built: Node3D = builder.build_from_blueprint(blueprint, root)
	if built == null:
		push_error("build_from_blueprint returned null")
		quit(FAIL)
		return

	var gameplay: Node3D = built.get_node_or_null("GameplayLayer") as Node3D
	if gameplay == null:
		push_error("GameplayLayer missing")
		quit(FAIL)
		return

	for material_path in [
		"res://assets/materials/spawn_zone.tres",
		"res://assets/materials/goal_zone.tres",
		"res://assets/materials/road_asphalt.tres",
		"res://assets/materials/obstacle_warning.tres",
	]:
		var uid_text: String = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(material_path))
		if uid_text == "uid://<invalid>":
			push_error("Missing UID for %s" % material_path)
			quit(FAIL)
			return
		print("OK %s -> %s" % [material_path, uid_text])

	print("PASS: bridge_lab_test built with stable material UIDs")
	quit(PASS)
