@tool
class_name BoardLayoutConfig
extends Resource

const POSITION_LIMIT := 0.5
const GEOMETRY_EPSILON := 0.00001
const PATH_SAMPLE_COUNT := 32
const MIN_FLIPPER_COUNT := 1
const MAX_FLIPPER_COUNT := 4

@export var boundary_points := PackedVector2Array([
	Vector2(-0.5, -0.5),
	Vector2(0.5, -0.5),
	Vector2(0.5, 0.5),
	Vector2(-0.5, 0.5),
])
@export var anchors: Array[BoardAnchorConfig] = []
@export var launch_anchor_id: StringName = &"launch_main"
@export var drain_anchor_id: StringName = &"drain_main"


func get_validation_errors() -> PackedStringArray:
	var errors := _get_boundary_validation_errors()
	var anchor_ids: Dictionary = {}

	for anchor_index in anchors.size():
		var anchor := anchors[anchor_index]
		if anchor == null:
			errors.append("배치 지점 목록의 %d번 참조가 비어 있습니다." % anchor_index)
			continue
		for anchor_error in anchor.get_validation_errors():
			errors.append(anchor_error)
		if anchor.anchor_id != &"":
			if anchor_ids.has(anchor.anchor_id):
				errors.append("배치 지점 이름이 중복됩니다: %s" % anchor.anchor_id)
			else:
				anchor_ids[anchor.anchor_id] = true
		if anchor.snap_to_boundary and anchor.get_type_id() == BoardAnchorConfig.TYPE_FLIPPER:
			if anchor.boundary_edge_index < 0 or anchor.boundary_edge_index >= boundary_points.size():
				errors.append("플리퍼 지점이 참조하는 보드 외곽선 변을 찾을 수 없습니다: %s" % anchor.anchor_id)
		elif not is_board_position_in_bounds(anchor.board_position):
			errors.append("배치 지점이 보드 경계 밖에 있습니다: %s" % anchor.anchor_id)

	var flipper_count := get_anchors_by_type(BoardAnchorConfig.TYPE_FLIPPER).size()
	if flipper_count < MIN_FLIPPER_COUNT or flipper_count > MAX_FLIPPER_COUNT:
		errors.append(
			"플리퍼 배치 지점은 1~4개여야 합니다. 현재 %d개입니다." % flipper_count
		)

	_validate_required_anchor(launch_anchor_id, BoardAnchorConfig.TYPE_LAUNCH, "발사", errors)
	_validate_required_anchor(drain_anchor_id, BoardAnchorConfig.TYPE_DRAIN, "드레인", errors)

	if errors.is_empty() and not has_launch_to_drain_path():
		errors.append("발사 지점에서 드레인 지점까지 보드 안의 직선 경로가 없습니다.")
	return errors


func get_anchor(anchor_id: StringName) -> BoardAnchorConfig:
	for anchor in anchors:
		if anchor != null and anchor.anchor_id == anchor_id:
			return anchor
	return null


func get_anchors_by_type(anchor_type: StringName) -> Array[BoardAnchorConfig]:
	var matches: Array[BoardAnchorConfig] = []
	for anchor in anchors:
		if anchor != null and anchor.get_type_id() == anchor_type:
			matches.append(anchor)
	return matches


func get_closed_boundary_points() -> PackedVector2Array:
	var closed_points := PackedVector2Array(boundary_points)
	if not boundary_points.is_empty():
		closed_points.append(boundary_points[0])
	return closed_points


func get_boundary_position(edge_index: int, edge_offset: float) -> Vector2:
	if boundary_points.is_empty() or edge_index < 0 or edge_index >= boundary_points.size():
		return Vector2(INF, INF)
	var edge_start := boundary_points[edge_index]
	var edge_end := boundary_points[(edge_index + 1) % boundary_points.size()]
	return edge_start.lerp(edge_end, clampf(edge_offset, 0.0, 1.0))


