class_name ZombieTierVisuals
extends RefCounted

const BASIC_VISUAL_SCENE: PackedScene = preload("res://scenes/zombies/visuals/zombie_basic_visual.tscn")
const RIBCAGE_VISUAL_SCENE: PackedScene = preload("res://scenes/zombies/visuals/zombie_ribcage_visual.tscn")

const TWITCH_GIFT_ICON: Texture2D = preload("res://assets/ui/twitch/twitch_gift_icon.png")
const TWITCH_BITS_ICON: Texture2D = preload("res://assets/ui/twitch/twitch_bits_icon.png")


static func uses_ribcage_model(tier: ParticipantJoinInfo.SupporterTier) -> bool:
	return tier == ParticipantJoinInfo.SupporterTier.NONE


static func get_visual_scene_for_tier(tier: ParticipantJoinInfo.SupporterTier) -> PackedScene:
	if uses_ribcage_model(tier):
		return RIBCAGE_VISUAL_SCENE
	return BASIC_VISUAL_SCENE


static func get_visual_scene_for_join_info(join_info: ParticipantJoinInfo) -> PackedScene:
	var tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE
	if join_info != null:
		tier = join_info.get_supporter_tier()
	return get_visual_scene_for_tier(tier)


static func should_apply_body_tint(tier: ParticipantJoinInfo.SupporterTier) -> bool:
	return not uses_ribcage_model(tier)
