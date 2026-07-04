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


func get_supporter_tier() -> SupporterTier:
	if is_bits_donor:
		return SupporterTier.BITS_DONOR
	if is_gift_recipient:
		return SupporterTier.GIFT_RECIPIENT
	if is_subscriber:
		return SupporterTier.SUBSCRIBER
	return SupporterTier.NONE


func has_supporter_glow() -> bool:
	return get_supporter_tier() != SupporterTier.NONE


func get_join_feed_suffix() -> String:
	match get_supporter_tier():
		SupporterTier.BITS_DONOR:
			return " [bits]"
		SupporterTier.GIFT_RECIPIENT:
			return " [gift]"
		SupporterTier.SUBSCRIBER:
			return " [sub]"
	return ""
