class_name LaunchAimModes
extends RefCounted

const DIRECTION_KEYS := &"direction_keys"
const MOUSE := &"mouse"


static func get_all() -> Array[StringName]:
	return [DIRECTION_KEYS, MOUSE]


static func is_supported(aim_mode: StringName) -> bool:
	return get_all().has(aim_mode)
