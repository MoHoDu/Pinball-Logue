class_name BallPhysicsSnapshot
extends RefCounted

var shot_id: StringName = &""
var slot_id: StringName = &""
var ball_id: StringName = &""
var is_active := false
var is_launched := false
var board_position := Vector2.ZERO
var board_velocity := Vector2.ZERO
var angular_speed_radians := 0.0


func copy() -> BallPhysicsSnapshot:
	var snapshot := BallPhysicsSnapshot.new()
	snapshot.shot_id = shot_id
	snapshot.slot_id = slot_id
	snapshot.ball_id = ball_id
	snapshot.is_active = is_active
	snapshot.is_launched = is_launched
	snapshot.board_position = board_position
	snapshot.board_velocity = board_velocity
	snapshot.angular_speed_radians = angular_speed_radians
	return snapshot


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if shot_id == &"":
		errors.append("공 물리 상태의 발사 식별자가 비어 있습니다.")
	if slot_id == &"":
		errors.append("공 물리 상태의 공 슬롯 식별자가 비어 있습니다.")
	if ball_id == &"":
		errors.append("공 물리 상태의 공 식별자가 비어 있습니다.")
	if not _is_finite_vector(board_position):
		errors.append("공의 보드 평면 위치는 유한한 값이어야 합니다.")
	if not _is_finite_vector(board_velocity):
		errors.append("공의 보드 평면 속도는 유한한 값이어야 합니다.")
	if not is_finite(angular_speed_radians):
		errors.append("공의 회전 속도는 유한한 값이어야 합니다.")
	return errors


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
