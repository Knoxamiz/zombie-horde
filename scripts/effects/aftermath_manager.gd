class_name AftermathManager
extends Node3D

@export var road_mark_scene: PackedScene
@export_range(0, 256, 1) var max_marks: int = 96
@export var road_y: float = 0.135

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _marks: Array[Node3D] = []

func _ready() -> void:
	_rng.randomize()
	GameEvents.impact_mark_requested.connect(_on_impact_mark_requested)
	GameEvents.round_started.connect(_on_round_started)
	GameEvents.round_reset.connect(clear_marks)

func clear_marks() -> void:
	for mark in _marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_marks.clear()

func _on_round_started(_round_number: int) -> void:
	clear_marks()

func _on_impact_mark_requested(world_position: Vector3, mark_type: String) -> void:
	if road_mark_scene == null:
		return

	var mark: RoadMark = road_mark_scene.instantiate() as RoadMark
	if mark == null:
		return

	add_child(mark)
	mark.global_position = Vector3(world_position.x, road_y, world_position.z)
	mark.configure(mark_type, int(_rng.randi()))
	_marks.append(mark)
	_trim_marks()

func _trim_marks() -> void:
	while _marks.size() > max_marks:
		var oldest_mark: Node3D = _marks.pop_front()
		if is_instance_valid(oldest_mark):
			oldest_mark.queue_free()
