class_name SupporterUpgradeState
extends RefCounted

var tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE
var upgrade_root: Node3D
var pulse_materials: Array[StandardMaterial3D] = []
var pulse_time: float = 0.0
