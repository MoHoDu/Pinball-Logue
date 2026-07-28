@tool
class_name FlipperDefinition
extends BoardPlaceableDefinition


func _init() -> void:
	object_type = String(OBJECT_TYPE_FLIPPER)


func get_validation_errors() -> PackedStringArray:
	var errors := super.get_validation_errors()
	if get_object_type_id() != OBJECT_TYPE_FLIPPER:
		errors.append("플리퍼 원형의 오브젝트 종류는 플리퍼여야 합니다: %s" % display_name)
	return errors
