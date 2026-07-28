@tool
class_name FlipperMotionProfile
extends Resource

@export_category("플리퍼 크기")
@export_range(0.03, 0.35, 0.005) var length_board_ratio := 0.16
@export_range(0.01, 0.12, 0.0025) var width_board_ratio := 0.035

@export_category("플리퍼 작동")
@export_range(5.0, 120.0, 1.0) var activation_angle_degrees := 48.0
@export_range(0.02, 0.5, 0.005) var activation_seconds := 0.075
@export_range(0.0, 0.5, 0.005) var hold_seconds := 0.055
@export_range(0.02, 0.8, 0.005) var return_seconds := 0.12

@export_category("공 패링")
@export_range(0.0, 5.0, 0.05) var base_hit_impulse_board_per_second := 0.65
@export_range(0.0, 0.5, 0.005) var parry_window_seconds := 0.06
@export_range(1.0, 5.0, 0.05) var parry_impulse_multiplier := 1.8


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_positive_finite(length_board_ratio, "플리퍼 길이", errors)
	_validate_positive_finite(width_board_ratio, "플리퍼 너비", errors)
	_validate_positive_finite(activation_angle_degrees, "작동 회전 각도", errors)
	_validate_positive_finite(activation_seconds, "작동 시간", errors)
	_validate_non_negative_finite(hold_seconds, "유지 시간", errors)
	_validate_positive_finite(return_seconds, "복귀 시간", errors)
	_validate_non_negative_finite(
		base_hit_impulse_board_per_second,
		"기본 타격 힘",
		errors
	)
	_validate_non_negative_finite(parry_window_seconds, "공 패링 시간", errors)
	_validate_positive_finite(parry_impulse_multiplier, "공 패링 힘 배수", errors)
	if parry_impulse_multiplier < 1.0:
		errors.append("공 패링 힘 배수는 1 이상이어야 합니다.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func _validate_positive_finite(
	value: float,
	label: String,
	errors: PackedStringArray
) -> void:
	if not is_finite(value) or value <= 0.0:
		errors.append("%s은(는) 유한한 양수여야 합니다." % label)


func _validate_non_negative_finite(
	value: float,
	label: String,
	errors: PackedStringArray
) -> void:
	if not is_finite(value) or value < 0.0:
		errors.append("%s은(는) 유한한 0 이상의 값이어야 합니다." % label)
