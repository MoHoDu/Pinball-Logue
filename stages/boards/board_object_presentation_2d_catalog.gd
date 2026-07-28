@tool
class_name BoardObjectPresentation2DCatalog
extends Resource

@export var presentations: Array[BoardObjectPresentation2D] = []


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var known_content_ids: Dictionary = {}
	for presentation_index in presentations.size():
		var presentation := presentations[presentation_index]
		if presentation == null:
			errors.append("2D 디자인 연결표의 %d번 항목이 비어 있습니다." % presentation_index)
			continue
		errors.append_array(presentation.get_validation_errors())
		if presentation.content_id == &"":
			continue
		if known_content_ids.has(presentation.content_id):
			errors.append("같은 오브젝트 원형에 2D 디자인을 두 번 연결할 수 없습니다: %s" % presentation.content_id)
		else:
			known_content_ids[presentation.content_id] = true
	return errors


func get_presentation(content_id: StringName) -> BoardObjectPresentation2D:
	for presentation in presentations:
		if presentation != null and presentation.content_id == content_id:
			return presentation
	return null


func get_binding_validation_errors(definitions_by_id: Dictionary) -> PackedStringArray:
	var errors := get_validation_errors()
	for presentation in presentations:
		if presentation == null or presentation.content_id == &"":
			continue
		if not definitions_by_id.has(presentation.content_id):
			errors.append(
				"2D 디자인과 연결할 오브젝트 원형을 찾을 수 없습니다: %s"
				% presentation.content_id
			)
			continue
		var definition := definitions_by_id[presentation.content_id] as BoardPlaceableDefinition
		if definition == null:
			errors.append("2D 디자인에 연결된 오브젝트 원형 정보가 올바르지 않습니다: %s" % presentation.content_id)
	return errors


func get_scene(content_id: StringName) -> PackedScene:
	var presentation := get_presentation(content_id)
	if presentation == null:
		return null
	return presentation.scene_2d


func has_complete_presentations(content_ids: Array[StringName]) -> bool:
	if not get_validation_errors().is_empty():
		return false
	for content_id in content_ids:
		if get_scene(content_id) == null:
			return false
	return true
