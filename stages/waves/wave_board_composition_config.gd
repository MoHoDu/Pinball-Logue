@tool
class_name WaveBoardCompositionConfig
extends Resource

const MIN_FLIPPER_COUNT := 1
const MAX_FLIPPER_COUNT := 4

@export var layout_config: BoardLayoutConfig
@export var assignments: Array[BoardPlacementAssignmentConfig] = []
@export var flipper_control_targets: Array[FlipperControlTargetConfig] = []


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
	errors.append_array(_get_flipper_control_target_validation_errors(definitions_by_id))
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


func get_resolved_flipper_control_targets(definitions_by_id: Dictionary) -> Array[Dictionary]:
	if layout_config == null:
		return []
	var targets := _get_effective_flipper_control_targets(definitions_by_id)
	if targets.is_empty() or not _get_flipper_control_target_validation_errors(definitions_by_id).is_empty():
		return []
	var target_positions: Array[Vector2] = []
	for target in targets:
		target_positions.append(_get_control_target_position(target))
	var directions := _get_unique_direction_assignments(target_positions)
	if directions.size() != targets.size():
		return []

	var resolved: Array[Dictionary] = []
	for target_index in targets.size():
		var target := targets[target_index]
		resolved.append({
			"mode": target.get_mode_id(),
			"left_point_id": target.left_point_id,
			"right_point_id": target.right_point_id,
			"point_ids": target.get_point_ids(),
			"direction_id": directions[target_index],
			"board_position": target_positions[target_index],
		})
	return resolved


func get_flipper_control_target_for_direction(
	direction_id: StringName,
	definitions_by_id: Dictionary
) -> Dictionary:
	for target in get_resolved_flipper_control_targets(definitions_by_id):
		if target["direction_id"] == direction_id:
			return target
	return {}


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


func _get_flipper_control_target_validation_errors(
	definitions_by_id: Dictionary
) -> PackedStringArray:
	var errors := PackedStringArray()
	if layout_config == null:
		return errors
	var flipper_assignments := _get_flipper_assignments_by_point_id(definitions_by_id)
	if flipper_assignments.is_empty():
		return errors
	var targets := _get_effective_flipper_control_targets(definitions_by_id)
	var used_point_ids: Dictionary = {}
	for target_index in targets.size():
		var target := targets[target_index]
		if target == null:
			errors.append("플리퍼 조작 대상 %d번 항목이 비어 있습니다." % target_index)
			continue
		for target_error in target.get_validation_errors():
			errors.append("플리퍼 조작 대상 %d번: %s" % [target_index, target_error])
		for point_id in target.get_point_ids():
			var point := layout_config.get_anchor(point_id)
			if point == null:
				errors.append("플리퍼 조작 대상이 참조하는 배치 지점을 찾을 수 없습니다: %s" % point_id)
				continue
			if point.get_type_id() != BoardAnchorConfig.TYPE_FLIPPER:
				errors.append("플리퍼 조작 대상에는 플리퍼 지점만 사용할 수 있습니다: %s" % point_id)
			if not flipper_assignments.has(point_id):
				errors.append("플리퍼 조작 대상 지점에 실제 플리퍼가 배치되어 있지 않습니다: %s" % point_id)
			if used_point_ids.has(point_id):
				errors.append("같은 플리퍼를 둘 이상의 조작 대상에 넣을 수 없습니다: %s" % point_id)
			else:
				used_point_ids[point_id] = true
		_validate_flipper_target_roles(target, target_index, errors)

	for point_id in flipper_assignments:
		if not used_point_ids.has(point_id):
			errors.append("배치된 플리퍼에는 조작 대상이 정확히 하나 필요합니다: %s" % point_id)
	if not errors.is_empty():
		return errors

	var positions: Array[Vector2] = []
	for target in targets:
		positions.append(_get_control_target_position(target))
	if _get_unique_direction_assignments(positions).size() != targets.size():
		errors.append("플리퍼 조작 대상의 보드 상대 위치에서 고유 방향키를 배정할 수 없습니다.")
	return errors


