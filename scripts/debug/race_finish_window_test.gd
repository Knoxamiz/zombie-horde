extends SceneTree

const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Race finish window test ===")

	var first: Dictionary = {
		"display_name": "Winner",
		"progress": 1.0,
		"finish_place": 1,
	}
	var second: Dictionary = {
		"display_name": "Runner",
		"progress": 0.99,
		"finish_place": 2,
	}
	var crawler: Dictionary = {
		"display_name": "Crawler",
		"progress": 0.88,
		"finish_place": 0,
	}

	var sorted: Array[Dictionary] = [crawler, second, first]
	sorted.sort_custom(_sort_result_by_progress)
	if str(sorted[0].get("display_name", "")) != "Winner":
		push_error("Finish place should outrank raw progress")
		quit(FAIL)
		return

	var podium: Array[Dictionary] = PodiumResultsBuilder.build_top_three(
		"Winner",
		false,
		{
			"runner_up_results": [
				second,
				crawler,
			]
		}
	)
	if podium.size() != 3 or str(podium[0].get("display_name", "")) != "Winner":
		push_error("Podium should keep the first finisher in first place")
		quit(FAIL)
		return

	print("PASS: finish ordering for podium results works")
	quit(PASS)


func _sort_result_by_progress(a: Dictionary, b: Dictionary) -> bool:
	var a_place: int = int(a.get("finish_place", 0))
	var b_place: int = int(b.get("finish_place", 0))
	if a_place > 0 and b_place > 0:
		return a_place < b_place
	if a_place > 0:
		return true
	if b_place > 0:
		return false
	return float(a.get("progress", 0.0)) > float(b.get("progress", 0.0))
