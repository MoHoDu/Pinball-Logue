@tool
class_name ScoreConfig
extends Resource

@export_category("콤보")
@export_range(0.01, 60.0, 0.01) var combo_window_seconds := 2.0
@export_range(0.0, 10.0, 0.05) var multiplier_step := 0.5
@export_range(1.0, 100.0, 0.1) var maximum_multiplier := 5.0


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(combo_window_seconds) or combo_window_seconds <= 0.0:
		errors.append("콤보 시간은 유한한 양수여야 합니다.")
	if not is_finite(multiplier_step) or multiplier_step < 0.0:
		errors.append("타격당 배수 증가량은 유한한 0 이상의 값이어야 합니다.")
	if not is_finite(maximum_multiplier) or maximum_multiplier < 1.0:
		errors.append("최대 스코어 배수는 유한한 1 이상의 값이어야 합니다.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()
