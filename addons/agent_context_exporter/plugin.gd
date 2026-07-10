@tool
extends EditorPlugin

const SNAPSHOT_SCRIPT := preload("res://scripts/debug/godot_project_snapshot.gd")


func _enter_tree() -> void:
	add_tool_menu_item("Export AI Project Snapshot", _export_snapshot)


func _exit_tree() -> void:
	remove_tool_menu_item("Export AI Project Snapshot")


func _export_snapshot() -> void:
	var editor := get_editor_interface()
	var snapshot: Dictionary = SNAPSHOT_SCRIPT.build_full_snapshot()
	snapshot["source"] = "editor_plugin"
	snapshot["open_scenes"] = _open_scene_paths(editor)
	snapshot["edited_scene_root"] = _edited_scene_root(editor)

	if not SNAPSHOT_SCRIPT._write_snapshot(snapshot):
		push_error("AgentContextExporter: could not write snapshot")
		return
	print("AgentContextExporter: wrote res://artifacts/godot_project_snapshot.json")


func _open_scene_paths(editor: EditorInterface) -> Array[String]:
	var paths: Array[String] = []
	for scene_path in editor.get_open_scenes():
		var trimmed: String = str(scene_path)
		if not trimmed.is_empty():
			paths.append(trimmed)
	return paths


func _edited_scene_root(editor: EditorInterface) -> Dictionary:
	var root: Node = editor.get_edited_scene_root()
	if root == null:
		return {}
	return {
		"name": root.name,
		"path": root.scene_file_path,
		"type": root.get_class(),
		"child_count": root.get_child_count(),
	}
