class_name ParticipantJoinInfo
extends RefCounted

enum SupporterTier {
	NONE,
	SUBSCRIBER,
	GIFT_RECIPIENT,
	BITS_DONOR,
}

var display_name: String = ""
var is_subscriber: bool = false
var is_gift_recipient: bool = false
var is_bits_donor: bool = false
var bits_amount: int = 0


static func for_name(name: String) -> ParticipantJoinInfo:
	var info: ParticipantJoinInfo = ParticipantJoinInfo.new()
	info.display_name = name.strip_edges()
	return info


static func create_test_join(tier: SupporterTier, sequence: int = 1) -> ParticipantJoinInfo:
	var info: ParticipantJoinInfo = ParticipantJoinInfo.new()
	match tier:
		SupporterTier.BITS_DONOR:
			info.display_name = "TestBits_%02d" % sequence
			info.is_bits_donor = true
			info.bits_amount = 100
		SupporterTier.GIFT_RECIPIENT:
			info.display_name = "TestGift_%02d" % sequence
			info.is_gift_recipient = true
			info.is_subscriber = true
		SupporterTier.SUBSCRIBER:
			info.display_name = "TestSub_%02d" % sequence
			info.is_subscriber = true
		_:
			info.display_name = "TestViewer_%02d" % sequence
	return info


func get_tier_label() -> String:
	match get_supporter_tier():
		SupporterTier.BITS_DONOR:
			return "Bits Cheer"
		SupporterTier.GIFT_RECIPIENT:
			return "Gift Sub"
		SupporterTier.SUBSCRIBER:
			return "Subscriber"
	return "Viewer"


func get_supporter_tier() -> SupporterTier:
	if is_bits_donor:
		return SupporterTier.BITS_DONOR
	if is_gift_recipient:
		return SupporterTier.GIFT_RECIPIENT
	if is_subscriber:
		return SupporterTier.SUBSCRIBER
	return SupporterTier.NONE


func has_supporter_glow() -> bool:
	return get_supporter_tier() == SupporterTier.BITS_DONOR


func get_join_feed_suffix() -> String:
	match get_supporter_tier():
		SupporterTier.BITS_DONOR:
			return " [bits]"
		SupporterTier.GIFT_RECIPIENT:
			return " [gift]"
		SupporterTier.SUBSCRIBER:
			return " [sub]"
	return ""
