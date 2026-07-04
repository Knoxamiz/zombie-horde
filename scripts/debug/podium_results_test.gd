extends SceneTree

const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Podium results builder test ===")

	var stats: Dictionary = {
		"runner_up_results": [
			{
				"display_name": "Second",
				"progress": 0.82,
				"alive": false,
				"tier": ParticipantJoinInfo.SupporterTier.SUBSCRIBER,
				"tier_label": "Subscriber",
			},
			{
				"display_name": "Third",
				"progress": 0.71,
				"alive": false,
				"tier": ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT,
				"tier_label": "Gift Sub",
			},
		]
	}

	var zombie_win: Array[Dictionary] = PodiumResultsBuilder.build_top_three("Winner", false, stats)
	if zombie_win.size() != 3:
		push_error("Zombie win podium should have three entries")
		quit(FAIL)
		return
	if int(zombie_win[0].get("position", 0)) != 1 or str(zombie_win[0].get("display_name", "")) != "Winner":
		push_error("First place should be the winning zombie")
		quit(FAIL)
		return

	var base_stats: Dictionary = {
		"runner_up_results": [
			{"display_name": "Closest", "progress": 0.91, "alive": false, "tier": 0, "tier_label": "Viewer"},
			{"display_name": "Middle", "progress": 0.76, "alive": false, "tier": 1, "tier_label": "Subscriber"},
			{"display_name": "Last", "progress": 0.63, "alive": false, "tier": 2, "tier_label": "Gift Sub"},
		]
	}
	var base_win: Array[Dictionary] = PodiumResultsBuilder.build_top_three("Streamer Base", true, base_stats)
	if base_win.size() != 3:
		push_error("Base win podium should have three entries")
		quit(FAIL)
		return
	if str(base_win[0].get("display_name", "")) != "Closest":
		push_error("Base win first place should be closest zombie")
		quit(FAIL)
		return

	var display_order: Array[Dictionary] = PodiumResultsBuilder.get_podium_display_order(zombie_win)
	if display_order.size() != 3:
		push_error("Display order should preserve all podium entries")
		quit(FAIL)
		return
	if int(display_order[1].get("position", 0)) != 1:
		push_error("Center podium slot should be first place")
		quit(FAIL)
		return

	print("PASS: podium results builder orders top three correctly")
	quit(PASS)
