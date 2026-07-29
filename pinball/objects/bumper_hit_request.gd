class_name BumperHitRequest
extends RefCounted

var hit_id: StringName = &""
var contact_id: StringName = &""
var shot_id: StringName = &""
var ball_id: StringName = &""
var point_id: StringName = &""
var content_id: StringName = &""
var contact_time_fraction := 0.0
var contact_board_position := Vector2.ZERO
var contact_board_normal := Vector2.UP
var incoming_board_velocity := Vector2.ZERO
var reflected_board_velocity := Vector2.ZERO
var ball_max_speed_board_per_second := 0.0
var track_path_board_positions := PackedVector2Array()
var shot_target_board_position := Vector2(INF, INF)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if hit_id == &"":
		errors.append("범퍼 타격 식별자가 비어 있습니다.")
	if contact_id == &"":
		errors.append("범퍼 접촉 식별자가 비어 있습니다.")
	if shot_id == &"":
		errors.append("범퍼 타격과 연결할 발사 식별자가 비어 있습니다.")
	if ball_id == &"":
		errors.append("범퍼를 타격한 공 식별자가 비어 있습니다.")
	if point_id == &"":
		errors.append("타격한 범퍼 배치 지점 식별자가 비어 있습니다.")
	if content_id == &"":
		errors.append("타격한 범퍼 원형 식별자가 비어 있습니다.")
	if not is_finite(contact_time_fraction) or contact_time_fraction < 0.0 or contact_time_fraction > 1.0:
		errors.append("범퍼 최초 접촉 시점은 이동 구간의 0~1 범위여야 합니다.")
	if not _is_finite_vector(contact_board_position):
		errors.append("범퍼 접촉 위치는 유한한 보드 평면 값이어야 합니다.")
	if not _is_finite_vector(contact_board_normal) or contact_board_normal.is_zero_approx():
		errors.append("범퍼 접촉 법선은 유한하고 길이가 0이 아닌 보드 평면 방향이어야 합니다.")
	if not _is_finite_vector(incoming_board_velocity):
		errors.append("범퍼 입사 속도는 유한한 보드 평면 값이어야 합니다.")
	if not _is_finite_vector(reflected_board_velocity):
		errors.append("범퍼 기본 반사 속도는 유한한 보드 평면 값이어야 합니다.")
	if not is_finite(ball_max_speed_board_per_second) or ball_max_speed_board_per_second <= 0.0:
		errors.append("공 최대 직선 속도는 유한한 양수여야 합니다.")
	for path_index in track_path_board_positions.size():
		if not _is_finite_vector(track_path_board_positions[path_index]):
			errors.append("경로 지점 %d번 위치는 유한한 보드 평면 값이어야 합니다." % path_index)
	if not _is_infinite_vector(shot_target_board_position) and not _is_finite_vector(shot_target_board_position):
		errors.append("목표 지점은 유한한 보드 평면 값이어야 합니다.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


static func sort_before(first: BumperHitRequest, second: BumperHitRequest) -> bool:
	if first == null:
		return false
	if second == null:
		return true
	if not is_equal_approx(first.contact_time_fraction, second.contact_time_fraction):
		return first.contact_time_fraction < second.contact_time_fraction
	return String(first.point_id) < String(second.point_id)


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


func _is_infinite_vector(value: Vector2) -> bool:
	return is_inf(value.x) and is_inf(value.y)
