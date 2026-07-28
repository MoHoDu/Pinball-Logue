class_name PlayableBoard2D
extends Node2D

signal ball_exit_detected(shot_id: StringName, end_reason: StringName)

const END_REASON_DRAIN: StringName = &"drain"
const END_REASON_OUT_OF_BOUNDS: StringName = &"out_of_bounds"
const BALL_GROUP: StringName = &"pinball_ball_2d"
const GEOMETRY_EPSILON := 0.001

@export_node_path("BoardMockup2D") var board_mockup_path := NodePath("BoardMockup2D")
@export_range(1.0, 40.0, 1.0) var rail_collision_width := 12.0
@export_range(20.0, 240.0, 1.0) var drain_sensor_depth := 96.0
@export_range(20.0, 400.0, 1.0) var out_of_bounds_margin := 160.0

var _board_mockup: BoardMockup2D
var _rail_body: StaticBody2D
var _drain_area: Area2D
var _projected_bounds := Rect2()
var _ended_shot_ids: Dictionary = {}


func _ready() -> void:
	_board_mockup = get_node_or_null(board_mockup_path) as BoardMockup2D
	_rebuild_physics()


func _physics_process(_delta: float) -> void:
	if _board_mockup == null or _projected_bounds.size == Vector2.ZERO:
		return
	var safe_bounds := _projected_bounds.grow(out_of_bounds_margin)
	for candidate in get_tree().get_nodes_in_group(BALL_GROUP):
		if not candidate is Node2D or not is_ancestor_of(candidate):
			continue
		var local_position := to_local(candidate.global_position)
		if not safe_bounds.has_point(local_position):
			_emit_ball_exit_once(candidate, END_REASON_OUT_OF_BOUNDS)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _board_mockup == null:
		errors.append("플레이 보드에 2D 보드 목업이 연결되어 있지 않습니다.")
		return errors
	errors.append_array(_board_mockup.get_assembly_errors())
	if not is_finite(rail_collision_width) or rail_collision_width <= 0.0:
		errors.append("레일 충돌 두께는 양수여야 합니다.")
	if not is_finite(drain_sensor_depth) or drain_sensor_depth <= 0.0:
		errors.append("드레인 감지 깊이는 양수여야 합니다.")
	if not is_finite(out_of_bounds_margin) or out_of_bounds_margin <= 0.0:
		errors.append("보드 밖 안전 종료 여백은 양수여야 합니다.")
	return errors


func get_layout_config() -> BoardLayoutConfig:
	if _board_mockup == null:
		return null
	return _board_mockup.layout_config


func get_view_config() -> BoardViewConfig:
	if _board_mockup == null:
		return null
	return _board_mockup.view_config


func get_launch_anchor_id() -> StringName:
	var layout := get_layout_config()
	if layout == null:
		return &""
	return layout.launch_anchor_id


func get_launch_board_position() -> Vector2:
	var layout := get_layout_config()
	if layout == null:
		return Vector2(INF, INF)
	var launch_anchor := layout.get_anchor(layout.launch_anchor_id)
	if launch_anchor == null:
		return Vector2(INF, INF)
	return layout.get_resolved_anchor_position(launch_anchor)


func get_launch_forward_direction() -> Vector2:
	var layout := get_layout_config()
	var launch_position := get_launch_board_position()
	if layout == null or not _is_finite_vector(launch_position):
		return Vector2.ZERO
	var inward_direction := launch_position.direction_to(layout.get_board_center())
	if inward_direction.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
		return Vector2.UP
	return inward_direction


func board_to_local(board_position: Vector2) -> Vector2:
	var view := get_view_config()
	if view == null:
		return Vector2(INF, INF)
	return view.project_board_point(board_position)


func local_to_board(local_position: Vector2) -> Vector2:
	var view := get_view_config()
	if view == null:
		return Vector2(INF, INF)
	return view.unproject_board_point(local_position)


func board_velocity_to_local(board_position: Vector2, board_velocity: Vector2) -> Vector2:
	var view := get_view_config()
	if view == null:
		return Vector2.ZERO
	var sample_seconds := 0.01
	return (
		view.project_board_point(board_position + board_velocity * sample_seconds)
		- view.project_board_point(board_position)
	) / sample_seconds


func local_velocity_to_board(local_position: Vector2, local_velocity: Vector2) -> Vector2:
	var view := get_view_config()
	if view == null:
		return Vector2.ZERO
	var sample_seconds := 0.01
	return (
		view.unproject_board_point(local_position + local_velocity * sample_seconds)
		- view.unproject_board_point(local_position)
	) / sample_seconds


