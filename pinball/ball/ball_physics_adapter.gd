class_name BallPhysicsAdapter
extends RefCounted

signal ball_ended(
	shot_id: StringName,
	end_reason: StringName,
	snapshot: BallPhysicsSnapshot
)


func has_active_ball() -> bool:
	return false


func prepare_ball(
	_shot_id: StringName,
	_slot_id: StringName,
	_definition: BallDefinition,
	_board_position: Vector2
) -> String:
	return "현재 물리 어댑터는 공 준비를 구현하지 않았습니다."


func apply_launch(_solution: LaunchSolution) -> String:
	return "현재 물리 어댑터는 공 발사를 구현하지 않았습니다."


func get_snapshot(_shot_id: StringName) -> BallPhysicsSnapshot:
	return null


func remove_ball(_shot_id: StringName) -> String:
	return "현재 물리 어댑터는 공 제거를 구현하지 않았습니다."
