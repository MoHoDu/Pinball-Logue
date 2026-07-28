@tool
class_name WaveBoardCompositionConfig
extends Resource

const MIN_FLIPPER_COUNT := 1
const MAX_FLIPPER_COUNT := 4

@export var layout_config: BoardLayoutConfig
@export var assignments: Array[BoardPlacementAssignmentConfig] = []


func get_validation_errors(
	definitions_by_id: Dictionary = {}
) -> PackedStringArray:
	var errors := PackedStringArray()
	if layout_config == null:
		errors.append("웨이브 배치에 보드 템플릿이 연결되어 있지 않습니다.")
		return errors
	errors.append_array(layout_config.get_validation_errors())

	var assigned_point_ids: Dictionary = {}
	var assigned_flipper_count := 0
	for assignment_index in assignments.size():
		var assignment := assignments[assignment_index]
		if assignment == null:
			errors.append("웨이브 배치 %d번 항목이 비어 있습니다." % assignment_index)
			continue
		errors.append_array(assignment.get_validation_errors())
		if assignment.point_id != &"":
			if assigned_point_ids.has(assignment.point_id):
				errors.append("같은 배치 지점에 오브젝트를 두 번 놓을 수 없습니다: %s" % assignment.point_id)
			else:
				assigned_point_ids[assignment.point_id] = true

		var point := layout_config.get_anchor(assignment.point_id)
		if point == null:
			if assignment.point_id != &"":
				errors.append("보드 템플릿에서 배치 지점을 찾을 수 없습니다: %s" % assignment.point_id)
			continue
		if point.get_type_id() == BoardAnchorConfig.TYPE_LAUNCH:
			errors.append("발사 지점에는 오브젝트를 고정 배치할 수 없습니다: %s" % assignment.point_id)
			continue
		if point.get_type_id() == BoardAnchorConfig.TYPE_DRAIN:
			errors.append("드레인 지점에는 오브젝트를 고정 배치할 수 없습니다: %s" % assignment.point_id)
			continue

		if assignment.content_id == &"":
			continue
		if not definitions_by_id.has(assignment.content_id):
			errors.append("사용할 오브젝트 원형을 찾을 수 없습니다: %s" % assignment.content_id)
			continue
		var definition := definitions_by_id[assignment.content_id] as BoardPlaceableDefinition
		if definition == null:
			errors.append("오브젝트 원형 정보가 올바르지 않습니다: %s" % assignment.content_id)
			continue
		for definition_error in definition.get_validation_errors():
			errors.append("%s: %s" % [assignment.content_id, definition_error])
		var object_type_id: StringName = definition.get_object_type_id()
		if not _is_role_compatible(point.get_type_id(), object_type_id):
			errors.append(
				"배치 지점의 역할과 오브젝트 종류가 맞지 않습니다: %s → %s"
				% [assignment.point_id, assignment.content_id]
			)
		if object_type_id == &"flipper":
			assigned_flipper_count += 1

	if assigned_flipper_count < MIN_FLIPPER_COUNT or assigned_flipper_count > MAX_FLIPPER_COUNT:
		errors.append(
			"웨이브에 실제 배치한 플리퍼는 1~4개여야 합니다. 현재 %d개입니다."
			% assigned_flipper_count
		)
	return errors


func is_valid(definitions_by_id: Dictionary = {}) -> bool:
	return get_validation_errors(definitions_by_id).is_empty()


func get_assignment(point_id: StringName) -> BoardPlacementAssignmentConfig:
	for assignment in assignments:
		if assignment != null and assignment.point_id == point_id:
			return assignment
	return null


func get_resolved_placements(definitions_by_id: Dictionary) -> Array[Dictionary]:
	if not get_validation_errors(definitions_by_id).is_empty():
		return []
	var placements: Array[Dictionary] = []
	for assignment in assignments:
		var point := layout_config.get_anchor(assignment.point_id)
		var placement := {
			"point_id": assignment.point_id,
			"content_id": assignment.content_id,
			"point": point,
			"definition": definitions_by_id[assignment.content_id],
			"board_position": layout_config.get_resolved_anchor_position(point),
			"rotation_degrees": point.rotation_degrees,
		}
		if point.get_type_id() == BoardAnchorConfig.TYPE_FLIPPER:
			placement["inward_direction"] = layout_config.get_resolved_flipper_direction(point)
		placements.append(placement)
	return placements


static func build_definition_map(
	definitions: Array[BoardPlaceableDefinition]
) -> Dictionary:
	var definitions_by_id: Dictionary = {}
	for definition in definitions:
		if definition == null or definition.content_id == &"":
			continue
		definitions_by_id[definition.content_id] = definition
	return definitions_by_id


static func get_definition_catalog_validation_errors(
	definitions: Array[BoardPlaceableDefinition]
) -> PackedStringArray:
	var errors := PackedStringArray()
	var known_content_ids: Dictionary = {}
	for definition_index in definitions.size():
		var definition := definitions[definition_index]
		if definition == null:
			errors.append("오브젝트 원형 목록의 %d번 항목이 비어 있습니다." % definition_index)
			continue
		errors.append_array(definition.get_validation_errors())
		if definition.content_id == &"":
			continue
		if known_content_ids.has(definition.content_id):
			errors.append("오브젝트 원형 이름이 중복됩니다: %s" % definition.content_id)
		else:
			known_content_ids[definition.content_id] = true
	return errors


func _is_role_compatible(point_type: StringName, object_type: StringName) -> bool:
	match point_type:
		BoardAnchorConfig.TYPE_BUMPER:
			return object_type == &"bumper"
		BoardAnchorConfig.TYPE_FLIPPER:
			return object_type == &"flipper"
		BoardAnchorConfig.TYPE_RELIC_SLOT:
			return object_type == &"relic_preview"
		BoardAnchorConfig.TYPE_OBJECT:
			return object_type == &"wall" or object_type == &"general"
		_:
			return false
