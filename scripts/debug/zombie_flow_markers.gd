class_name ZombieFlowMarkers
extends Node3D

enum MarkerKind {
	SPAWN,
	FINISH,
	DEATH,
	STUCK,
	HAZARD,
}

const MARKER_COLORS: Dictionary = {
	MarkerKind.SPAWN: Color(0.2, 0.45, 1.0, 0.92),
	MarkerKind.FINISH: Color(0.15, 0.9, 0.25, 0.92),
	MarkerKind.DEATH: Color(0.95, 0.15, 0.12, 0.92),
	MarkerKind.STUCK: Color(0.98, 0.86, 0.1, 0.92),
	MarkerKind.HAZARD: Color(0.62, 0.2, 0.95, 0.92),
}

const MARKER_RADIUS: float = 0.28
const MARKER_HEIGHT: float = 0.12

var _markers_visible: bool = true


func set_markers_visible(visible: bool) -> void:
	_markers_visible = visible
	for child in get_children():
		if child is Node3D:
			child.visible = visible


func are_markers_visible() -> bool:
	return _markers_visible


func clear_markers() -> void:
	var children: Array[Node] = []
	for child in get_children():
		children.append(child)
	for child in children:
		remove_child(child)
		child.free()


func add_marker(world_position: Vector3, kind: MarkerKind) -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = "FlowMarker_%s_%d" % [_kind_name(kind), get_child_count() + 1]
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = _markers_visible

	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = MARKER_RADIUS
	mesh.bottom_radius = MARKER_RADIUS
	mesh.height = MARKER_HEIGHT
	marker.mesh = mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = MARKER_COLORS.get(kind, Color.WHITE)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	marker.material_override = material

	marker.position = world_position + Vector3.UP * (MARKER_HEIGHT * 0.5 + 0.04)
	add_child(marker)


func _kind_name(kind: MarkerKind) -> String:
	match kind:
		MarkerKind.SPAWN:
			return "spawn"
		MarkerKind.FINISH:
			return "finish"
		MarkerKind.DEATH:
			return "death"
		MarkerKind.STUCK:
			return "stuck"
		MarkerKind.HAZARD:
			return "hazard"
	return "marker"
