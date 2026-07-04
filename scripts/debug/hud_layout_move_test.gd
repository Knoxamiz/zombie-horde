extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== HUD layout move test ===")
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		_finish(FAIL)
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.5).timeout

	var hud: HudController = main_game.get_node_or_null("HUD") as HudController
	if hud == null:
		_fail("HUD not found")
		_finish(FAIL)
		return

	hud.visible = true
	hud.get_node("Root").visible = true
	await create_timer(0.1).timeout

	var panel: HudLayoutPanel = hud.get_layout_panel("top")
	if panel == null:
		_fail("Top panel not found")
		_finish(FAIL)
		return

	var start: Vector2 = panel.get_layout_rect().position
	var target_pos: Vector2 = Vector2(520.0, 180.0)
	var target_size: Vector2 = panel.get_layout_rect().size
	panel.set_layout_rect(Rect2(target_pos, target_size))
	await create_timer(0.05).timeout

	var moved: Vector2 = panel.get_layout_rect().position
	if moved.distance_to(target_pos) > 1.0:
		_fail("Top panel did not move: expected %s got %s" % [target_pos, moved])

	var tl_target: Vector2 = Vector2(80.0, 60.0)
	panel.set_layout_rect(Rect2(tl_target, target_size))
	await create_timer(0.05).timeout
	moved = panel.get_layout_rect().position
	if moved.distance_to(tl_target) > 1.0:
		_fail("Top panel top-left did not update: expected %s got %s" % [tl_target, moved])

	if _failures.is_empty():
		print("PASS: panel move from %s to %s and %s" % [start, target_pos, tl_target])
		_finish(PASS)
		return

	for failure in _failures:
		push_error(failure)
	print("FAIL: %d issue(s)" % _failures.size())
	_finish(FAIL)


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: ", message)


func _finish(exit_code: int) -> void:
	quit(exit_code)
