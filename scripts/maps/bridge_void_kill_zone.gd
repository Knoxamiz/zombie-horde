class_name BridgeVoidKillZone
extends Area3D

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	var zombie: Zombie = body as Zombie
	if zombie == null or not zombie.is_alive():
		return
	zombie.kill("out_of_bounds")