func _validate_flipper_target_roles(
	target: FlipperControlTargetConfig,
	target_index: int,
	errors: PackedStringArray
) -> void:
	if target == null or layout_config == null:
		return
	var board_center := layout_config.get_board_center()
	var left_point := layout_config.get_anchor(target.left_point_id)
	var right_point := layout_config.get_anchor(target.right_point_id)
	match target.get_mode_id():
		FlipperControlTargetConfig.MODE_LEFT_ONLY:
			if left_point != null and layout_config.get_resolved_anchor_position(left_point).x >= board_center.x:
				errors.append("플리퍼 조작 대상 %d번: 왼쪽 플리퍼 지점은 보드 중심의 왼쪽에 있어야 합니다." % target_index)
		FlipperControlTargetConfig.MODE_RIGHT_ONLY:
			if right_point != null and layout_config.get_resolved_anchor_position(right_point).x <= board_center.x:
				errors.append("플리퍼 조작 대상 %d번: 오른쪽 플리퍼 지점은 보드 중심의 오른쪽에 있어야 합니다." % target_index)
		FlipperControlTargetConfig.MODE_PAIR:
			if left_point != null and right_point != null:
				var left_position := layout_config.get_resolved_anchor_position(left_point)
				var right_position := layout_config.get_resolved_anchor_position(right_point)
				if left_position.x >= right_position.x:
					errors.append("플리퍼 조작 대상 %d번: 좌우 쌍의 왼쪽 지점은 오른쪽 지점보다 화면상 왼쪽에 있어야 합니다." % target_index)


func _get_flipper_assignments_by_point_id(definitions_by_id: Dictionary) -> Dictionary:
	var flipper_assignments: Dictionary = {}
	for assignment in assignments:
		if assignment == null or assignment.point_id == &"" or assignment.content_id == &"":
			continue
		var definition := definitions_by_id.get(assignment.content_id) as BoardPlaceableDefinition
		if definition != null and definition.get_object_type_id() == &"flipper":
			flipper_assignments[assignment.point_id] = assignment
	return flipper_assignments


func _get_effective_flipper_control_targets(
	definitions_by_id: Dictionary
) -> Array[FlipperControlTargetConfig]:
	if not flipper_control_targets.is_empty():
		return flipper_control_targets
	var compatible_targets: Array[FlipperControlTargetConfig] = []
	if layout_config == null:
		return compatible_targets
	var board_center := layout_config.get_board_center()
	var flipper_assignments := _get_flipper_assignments_by_point_id(definitions_by_id)
	var point_ids: Array = flipper_assignments.keys()
	point_ids.sort_custom(func(first: StringName, second: StringName) -> bool:
		var first_position := layout_config.get_resolved_anchor_position(layout_config.get_anchor(first))
		var second_position := layout_config.get_resolved_anchor_position(layout_config.get_anchor(second))
		if not is_equal_approx(first_position.x, second_position.x):
			return first_position.x < second_position.x
		if not is_equal_approx(first_position.y, second_position.y):
			return first_position.y < second_position.y
		return String(first) < String(second)
	)
	for point_id in point_ids:
		var target := FlipperControlTargetConfig.new()
		var position := layout_config.get_resolved_anchor_position(layout_config.get_anchor(point_id))
		if position.x < board_center.x:
			target.set_mode_id(FlipperControlTargetConfig.MODE_LEFT_ONLY)
			target.left_point_id = point_id
		else:
			target.set_mode_id(FlipperControlTargetConfig.MODE_RIGHT_ONLY)
			target.right_point_id = point_id
		compatible_targets.append(target)
	return compatible_targets


func _get_control_target_position(target: FlipperControlTargetConfig) -> Vector2:
	var positions: Array[Vector2] = []
	for point_id in target.get_point_ids():
		var point := layout_config.get_anchor(point_id)
		if point != null:
			positions.append(layout_config.get_resolved_anchor_position(point))
	if positions.is_empty():
		return Vector2(INF, INF)
	var midpoint := Vector2.ZERO
	for position in positions:
		midpoint += position
	return midpoint / float(positions.size())


