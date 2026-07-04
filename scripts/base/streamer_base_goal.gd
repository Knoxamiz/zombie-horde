class_name StreamerBaseGoal
extends Area3D

@export var goal_enabled: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func set_goal_enabled(enabled: bool) -> void:
	goal_enabled = enabled
	monitoring = enabled

func _on_body_entered(body: Node3D) -> void:
	if not goal_enabled:
		return

	var zombie: Zombie = body as Zombie
	if zombie == null or not zombie.is_alive() or zombie.has_finished_race():
		return

	GameEvents.zombie_reached_base.emit(zombie)

