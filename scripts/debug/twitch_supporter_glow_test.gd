extends SceneTree

const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Twitch supporter glow test ===")

	var sub_tags: Dictionary = {
		"display-name": "SubViewer",
		"login": "subviewer",
		"subscriber": "1",
		"badges": "subscriber/12",
	}
	var sub_info: ParticipantJoinInfo = _build_test_join_info("SubViewer", sub_tags, 0)
	if sub_info.get_supporter_tier() != ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
		push_error("Expected subscriber tier")
		quit(FAIL)
		return
	if sub_info.has_supporter_glow():
		push_error("Subscribers should not pulse-glow")
		quit(FAIL)
		return
	if not ZombieCharacterVisuals.get_body_color_for_join_info(sub_info).is_equal_approx(
		ZombieCharacterVisuals.COLOR_SUBSCRIBER
	):
		push_error("Subscriber body should be red")
		quit(FAIL)
		return

	var gift_tags: Dictionary = {
		"display-name": "GiftViewer",
		"login": "giftviewer",
		"subscriber": "1",
		"badges": "subscriber/0",
		"badge-info": "subscriber/0",
	}
	var gift_info: ParticipantJoinInfo = _build_test_join_info("GiftViewer", gift_tags, 0)
	if gift_info.get_supporter_tier() != ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT:
		push_error("Expected gift recipient tier")
		quit(FAIL)
		return

	var bits_info: ParticipantJoinInfo = _build_test_join_info(
		"BitsViewer",
		{"display-name": "BitsViewer", "login": "bitsviewer"},
		250
	)
	if bits_info.get_supporter_tier() != ParticipantJoinInfo.SupporterTier.BITS_DONOR:
		push_error("Expected bits donor tier")
		quit(FAIL)
		return
	if not bits_info.has_supporter_glow():
		push_error("Bits donors should pulse-glow")
		quit(FAIL)
		return

	var glow_materials: Array[ShaderMaterial] = ZombieCharacterVisuals.apply_supporter_glow(
		Node3D.new(),
		ParticipantJoinInfo.SupporterTier.NONE
	)
	if not glow_materials.is_empty():
		push_error("None tier should not create glow materials")
		quit(FAIL)
		return

	print("PASS: supporter tiers and glow helpers work")
	quit(PASS)


func _build_test_join_info(display_name: String, tags: Dictionary, bits_amount: int) -> ParticipantJoinInfo:
	var join_info: ParticipantJoinInfo = ParticipantJoinInfo.new()
	join_info.display_name = display_name
	join_info.bits_amount = bits_amount
	join_info.is_bits_donor = bits_amount > 0
	join_info.is_subscriber = str(tags.get("subscriber", "0")) == "1" or str(tags.get("badges", "")).contains("subscriber/")
	join_info.is_gift_recipient = str(tags.get("badge-info", "")).contains("subscriber/0")
	return join_info
