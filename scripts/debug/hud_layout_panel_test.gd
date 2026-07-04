extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== HUD layout panel test ===")
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

	var viewport_size: Vector2 = hud.get_node("Root").get_rect().size
	for panel_id in ["top", "roster", "leaderboard", "command"]:
		var panel: HudLayoutPanel = hud.get_layout_panel(panel_id)
		if panel == null:
			_fail("Missing panel: %s" % panel_id)
			continue
		var rect: Rect2 = panel.get_layout_rect()
		if rect.size.x < 180.0 or rect.size.y < 72.0:
			_fail("%s too small: %s" % [panel_id, rect.size])
		if rect.position.x < -40.0 or rect.position.y < -40.0:
			_fail("%s off-screen left/top: %s" % [panel_id, rect.position])
		if rect.position.x + rect.size.x > viewport_size.x + 40.0:
			_fail("%s off-screen right: %s" % [panel_id, rect.end])
		if rect.position.y + rect.size.y > viewport_size.y + 40.0:
			_fail("%s off-screen bottom: %s" % [panel_id, rect.end])

	if _failures.is_empty():
		print("PASS: all layout panels within viewport")
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