func get_closest_boundary_location(board_position: Vector2) -> Dictionary:
	if boundary_points.size() < 2:
		return {}
	var closest_edge_index := -1
	var closest_edge_offset := 0.0
	var closest_position := Vector2.ZERO
	var closest_distance_squared := INF
	for edge_index in boundary_points.size():
		var edge_start := boundary_points[edge_index]
		var edge_end := boundary_points[(edge_index + 1) % boundary_points.size()]
		var edge_vector := edge_end - edge_start
		if edge_vector.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			continue
		var edge_offset := clampf(
			(board_position - edge_start).dot(edge_vector) / edge_vector.length_squared(),
			0.0,
			1.0
		)
		var candidate_position := edge_start + edge_vector * edge_offset
		var distance_squared := board_position.distance_squared_to(candidate_position)
		if distance_squared < closest_distance_squared:
			closest_edge_index = edge_index
			closest_edge_offset = edge_offset
			closest_position = candidate_position
			closest_distance_squared = distance_squared
	if closest_edge_index < 0:
		return {}
	return {
		"edge_index": closest_edge_index,
		"edge_offset": closest_edge_offset,
		"board_position": closest_position,
		"distance_squared": closest_distance_squared,
	}


func get_boundary_inward_direction(edge_index: int) -> Vector2:
	if boundary_points.size() < 3 or edge_index < 0 or edge_index >= boundary_points.size():
		return Vector2.ZERO
	var edge_start := boundary_points[edge_index]
	var edge_end := boundary_points[(edge_index + 1) % boundary_points.size()]
	var edge_direction := (edge_end - edge_start).normalized()
	if edge_direction == Vector2.ZERO:
		return Vector2.ZERO
	if _get_signed_area() > 0.0:
		return Vector2(-edge_direction.y, edge_direction.x)
	return Vector2(edge_direction.y, -edge_direction.x)


func get_resolved_anchor_position(anchor: BoardAnchorConfig) -> Vector2:
	if anchor == null:
		return Vector2(INF, INF)
	if anchor.get_type_id() == BoardAnchorConfig.TYPE_FLIPPER and anchor.snap_to_boundary:
		return get_boundary_position(anchor.boundary_edge_index, anchor.boundary_edge_offset)
	return anchor.board_position


func get_resolved_flipper_direction(anchor: BoardAnchorConfig) -> Vector2:
	if anchor == null or anchor.get_type_id() != BoardAnchorConfig.TYPE_FLIPPER:
		return Vector2.ZERO
	if anchor.snap_to_boundary:
		return get_boundary_inward_direction(anchor.boundary_edge_index).rotated(
			deg_to_rad(anchor.rotation_degrees)
		)
	return Vector2.RIGHT.rotated(deg_to_rad(anchor.rotation_degrees))


func snap_flipper_anchor_to_boundary(
	anchor: BoardAnchorConfig,
	desired_position: Vector2
) -> bool:
	if anchor == null or anchor.get_type_id() != BoardAnchorConfig.TYPE_FLIPPER:
		return false
	var location := get_closest_boundary_location(desired_position)
	if location.is_empty():
		return false
	anchor.snap_to_boundary = true
	anchor.boundary_edge_index = location["edge_index"]
	anchor.boundary_edge_offset = location["edge_offset"]
	anchor.board_position = location["board_position"]
	return true


func is_board_position_in_bounds(board_position: Vector2) -> bool:
	if boundary_points.size() < 3:
		return false
	if _is_point_on_boundary(board_position):
		return true
	return Geometry2D.is_point_in_polygon(board_position, boundary_points)


func has_launch_to_drain_path() -> bool:
	var launch_anchor := get_anchor(launch_anchor_id)
	var drain_anchor := get_anchor(drain_anchor_id)
	if launch_anchor == null or drain_anchor == null:
		return false
	for sample_index in PATH_SAMPLE_COUNT + 1:
		var weight := float(sample_index) / float(PATH_SAMPLE_COUNT)
		var sample_position := launch_anchor.board_position.lerp(
			drain_anchor.board_position,
			weight
		)
		if not is_board_position_in_bounds(sample_position):
			return false
	return true


