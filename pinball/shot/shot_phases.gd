class_name ShotPhases
extends RefCounted

const BALL_SELECTION := &"ball_selection"
const AIMING := &"aiming"
const IN_PLAY := &"in_play"
const RESOLVING := &"resolving"


static func get_all() -> Array[StringName]:
	return [BALL_SELECTION, AIMING, IN_PLAY, RESOLVING]


static func is_supported(phase: StringName) -> bool:
	return get_all().has(phase)
