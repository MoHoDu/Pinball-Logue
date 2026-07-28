class_name FlipperPhysicsAdapter
extends RefCounted

signal action_started(action_id: StringName, anchor_ids: PackedStringArray)
signal action_finished(action_id: StringName, anchor_ids: PackedStringArray)
signal parry_applied(
	action_id: StringName,
	anchor_id: StringName,
	shot_id: StringName
)


func activate(_command: FlipperActionCommand) -> String:
	return "현재 물리 어댑터는 플리퍼 작동을 구현하지 않았습니다."


func physics_tick(_delta: float) -> void:
	pass


func reset() -> void:
	pass


func is_action_active(_action_id: StringName) -> bool:
	return false


func get_registered_anchor_ids() -> PackedStringArray:
	return PackedStringArray()
