extends Node

signal join_requested(display_name: String)
signal participant_registered(join_info: ParticipantJoinInfo, queued_count: int)
signal participant_queue_changed(display_names: PackedStringArray)
signal round_state_changed(state: String)
signal round_countdown_changed(seconds_remaining: int)
signal round_started(round_number: int)
signal round_reset()
signal round_ended(winner_name: String, base_won: bool)
signal round_stats_changed(stats: Dictionary)
signal zombie_spawned(zombie: Node)
signal zombie_died(zombie: Node, cause: String)
signal zombie_became_crawler(zombie: Node, cause: String)
signal zombie_survived_dismemberment(zombie: Node, cause: String)
signal zombie_reached_base(zombie: Node)
signal zombie_status_changed(display_name: String, status_text: String)
signal zombie_count_changed(living_count: int, total_count: int)
signal leader_changed(leader_name: String, progress: float)
signal command_text_changed(text: String)
signal chat_connection_status_changed(status_text: String, detail_text: String)
signal bits_cheer_received(display_name: String, bits_amount: int)
signal minigun_fired(target_name: String, hit: bool)
signal human_defender_fired(defender_name: String, target_name: String, hit: bool)
signal human_defender_died(defender_name: String)
signal mine_triggered(target_name: String, world_position: Vector3)
signal obstacle_triggered(target_name: String, obstacle_name: String, world_position: Vector3)
signal boost_pad_triggered(target_name: String, world_position: Vector3)
signal impact_mark_requested(world_position: Vector3, mark_type: String)
signal camera_shake_requested(strength: float, duration: float)
signal world_feedback_requested(world_position: Vector3, label_text: String, accent_color: Color)

var _reported_race_blockers: Dictionary = {}

func report_race_blocker(collider: Object, world_position: Vector3) -> void:
	var collider_node: Node = collider as Node
	if collider_node == null:
		return

	var collider_path: String = str(collider_node.get_path())
	if _is_expected_race_collider(collider_path):
		return
	if _reported_race_blockers.has(collider_path):
		return

	_reported_race_blockers[collider_path] = true
	push_warning("Zombie race blocker collision: %s at %s" % [collider_path, world_position])
	world_feedback_requested.emit(
		world_position + Vector3.UP * 1.35,
		"BLOCK?",
		Color(1.0, 0.12, 0.06, 1.0)
	)

func _is_expected_race_collider(collider_path: String) -> bool:
	if not collider_path.contains("/RoadArena/"):
		return false

	return (
		collider_path.ends_with("/Ground")
		or collider_path.ends_with("/Road")
		or collider_path.ends_with("/LeftRail")
		or collider_path.ends_with("/RightRail")
	)
