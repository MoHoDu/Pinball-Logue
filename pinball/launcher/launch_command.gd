class_name LaunchCommand
extends RefCounted

const DIRECTION_LENGTH_TOLERANCE := 0.001

var request_id: StringName = &""
var shot_id: StringName = &""
var slot_id: StringName = &""
var ball_id: StringName = &""
var launch_anchor_id: StringName = &""
var board_direction := Vector2.ZERO
var normalized_strength := 0.0


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if request_id == &"":
		errors.append("발사 요청 식별자는 비어 있을 수 없습니다.")
	if shot_id == &"":
		errors.append("발사 식별자는 비어 있을 수 없습니다.")
	if slot_id == &"":
		errors.append("공 슬롯 식별자는 비어 있을 수 없습니다.")
	if ball_id == &"":
		errors.append("공 식별자는 비어 있을 수 없습니다.")
	if launch_anchor_id == &"":
		errors.append("발사 지점 식별자는 비어 있을 수 없습니다.")
	if not _is_finite_vector(board_direction):
		errors.append("발사 방향은 유한한 보드 평면 값이어야 합니다.")
	elif absf(board_direction.length() - 1.0) > DIRECTION_LENGTH_TOLERANCE:
		errors.append("발사 방향은 길이가 1인 정규화 방향이어야 합니다.")
	if not is_finite(normalized_strength):
		errors.append("발사 세기는 유한한 숫자여야 합니다.")
	elif normalized_strength < 0.0 or normalized_strength > 1.0:
		errors.append("발사 세기는 0~1 범위여야 합니다.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