func _get_boundary_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if boundary_points.size() < 3:
		errors.append("보드 경계는 서로 다른 꼭짓점이 3개 이상이어야 합니다.")
		return errors

	for point_index in boundary_points.size():
		var point := boundary_points[point_index]
		if not is_finite(point.x) or not is_finite(point.y):
			errors.append("보드 경계 좌표는 유한한 값이어야 합니다: %d" % point_index)
			continue
		if absf(point.x) > POSITION_LIMIT or absf(point.y) > POSITION_LIMIT:
			errors.append("보드 경계 좌표는 -0.5~0.5 범위여야 합니다: %d" % point_index)
		var next_point := boundary_points[(point_index + 1) % boundary_points.size()]
		if point.distance_squared_to(next_point) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			errors.append("보드 경계에 길이가 0인 변이 있습니다: %d" % point_index)

	for first_index in boundary_points.size():
		for second_index in range(first_index + 1, boundary_points.size()):
			if boundary_points[first_index].distance_squared_to(boundary_points[second_index]) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
				errors.append("보드 경계 꼭짓점이 중복됩니다: %d, %d" % [first_index, second_index])

	if absf(_get_signed_area()) <= GEOMETRY_EPSILON:
		errors.append("보드 경계 면적은 0보다 커야 합니다.")
	if _has_self_intersection():
		errors.append("보드 경계는 자기 교차할 수 없습니다.")
	if not _is_convex():
		errors.append("현재 보드 경계는 단순 볼록 다각형이어야 합니다.")
	return errors


func _validate_required_anchor(
	anchor_id: StringName,
	expected_type: StringName,
	label: String,
	errors: PackedStringArray
) -> void:
	if anchor_id == &"":
		errors.append("%s 지점 선택은 비어 있을 수 없습니다." % label)
		return
	var anchor := get_anchor(anchor_id)
	if anchor == null:
		errors.append("선택한 %s 지점을 찾을 수 없습니다: %s" % [label, anchor_id])
		return
	if anchor.get_type_id() != expected_type:
		errors.append("선택한 %s 지점의 종류가 올바르지 않습니다: %s" % [label, anchor_id])


func _get_signed_area() -> float:
	var doubled_area := 0.0
	for point_index in boundary_points.size():
		var current_point := boundary_points[point_index]
		var next_point := boundary_points[(point_index + 1) % boundary_points.size()]
		doubled_area += current_point.cross(next_point)
	return doubled_area * 0.5


func _is_convex() -> bool:
	var winding_sign := 0
	for point_index in boundary_points.size():
		var first_point := boundary_points[point_index]
		var second_point := boundary_points[(point_index + 1) % boundary_points.size()]
		var third_point := boundary_points[(point_index + 2) % boundary_points.size()]
		var cross_product := (second_point - first_point).cross(third_point - second_point)
		if absf(cross_product) <= GEOMETRY_EPSILON:
			continue
		var current_sign := 1 if cross_product > 0.0 else -1
		if winding_sign == 0:
			winding_sign = current_sign
		elif winding_sign != current_sign:
			return false
	return winding_sign != 0


func _has_self_intersection() -> bool:
	for first_edge_index in boundary_points.size():
		var first_edge_end_index := (first_edge_index + 1) % boundary_points.size()
		for second_edge_index in range(first_edge_index + 1, boundary_points.size()):
			var second_edge_end_index := (second_edge_index + 1) % boundary_points.size()
			if first_edge_index == second_edge_end_index or first_edge_end_index == second_edge_index:
				continue
			var intersection: Variant = Geometry2D.segment_intersects_segment(
				boundary_points[first_edge_index],
				boundary_points[first_edge_end_index],
				boundary_points[second_edge_index],
				boundary_points[second_edge_end_index]
			)
			if intersection != null:
				return true
	return false


func _is_point_on_boundary(point: Vector2) -> bool:
	for point_index in boundary_points.size():
		var edge_start := boundary_points[point_index]
		var edge_end := boundary_points[(point_index + 1) % boundary_points.size()]
		var edge_vector := edge_end - edge_start
		if edge_vector.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			continue
		var edge_weight := clampf(
			(point - edge_start).dot(edge_vector) / edge_vector.length_squared(),
			0.0,
			1.0
		)
		var closest_point := edge_start + edge_vector * edge_weight
		if point.distance_squared_to(closest_point) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			return true
	return false
