class_name LaunchSolution
extends RefCounted

const DIRECTION_LENGTH_TOLERANCE := 0.001
const VELOCITY_TOLERANCE := 0.001

var request_id: StringName = &""
var shot_id: StringName = &""
var slot_id: StringName = &""
var ball_id: StringName = &""
var launch_anchor_id: StringName = &""
var board_direction := Vector2.ZERO
var normalized_strength := 0.0
var speed_board_per_second := 0.0
var initial_board_velocity := Vector2.ZERO
var direction_was_clamped := false
var speed_was_clamped := false
var validation_errors := PackedStringArray()


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray(validation_errors)
	if request_id == &"":
		errors.append("발사 계산 결과의 요청 식별자가 비어 있습니다.")
	if shot_id == &"":
		errors.append("발사 계산 결과의 발사 식별자가 비어 있습니다.")
	if slot_id == &"":
		errors.append("발사 계산 결과의 공 슬롯 식별자가 비어 있습니다.")
	if ball_id == &"":
		errors.append("발사 계산 결과의 공 식별자가 비어 있습니다.")
	if launch_anchor_id == &"":
		errors.append("발사 계산 결과의 발사 지점 식별자가 비어 있습니다.")
	if not _is_finite_vector(board_direction):
		errors.append("발사 계산 결과의 방향은 유한한 보드 평면 값이어야 합니다.")
	elif absf(board_direction.length() - 1.0) > DIRECTION_LENGTH_TOLERANCE:
		errors.append("발사 계산 결과의 방향은 길이가 1인 정규화 방향이어야 합니다.")
	if not is_finite(normalized_strength) or normalized_strength < 0.0 or normalized_strength > 1.0:
		errors.append("발사 계산 결과의 세기는 0~1 범위의 유한한 값이어야 합니다.")
	if not is_finite(speed_board_per_second) or speed_board_per_second <= 0.0:
		errors.append("발사 계산 결과의 속도는 유한한 양수여야 합니다.")
	if not _is_finite_vector(initial_board_velocity):
		errors.append("발사 계산 결과의 초기 속도는 유한한 보드 평면 값이어야 합니다.")
	elif (
		_is_finite_vector(board_direction)
		and is_finite(speed_board_per_second)
		and initial_board_velocity.distance_to(
			board_direction * speed_board_per_second
		) > VELOCITY_TOLERANCE
	):
		errors.append("발사 계산 결과의 방향·속도와 초기 속도가 일치하지 않습니다.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
