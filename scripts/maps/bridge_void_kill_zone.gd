## Deprecated: map void kill zones are visual markers only.
## Authoritative fall/OOB death is handled by Zombie._check_out_of_bounds().
class_name BridgeVoidKillZone
extends Area3D

func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
