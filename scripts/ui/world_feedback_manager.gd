class_name WorldFeedbackManager
extends Node3D

@export var feedback_label_scene: PackedScene

func _ready() -> void:
	GameEvents.world_feedback_requested.connect(_on_world_feedback_requested)

func _on_world_feedback_requested(world_position: Vector3, label_text: String, accent_color: Color) -> void:
	if feedback_label_scene == null:
		return

	var feedback_label: WorldFeedbackLabel = feedback_label_scene.instantiate() as WorldFeedbackLabel
	if feedback_label == null:
		return

	add_child(feedback_label)
	feedback_label.global_position = world_position
	feedback_label.configure(label_text, accent_color)