func get_board_width_pixels() -> float:
	var view := get_view_config()
	if view == null:
		return 0.0
	return view.board_size.x


func clear_finished_shot(shot_id: StringName) -> void:
	_ended_shot_ids.erase(shot_id)


func _rebuild_physics() -> void:
	_clear_generated_physics()
	if not get_validation_errors().is_empty():
		return
	var boundary := _board_mockup.get_projected_boundary()
	if boundary.size() < 3:
		return
	_projected_bounds = _get_bounds(boundary)
	_rail_body = StaticBody2D.new()
	_rail_body.name = "GeneratedRails"
	add_child(_rail_body)
	var drain_position := _board_mockup.get_projected_anchor_position(
		_board_mockup.layout_config.drain_anchor_id
	)
	var drain_edge_index := _find_closest_edge_index(boundary, drain_position)
	for edge_index in boundary.size():
		var edge_start := boundary[edge_index]
		var edge_end := boundary[(edge_index + 1) % boundary.size()]
		if edge_index == drain_edge_index:
			_add_split_drain_edge(edge_start, edge_end, drain_position)
		else:
			_add_rail_segment(edge_start, edge_end)
	_create_drain_sensor(drain_position)


func _clear_generated_physics() -> void:
	if is_instance_valid(_rail_body):
		_rail_body.queue_free()
	if is_instance_valid(_drain_area):
		_drain_area.queue_free()
	_rail_body = null
	_drain_area = null


func _add_split_drain_edge(edge_start: Vector2, edge_end: Vector2, drain_position: Vector2) -> void:
	var edge_vector := edge_end - edge_start
	var edge_length := edge_vector.length()
	if edge_length <= GEOMETRY_EPSILON:
		return
	var edge_direction := edge_vector / edge_length
	var closest_offset := clampf((drain_position - edge_start).dot(edge_direction), 0.0, edge_length)
	var half_gap := minf(_board_mockup.view_config.drain_width * 0.5, edge_length * 0.45)
	var gap_start := edge_start + edge_direction * maxf(0.0, closest_offset - half_gap)
	var gap_end := edge_start + edge_direction * minf(edge_length, closest_offset + half_gap)
	_add_rail_segment(edge_start, gap_start)
	_add_rail_segment(gap_end, edge_end)


func _add_rail_segment(point_a: Vector2, point_b: Vector2) -> void:
	if point_a.distance_squared_to(point_b) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
		return
	var collision := CollisionShape2D.new()
	var segment := point_b - point_a
	var shape := CapsuleShape2D.new()
	shape.radius = rail_collision_width * 0.5
	shape.height = segment.length() + rail_collision_width
	collision.shape = shape
	collision.position = point_a.lerp(point_b, 0.5)
	collision.rotation = segment.angle() + PI * 0.5
	_rail_body.add_child(collision)


func _create_drain_sensor(drain_position: Vector2) -> void:
	_drain_area = Area2D.new()
	_drain_area.name = "DrainSensor"
	_drain_area.collision_layer = 0
	_drain_area.collision_mask = 1
	_drain_area.monitoring = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(_board_mockup.view_config.drain_width, drain_sensor_depth)
	collision.shape = shape
	collision.position = drain_position + Vector2(0.0, drain_sensor_depth * 0.45)
	_drain_area.add_child(collision)
	add_child(_drain_area)
	_drain_area.body_entered.connect(_on_drain_body_entered)


func _on_drain_body_entered(body: Node2D) -> void:
	_emit_ball_exit_once(body, END_REASON_DRAIN)


func _emit_ball_exit_once(body: Node, end_reason: StringName) -> void:
	if not body.has_meta("shot_id"):
		return
	var shot_id := StringName(body.get_meta("shot_id", ""))
	if shot_id == &"" or _ended_shot_ids.has(shot_id):
		return
	_ended_shot_ids[shot_id] = true
	ball_exit_detected.emit(shot_id, end_reason)


func _find_closest_edge_index(boundary: PackedVector2Array, point: Vector2) -> int:
	var best_index := -1
	var best_distance_squared := INF
	for edge_index in boundary.size():
		var closest := Geometry2D.get_closest_point_to_segment(
			point,
			boundary[edge_index],
			boundary[(edge_index + 1) % boundary.size()]
		)
		var distance_squared := point.distance_squared_to(closest)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_index = edge_index
	return best_index


func _get_bounds(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
