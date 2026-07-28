@tool
class_name BoardObjectPresentation2D
extends Resource

@export var content_id: StringName = &""
@export var scene_2d: PackedScene


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if content_id == &"":
		errors.append("2D 디자인의 오브젝트 원형 이름은 비어 있을 수 없습니다.")
	if scene_2d == null:
		errors.append("오브젝트 원형에 사용할 2D 디자인을 선택해 주세요: %s" % content_id)
	elif not scene_2d.can_instantiate():
		errors.append("선택한 2D 디자인을 장면에 만들 수 없습니다: %s" % content_id)
	else:
		var scene_state := scene_2d.get_state()
		if scene_state.get_node_count() == 0:
			errors.append("선택한 2D 디자인에 루트 노드가 없습니다: %s" % content_id)
		elif not ClassDB.is_parent_class(scene_state.get_node_type(0), &"Node2D"):
			errors.append("2D 디자인의 루트는 Node2D여야 합니다: %s" % content_id)
	return errors
