@tool
class_name ScoreObjectiveConfig
extends Resource

@export_category("일반 웨이브 목표")
@export_range(1, 100000000, 1) var target_score := 1000


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if target_score <= 0:
		errors.append("목표 스코어는 1점 이상이어야 합니다.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()
