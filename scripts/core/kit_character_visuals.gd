class_name KitCharacterVisuals
extends RefCounted

static func set_weapon_nodes_visible(root: Node, active_weapon_name: String = "", visible: bool = false) -> void:
	if root == null:
		return

	var node_3d: Node3D = root as Node3D
	if node_3d != null and _is_weapon_node_name(str(node_3d.name)):
		node_3d.visible = visible and str(node_3d.name) == active_weapon_name

	for child in root.get_children():
		set_weapon_nodes_visible(child, active_weapon_name, visible)

static func _is_weapon_node_name(node_name: String) -> bool:
	match node_name:
		"Axe", "Guitar", "Knife", "Pistol", "Rifle", "Shotgun", "SMG", "Spear", "WoodenBat_Barbed", "WoodenBat_Saw":
			return true

	var lower_name: String = node_name.to_lower()
	return (
		lower_name.contains("axe")
		or lower_name.contains("guitar")
		or lower_name.contains("knife")
		or lower_name.contains("pistol")
		or lower_name.contains("rifle")
		or lower_name.contains("shotgun")
		or lower_name.contains("smg")
		or lower_name.contains("spear")
		or lower_name.contains("bat")
	)
