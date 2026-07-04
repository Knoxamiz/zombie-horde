extends SceneTree

const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Supporter upgrade test ===")

	var viewer_info: ParticipantJoinInfo = ParticipantJoinInfo.create_test_join(
		ParticipantJoinInfo.SupporterTier.NONE,
		1
	)
	var sub_info: ParticipantJoinInfo = ParticipantJoinInfo.create_test_join(
		ParticipantJoinInfo.SupporterTier.SUBSCRIBER,
		1
	)
	var gift_info: ParticipantJoinInfo = ParticipantJoinInfo.create_test_join(
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT,
		1
	)
	var bits_info: ParticipantJoinInfo = ParticipantJoinInfo.create_test_join(
		ParticipantJoinInfo.SupporterTier.BITS_DONOR,
		1
	)

	var attach_root: Node3D = Node3D.new()
	root.add_child(attach_root)

	var viewer_state: SupporterUpgradeState = SupporterUpgradeApplier.apply_upgrades(attach_root, viewer_info)
	if viewer_state.upgrade_root != null:
		push_error("Viewer tier should not create upgrade attachments")
		quit(FAIL)
		return

	var sub_state: SupporterUpgradeState = SupporterUpgradeApplier.apply_upgrades(attach_root, sub_info)
	if sub_state.upgrade_root != null:
		push_error("Subscriber tier should not create upgrade attachments")
		quit(FAIL)
		return

	var gift_state: SupporterUpgradeState = SupporterUpgradeApplier.apply_upgrades(attach_root, gift_info)
	if gift_state.upgrade_root == null or gift_state.upgrade_root.get_node_or_null("HeadAttach") == null:
		push_error("Gift tier should create gift icon attachment")
		quit(FAIL)
		return

	var bits_state: SupporterUpgradeState = SupporterUpgradeApplier.apply_upgrades(attach_root, bits_info)
	if bits_state.upgrade_root == null:
		push_error("Bits tier should create bits icon attachments")
		quit(FAIL)
		return
	if bits_state.upgrade_root.get_node_or_null("HeadAttach/BitsSparkles") == null:
		push_error("Bits tier should include sparkle particles")
		quit(FAIL)
		return

	SupporterUpgradeApplier.clear_upgrades(attach_root)
	if attach_root.get_node_or_null(SupporterUpgradeApplier.UPGRADE_ROOT_NAME) != null:
		push_error("Upgrade root should be removed after clear")
		quit(FAIL)
		return

	print("PASS: supporter tier upgrades attach and clear correctly")
	quit(PASS)
