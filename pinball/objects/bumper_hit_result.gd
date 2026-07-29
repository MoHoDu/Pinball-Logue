class_name BumperHitResult
extends RefCounted

const EFFECT_NORMAL_REFLECT := &"normal_reflect"
const EFFECT_BOUNCE := &"bounce"
const EFFECT_TRACK := &"track"
const EFFECT_SHOT := &"shot"

var is_applied := false
var ignored_reason := ""
var hit_id: StringName = &""
var contact_id: StringName = &""
var shot_id: StringName = &""
var ball_id: StringName = &""
var point_id: StringName = &""
var content_id: StringName = &""
var bumper_type: StringName = &""
var effect_type: StringName = &""
var contact_time_fraction := 0.0
var contact_board_position := Vector2.ZERO
var contact_board_normal := Vector2.UP
var incoming_board_velocity := Vector2.ZERO
var reflected_board_velocity := Vector2.ZERO
var collision_strength_board_per_second := 0.0
var base_score_value := 0
var durability_before := 0
var durability_after := 0
var destroyed := false
var output_board_velocity := Vector2.ZERO
var track_path_board_positions := PackedVector2Array()
var track_speed_board_per_second := 0.0
var shot_target_board_position := Vector2(INF, INF)
var shot_speed_board_per_second := 0.0
var shot_direction_error_degrees := 0.0


static func ignored(reason: String) -> BumperHitResult:
	var result := BumperHitResult.new()
	result.ignored_reason = reason
	return result


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_applied:
		if ignored_reason.strip_edges().is_empty():
			errors.append("적용되지 않은 범퍼 타격 결과에는 무시 이유가 필요합니다.")
		return errors
	_validate_identifier(hit_id, "타격", errors)
	_validate_identifier(contact_id, "접촉", errors)
	_validate_identifier(shot_id, "발사", errors)
	_validate_identifier(ball_id, "공", errors)
	_validate_identifier(point_id, "배치 지점", errors)
	_validate_identifier(content_id, "범퍼 원형", errors)
	if not BumperDefinition.get_supported_bumper_types().has(bumper_type):
		errors.append("범퍼 타격 결과의 종류가 올바르지 않습니다: %s" % bumper_type)
	if not [EFFECT_NORMAL_REFLECT, EFFECT_BOUNCE, EFFECT_TRACK, EFFECT_SHOT].has(effect_type):
		errors.append("범퍼 타격 결과의 효과가 올바르지 않습니다: %s" % effect_type)
	if base_score_value < 0:
		errors.append("범퍼 타격 결과의 기본 점수 근거는 0 이상이어야 합니다.")
	if not is_finite(contact_time_fraction) or contact_time_fraction < 0.0 or contact_time_fraction > 1.0:
		errors.append("범퍼 타격 결과의 최초 접촉 시점은 이동 구간의 0~1 범위여야 합니다.")
	if not _is_finite_vector(contact_board_position):
		errors.append("범퍼 타격 결과의 접촉 위치는 유한한 보드 평면 값이어야 합니다.")
	if not _is_finite_vector(contact_board_normal) or contact_board_normal.is_zero_approx():
		errors.append("범퍼 타격 결과의 접촉 법선은 유한하고 길이가 0이 아니어야 합니다.")
	if not _is_finite_vector(incoming_board_velocity):
		errors.append("범퍼 타격 결과의 입사 속도는 유한한 보드 평면 값이어야 합니다.")
	if not _is_finite_vector(reflected_board_velocity):
		errors.append("범퍼 타격 결과의 기본 반사 속도는 유한한 보드 평면 값이어야 합니다.")
	if not is_finite(collision_strength_board_per_second) or collision_strength_board_per_second < 0.0:
		errors.append("범퍼 타격 결과의 충돌 세기는 유한한 0 이상의 값이어야 합니다.")
	if durability_before < 0 or durability_after < 0:
		errors.append("범퍼 타격 결과의 내구도는 0 이상이어야 합니다.")
	if not _is_finite_vector(output_board_velocity):
		errors.append("범퍼 타격 결과의 출력 속도는 유한한 보드 평면 값이어야 합니다.")
	match effect_type:
		EFFECT_TRACK:
			if track_path_board_positions.is_empty():
				errors.append("경로 범퍼 결과에는 하나 이상의 경로 지점이 필요합니다.")
			if not is_finite(track_speed_board_per_second) or track_speed_board_per_second <= 0.0:
				errors.append("경로 범퍼 결과의 이동 속도는 유한한 양수여야 합니다.")
		EFFECT_SHOT:
			if not _is_finite_vector(shot_target_board_position):
				errors.append("발사 범퍼 결과에는 유효한 목표 지점이 필요합니다.")
			if not is_finite(shot_speed_board_per_second) or shot_speed_board_per_second <= 0.0:
				errors.append("발사 범퍼 결과의 발사 속도는 유한한 양수여야 합니다.")
			if not is_finite(shot_direction_error_degrees) or absf(shot_direction_error_degrees) > 180.0:
				errors.append("발사 범퍼 결과의 적용 방향 오차는 유한한 -180~180도 값이어야 합니다.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


func _validate_identifier(
	value: StringName,
	label: String,
	errors: PackedStringArray
) -> void:
	if value == &"":
		errors.append("범퍼 타격 결과의 %s 식별자가 비어 있습니다." % label)
