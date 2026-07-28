@tool
class_name BoardPlacementAssignmentConfig
extends Resource

@export var point_id: StringName = &""
@export var content_id: StringName = &""


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if point_id == &"":
		errors.append("웨이브 배치의 배치 지점 이름은 비어 있을 수 없습니다.")
	if content_id == &"":
		errors.append("웨이브 배치에서 사용할 오브젝트 원형을 선택해 주세요: %s" % point_id)
	return errors

