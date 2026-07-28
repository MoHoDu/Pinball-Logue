@tool
class_name BallPhysicsProfile
extends Resource

@export_category("공 물리 설정")
@export_range(0.01, 0.08, 0.001) var radius_board_ratio := 0.025
@export_range(0.1, 10.0, 0.05) var mass := 1.0
@export_range(0.0, 1.0, 0.01) var bounce := 0.65
@export_range(0.0, 1.0, 0.01) var friction := 0.20
@export_range(0.0, 4.0, 0.05) var gravity_scale := 1.0
@export_range(0.0, 5.0, 0.01) var linear_damping := 0.05
@export_range(0.0, 5.0, 0.01) var angular_damping := 0.05
@export_range(0.5, 10.0, 0.1) var max_linear_speed_board_per_second := 3.0
@export_range(0.0, 100.0, 0.5) var max_angular_speed_radians := 40.0
@export var continuous_collision_detection := true
@export var can_sleep := false


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_finite_range(radius_board_ratio, 0.01, 0.08, "공 반지름", errors)
	_validate_finite_range(mass, 0.1, 10.0, "질량", errors)
	_validate_finite_range(bounce, 0.0, 1.0, "반발력", errors)
	_validate_finite_range(friction, 0.0, 1.0, "마찰", errors)
	_validate_finite_range(gravity_scale, 0.0, 4.0, "중력 영향", errors)
	_validate_finite_range(linear_damping, 0.0, 5.0, "직선 감쇠", errors)
	_validate_finite_range(angular_damping, 0.0, 5.0, "회전 감쇠", errors)
	_validate_finite_range(
		max_linear_speed_board_per_second,
		0.5,
		10.0,
		"최대 직선 속도",
		errors
	)
	_validate_finite_range(
		max_angular_speed_radians,
		0.0,
		100.0,
		"최대 회전 속도",
		errors
	)
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


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
