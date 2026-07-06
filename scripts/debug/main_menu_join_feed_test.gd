extends SceneTree

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Main menu join feed test ===")
	var packed: PackedScene = load(MAIN_MENU_SCENE)
	if packed == null:
		push_error("Could not load main menu scene")
		quit(FAIL)
		return

	var main_menu: Node = packed.instantiate()
	root.add_child(main_menu)
	await create_timer(0.4).timeout

	var twitch: TwitchJoinSource = main_menu.get_node_or_null("Systems/TwitchJoinSource") as TwitchJoinSource
	var feed_body: Label = main_menu.get_node_or_null(
		"OverlayLayer/JoinFeedPanel/Margin/VBox/FeedScroll/FeedBody"
	) as Label
	if twitch == null or feed_body == null:
		push_error("Main menu twitch feed nodes missing")
		quit(FAIL)
		return

	twitch.submit_join("TestViewer")
	await create_timer(0.1).timeout

	if feed_body.text != "TestViewer joins the horde.":
		push_error("Unexpected feed text: %s" % feed_body.text)
		quit(FAIL)
		return

	twitch.submit_join("SecondUser")
	await create_timer(0.1).timeout
	if not feed_body.text.contains("TestViewer joins the horde.") or not feed_body.text.contains("SecondUser joins the horde."):
		push_error("Feed did not append joins: %s" % feed_body.text)
		quit(FAIL)
		return

	print("PASS: real join feed lines render correctly")
	quit(PASS)
