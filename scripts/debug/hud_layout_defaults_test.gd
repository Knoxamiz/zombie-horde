extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== HUD layout defaults test ===")
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

	hud.reset_layout_to_defaults()
	await create_timer(0.05).timeout

	var viewport_size: Vector2 = hud.get_node("Root").get_rect().size
	var profile: HudLayoutProfile = HudLayoutProfile.create_default_profile(viewport_size)
	var expected: Dictionary = profile.panels

	for panel_id in ["top", "roster", "leaderboard", "command"]:
		var panel: HudLayoutPanel = hud.get_layout_panel(panel_id)
		if panel == null:
			_fail("Missing panel: %s" % panel_id)
			continue
		var rect: Rect2 = panel.get_layout_rect()
		var data: Dictionary = expected.get(panel_id, {})
		var want: Rect2 = HudLayoutProfile.get_absolute_rect_from_data(data)
		if rect.position.distance_to(want.position) > 2.0:
			_fail("%s position mismatch: got %s want %s" % [panel_id, rect.position, want.position])
		if rect.size.distance_to(want.size) > 2.0:
			_fail("%s size mismatch: got %s want %s" % [panel_id, rect.size, want.size])

	if _failures.is_empty():
		print("PASS: default corner layout applied")
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
