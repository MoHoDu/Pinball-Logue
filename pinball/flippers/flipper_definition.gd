@tool
class_name FlipperDefinition
extends BoardPlaceableDefinition

@export_category("플리퍼 작동")
@export var motion_profile: FlipperMotionProfile


func _init() -> void:
	object_type = String(OBJECT_TYPE_FLIPPER)


func get_validation_errors() -> PackedStringArray:
	var errors := super.get_validation_errors()
	if get_object_type_id() != OBJECT_TYPE_FLIPPER:
		errors.append("플리퍼 원형의 오브젝트 종류는 플리퍼여야 합니다: %s" % display_name)
	if motion_profile == null:
		errors.append("플리퍼 원형에 작동 설정이 연결되지 않았습니다: %s" % display_name)
	else:
		errors.append_array(motion_profile.get_validation_errors())
	return errors
