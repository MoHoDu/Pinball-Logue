class_name ShotEndReasons
extends RefCounted

const DRAIN := &"drain"
const OUT_OF_BOUNDS := &"out_of_bounds"
const CANCELLED := &"cancelled"


static func get_all() -> Array[StringName]:
	return [DRAIN, OUT_OF_BOUNDS, CANCELLED]


static func is_supported(end_reason: StringName) -> bool:
	return get_all().has(end_reason)
