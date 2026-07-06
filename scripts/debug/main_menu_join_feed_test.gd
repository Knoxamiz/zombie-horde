extends SceneTree

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Main menu lobby-only joins test ===")
	var packed: PackedScene = load(MAIN_MENU_SCENE)
	if packed == null:
		push_error("Could not load main menu scene")
		quit(FAIL)
		return

	var main_menu: Node = packed.instantiate()
	root.add_child(main_menu)
	await create_timer(0.4).timeout

	var twitch: TwitchJoinSource = main_menu.get_node_or_null("Systems/TwitchJoinSource") as TwitchJoinSource
	var join_prompt: Node = main_menu.get_node_or_null("OverlayLayer/JoinPromptPanel")
	if twitch == null:
		push_error("Main menu twitch source missing")
		quit(FAIL)
		return

	if join_prompt != null:
		push_error("Main menu should not show the join prompt panel")
		quit(FAIL)
		return

	twitch.submit_join("TestViewer")
	await create_timer(0.1).timeout

	var feed_body: Label = main_menu.get_node_or_null(
		"OverlayLayer/JoinFeedPanel/Margin/VBox/FeedScroll/FeedBody"
	) as Label
	if feed_body != null and feed_body.text.contains("TestViewer"):
		push_error("Main menu should not display join feed lines: %s" % feed_body.text)
		quit(FAIL)
		return

	print("PASS: main menu hides join prompt and ignores join feed")
	quit(PASS)