func _get_unique_direction_assignments(target_positions: Array[Vector2]) -> Array[StringName]:
	if target_positions.is_empty() or target_positions.size() > BoardLayoutConfig.FLIPPER_DIRECTION_IDS.size():
		return []
	if target_positions.size() == 2:
		var separation := target_positions[1] - target_positions[0]
		if separation.is_zero_approx():
			return []
		var paired_directions: Array[StringName] = []
		if absf(separation.x) >= absf(separation.y):
			paired_directions.append(
				BoardLayoutConfig.FLIPPER_DIRECTION_LEFT
				if separation.x > 0.0
				else BoardLayoutConfig.FLIPPER_DIRECTION_RIGHT
			)
			paired_directions.append(
				BoardLayoutConfig.FLIPPER_DIRECTION_RIGHT
				if separation.x > 0.0
				else BoardLayoutConfig.FLIPPER_DIRECTION_LEFT
			)
			return paired_directions
		paired_directions.append(
			BoardLayoutConfig.FLIPPER_DIRECTION_UP
			if separation.y > 0.0
			else BoardLayoutConfig.FLIPPER_DIRECTION_DOWN
		)
		paired_directions.append(
			BoardLayoutConfig.FLIPPER_DIRECTION_DOWN
			if separation.y > 0.0
			else BoardLayoutConfig.FLIPPER_DIRECTION_UP
		)
		return paired_directions
	var center := layout_config.get_board_center()
	var relative_directions: Array[Vector2] = []
	for position in target_positions:
		var relative := position - center
		if not is_finite(relative.x) or not is_finite(relative.y) or relative.is_zero_approx():
			return []
		relative_directions.append(relative.normalized())

	var search_state := {
		"best_cost": INF,
		"directions": Array([], TYPE_STRING_NAME, "", null),
	}
	_find_best_control_target_direction(
		relative_directions,
		0,
		{},
		Array([], TYPE_STRING_NAME, "", null),
		0.0,
		search_state
	)
	return search_state["directions"]


func _find_best_control_target_direction(
	relative_directions: Array[Vector2],
	target_index: int,
	used_directions: Dictionary,
	current_directions: Array[StringName],
	current_cost: float,
	search_state: Dictionary
) -> void:
	if target_index >= relative_directions.size():
		if current_cost < float(search_state["best_cost"]) - BoardLayoutConfig.DIRECTION_COST_EPSILON:
			search_state["best_cost"] = current_cost
			search_state["directions"] = current_directions.duplicate()
		return
	for direction_id in BoardLayoutConfig.FLIPPER_DIRECTION_IDS:
		if used_directions.has(direction_id):
			continue
		var next_cost := current_cost + _get_direction_cost(
			relative_directions[target_index],
			direction_id
		)
		if next_cost > float(search_state["best_cost"]) + BoardLayoutConfig.DIRECTION_COST_EPSILON:
			continue
		used_directions[direction_id] = true
		current_directions.append(direction_id)
		_find_best_control_target_direction(
			relative_directions,
			target_index + 1,
			used_directions,
			current_directions,
			next_cost,
			search_state
		)
		current_directions.pop_back()
		used_directions.erase(direction_id)


func _get_direction_cost(relative_direction: Vector2, direction_id: StringName) -> float:
	var input_direction := Vector2.ZERO
	match direction_id:
		BoardLayoutConfig.FLIPPER_DIRECTION_LEFT:
			input_direction = Vector2.LEFT
		BoardLayoutConfig.FLIPPER_DIRECTION_RIGHT:
			input_direction = Vector2.RIGHT
		BoardLayoutConfig.FLIPPER_DIRECTION_UP:
			input_direction = Vector2.UP
		BoardLayoutConfig.FLIPPER_DIRECTION_DOWN:
			input_direction = Vector2.DOWN
		_:
			return INF
	return acos(clampf(relative_direction.dot(input_direction), -1.0, 1.0))
