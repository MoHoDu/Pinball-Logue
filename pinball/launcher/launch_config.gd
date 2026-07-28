@tool
class_name LaunchConfig
extends Resource

@export_category("조준 방식")
@export_enum("direction_keys", "mouse") var aim_mode := "mouse"
@export_range(-180.0, 180.0, 0.5) var default_aim_angle_degrees := 0.0
@export_range(-180.0, 180.0, 0.5) var minimum_aim_angle_degrees := -45.0
@export_range(-180.0, 180.0, 0.5) var maximum_aim_angle_degrees := 45.0

@export_category("방향키 조준")
@export_range(0.1, 45.0, 0.1) var keyboard_angle_step_degrees := 2.0
@export_range(0.01, 1.0, 0.01) var keyboard_strength_step := 0.05

@export_category("발사 세기")
@export_range(0.0, 1.0, 0.01) var default_strength := 0.60
@export_range(0.1, 10.0, 0.1) var minimum_speed_board_per_second := 1.0
@export_range(0.1, 10.0, 0.1) var maximum_speed_board_per_second := 2.5

@export_category("마우스 조준")
@export_range(0.01, 1.0, 0.01) var mouse_max_distance_board_ratio := 0.35

@export_category("조준 안내")
@export_range(0.01, 1.0, 0.01) var aim_guide_length_board_ratio := 0.28


func get_aim_mode_id() -> StringName:
	return StringName(aim_mode)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not LaunchAimModes.is_supported(get_aim_mode_id()):
		errors.append("조준 방식은 방향키 또는 마우스 중 하나여야 합니다.")
	_validate_finite_range(
		minimum_aim_angle_degrees, -180.0, 180.0, "최소 조준 각도", errors
	)
	_validate_finite_range(
		maximum_aim_angle_degrees, -180.0, 180.0, "최대 조준 각도", errors
	)
	_validate_finite_range(
		default_aim_angle_degrees, -180.0, 180.0, "기본 조준 각도", errors
	)
	if minimum_aim_angle_degrees > maximum_aim_angle_degrees:
		errors.append("최소 조준 각도는 최대 조준 각도보다 클 수 없습니다.")
	elif (
		default_aim_angle_degrees < minimum_aim_angle_degrees
		or default_aim_angle_degrees > maximum_aim_angle_degrees
	):
		errors.append("기본 조준 각도는 최소·최대 조준 각도 안에 있어야 합니다.")
	_validate_finite_range(
		keyboard_angle_step_degrees, 0.1, 45.0, "방향키 각도 변화량", errors
	)
	_validate_finite_range(
		keyboard_strength_step, 0.01, 1.0, "방향키 세기 변화량", errors
	)
	_validate_finite_range(default_strength, 0.0, 1.0, "기본 발사 세기", errors)
	_validate_finite_range(
		minimum_speed_board_per_second, 0.1, 10.0, "최소 발사 속도", errors
	)
	_validate_finite_range(
		maximum_speed_board_per_second, 0.1, 10.0, "최대 발사 속도", errors
	)
	if minimum_speed_board_per_second > maximum_speed_board_per_second:
		errors.append("최소 발사 속도는 최대 발사 속도보다 클 수 없습니다.")
	_validate_finite_range(
		mouse_max_distance_board_ratio, 0.01, 1.0, "마우스 최대 조준 거리", errors
	)
	_validate_finite_range(
		aim_guide_length_board_ratio, 0.01, 1.0, "조준선 길이", errors
	)
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func clamp_aim_angle_degrees(value: float) -> float:
	return clampf(value, minimum_aim_angle_degrees, maximum_aim_angle_degrees)


func clamp_strength(value: float) -> float:
	return clampf(value, 0.0, 1.0)


func get_speed_for_strength(value: float) -> float:
	return lerpf(
		minimum_speed_board_per_second,
		maximum_speed_board_per_second,
		clamp_strength(value)
	)


func _validate_finite_range(
	value: float,
	minimum: float,
	maximum: float,
	label: String,
	errors: PackedStringArray
) -> void:
	if not is_finite(value):
		errors.append("%s 값은 유한한 숫자여야 합니다." % label)
	elif value < minimum or value > maximum:
		errors.append("%s 값은 %.3f~%.3f 범위여야 합니다." % [label, minimum, maximum])
