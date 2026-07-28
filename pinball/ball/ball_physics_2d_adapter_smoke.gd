extends SceneTree

const WORLD_SCALE := 200.0
const EPSILON := 0.01

var _failures := PackedStringArray()
var _container: Node2D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_container = Node2D.new()
	_container.position = Vector2(640.0, 382.0)
	root.add_child(_container)
	var definition := load(
		"res://pinball/ball/standard_ball_definition.tres"
	) as BallDefinition
	var adapter := BallPhysics2DAdapter.new()
	_expect_empty(
		adapter.configure(
			_container,
			_board_to_world_position,
			_world_to_board_position,
			_board_to_world_velocity,
			_world_to_board_velocity,
			_board_radius_to_world
		),
		"2D 어댑터 설정"
	)
	_expect_empty(
		adapter.prepare_ball(&"shot_1", &"slot_2", definition, Vector2(0.1, 0.2)),
		"2D 공 준비"
	)
	if not adapter.prepare_ball(&"shot_2", &"slot_3", definition, Vector2.ZERO).is_empty():
		pass
	else:
		_failures.append("활성 공 1개 제한")

	var ball := adapter.get_active_ball_2d()
	if ball == null:
		_failures.append("활성 2D 공 조회")
	else:
		_expect_near(ball.mass, definition.physics_profile.mass, "질량")
		_expect_near(ball.gravity_scale, definition.physics_profile.gravity_scale, "중력 영향")
		_expect_near(ball.linear_damp, definition.physics_profile.linear_damping, "직선 감쇠")
		_expect_near(ball.angular_damp, definition.physics_profile.angular_damping, "회전 감쇠")
		if ball.can_sleep != definition.physics_profile.can_sleep:
			_failures.append("물리 휴면")
		if ball.continuous_cd != RigidBody2D.CCD_MODE_CAST_SHAPE:
			_failures.append("연속 충돌 검사")
		if ball.physics_material_override == null:
			_failures.append("물리 재질")
		else:
			_expect_near(
				ball.physics_material_override.bounce,
				definition.physics_profile.bounce,
				"반발력"
			)
			_expect_near(
				ball.physics_material_override.friction,
				definition.physics_profile.friction,
				"마찰"
			)
		var shape := ball.get_node("CollisionShape2D") as CollisionShape2D
		var circle := shape.shape as CircleShape2D
		_expect_near(
			circle.radius,
			definition.physics_profile.radius_board_ratio * WORLD_SCALE,
			"공 반지름"
		)

	var wrong_solution := _make_solution(&"shot_wrong", &"slot_2", definition.ball_id)
	if adapter.apply_launch(wrong_solution).is_empty():
		_failures.append("발사 식별자 불일치 거부")
	var solution := _make_solution(&"shot_1", &"slot_2", definition.ball_id)
	_expect_empty(adapter.apply_launch(solution), "2D 공 발사")
	if adapter.apply_launch(solution).is_empty():
		_failures.append("중복 발사 거부")

	var snapshot := adapter.get_snapshot(&"shot_1")
	if snapshot == null:
		_failures.append("보드 좌표 상태 조회")
	else:
		_expect_vector_near(snapshot.board_position, Vector2(0.1, 0.2), "보드 위치")
		_expect_vector_near(
			snapshot.board_velocity,
			solution.initial_board_velocity,
			"보드 속도"
		)
	if adapter.get_snapshot(&"shot_wrong") != null:
		_failures.append("잘못된 발사 상태 조회 거부")

	ball = adapter.get_active_ball_2d()
	ball.linear_velocity = Vector2(WORLD_SCALE * 30.0, 0.0)
	await physics_frame
	await physics_frame
	snapshot = adapter.get_snapshot(&"shot_1")
	if (
		snapshot == null
		or snapshot.board_velocity.length()
		> definition.physics_profile.max_linear_speed_board_per_second + EPSILON
	):
		_failures.append("최대 보드 속도 제한")

	if adapter.remove_ball(&"shot_wrong").is_empty():
		_failures.append("제거 발사 식별자 불일치 거부")
	_expect_empty(adapter.remove_ball(&"shot_1"), "안전한 공 제거")
	if adapter.has_active_ball():
		_failures.append("제거 뒤 활성 공 해제")
	if adapter.prepare_ball(&"shot_2", &"slot_3", definition, Vector2.ZERO).is_empty():
		_failures.append("queue_free 대기 중 새 공 생성 거부")
	if get_nodes_in_group(&"pinball_ball_2d").size() > 1:
		_failures.append("queue_free 대기 중 2D 공 노드 0/1 제한")
	if adapter.remove_ball(&"shot_1").is_empty():
		_failures.append("중복 제거 거부")
	await process_frame
	_expect_empty(
		adapter.prepare_ball(&"shot_2", &"slot_3", definition, Vector2.ZERO),
		"제거 완료 뒤 다음 2D 공 준비"
	)
	if get_nodes_in_group(&"pinball_ball_2d").size() != 1:
		_failures.append("제거 완료 뒤 활성 2D 공 노드 1개")
	_expect_empty(adapter.remove_ball(&"shot_2"), "다음 2D 공 제거")
	await process_frame

	if _failures.is_empty():
		print("BALL_PHYSICS_2D_ADAPTER_SMOKE: PASS")
		quit(0)
	else:
		push_error("BALL_PHYSICS_2D_ADAPTER_SMOKE: FAIL - %s" % ", ".join(_failures))
		quit(1)


func _make_solution(
	shot_id: StringName,
	slot_id: StringName,
	ball_id: StringName
) -> LaunchSolution:
	var solution := LaunchSolution.new()
	solution.request_id = &"request_1"
	solution.shot_id = shot_id
	solution.slot_id = slot_id
	solution.ball_id = ball_id
	solution.launch_anchor_id = &"launch_main"
	solution.board_direction = Vector2.UP
	solution.normalized_strength = 0.5
	solution.speed_board_per_second = 2.0
	solution.initial_board_velocity = Vector2(0.0, -2.0)
	return solution


func _board_to_world_position(board_position: Vector2) -> Vector2:
	return board_position * WORLD_SCALE


func _world_to_board_position(world_position: Vector2) -> Vector2:
	return world_position / WORLD_SCALE


func _board_to_world_velocity(_board_position: Vector2, board_velocity: Vector2) -> Vector2:
	return board_velocity * WORLD_SCALE


func _world_to_board_velocity(_world_position: Vector2, world_velocity: Vector2) -> Vector2:
	return world_velocity / WORLD_SCALE


func _board_radius_to_world(_board_position: Vector2, board_radius: float) -> float:
	return board_radius * WORLD_SCALE


func _expect_empty(value: String, label: String) -> void:
	if not value.is_empty():
		_failures.append("%s: %s" % [label, value])


func _expect_near(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > EPSILON:
		_failures.append("%s: %.4f != %.4f" % [label, actual, expected])


func _expect_vector_near(actual: Vector2, expected: Vector2, label: String) -> void:
	if actual.distance_to(expected) > EPSILON:
		_failures.append("%s: %s != %s" % [label, actual, expected])
