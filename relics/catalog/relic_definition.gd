@tool
class_name RelicDefinition
extends BoardPlaceableDefinition


func _init() -> void:
	object_type = String(OBJECT_TYPE_RELIC_PREVIEW)


func get_validation_errors() -> PackedStringArray:
	var errors := super.get_validation_errors()
	if get_object_type_id() != OBJECT_TYPE_RELIC_PREVIEW:
		errors.append("유물 미리보기 원형의 오브젝트 종류는 유물 미리보기여야 합니다: %s" % display_name)
	return errors
