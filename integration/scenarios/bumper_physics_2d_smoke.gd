extends SceneTree

const BALL_SCENE := preload("res://pinball/ball/ball_2d.tscn")
const BALL_PROFILE := preload("res://pinball/ball/standard_ball_physics_profile.tres")
const NORMAL_PRESENTATION := preload("res://stages/boards/prefabs_2d/normal_bumper_2d.tscn")
const WORLD_SCALE := 500.0

var _failures := PackedStringArray()
var _hit_results: Array[BumperHitResult] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var parent := Node2D.new()
	root.add_child(parent)
	var adapter := BumperPhysics2DAdapter.new()
	var configure_error := adapter.configure(
		parent,
		func(world_position: Vector2) -> Vector2: return world_position / WORLD_SCALE,
		func(board_position: Vector2) -> Vector2: return board_position * WORLD_SCALE,
		func(_world_position: Vector2, world_velocity: Vector2) -> Vector2: return world_velocity / WORLD_SCALE,
		func(_board_position: Vector2, board_velocity: Vector2) -> Vector2: return board_velocity * WORLD_SCALE,
		func(_board_position: Vector2, radius: float) -> float: return radius * WORLD_SCALE
	)
	_expect(configure_error.is_empty(), "2D 범퍼 어댑터를 설정하지 못했습니다: %s" % configure_error)
	adapter.hit_applied.connect(_on_hit_applied)
	var definition := ResourceLoader.load("res://pinball/objects/bounce_bumper_definition.tres") as BumperDefinition
	definition = definition.duplicate(true) as BumperDefinition
	definition.max_durability = 20
	var bumper_container := Node2D.new()
	parent.add_child(bumper_container)
	var runtime := BumperRuntime2D.new()
	var runtime_error := runtime.configure(&"bumper_high_speed", definition, 20.0, 5.0, NORMAL_PRESENTATION)
	_expect(runtime_error.is_empty(), "2D 범퍼를 설정하지 못했습니다: %s" % runtime_error)
	bumper_container.add_child(runtime)
	runtime.global_position = Vector2.ZERO
	_expect(adapter.register_bumper(runtime, definition, {"point_id": &"bumper_high_speed"}).is_empty(), "2D 범퍼를 어댑터에 등록하지 못했습니다.")

	var ball := BALL_SCENE.instantiate() as Ball2D
	parent.add_child(ball)
	var ball_error := ball.configure(
		BALL_PROFILE,
		12.0,
		func(_board_position: Vector2, board_velocity: Vector2) -> Vector2: return board_velocity * WORLD_SCALE,
		func(world_position: Vector2) -> Vector2: return world_position / WORLD_SCALE,
		func(_world_position: Vector2, world_velocity: Vector2) -> Vector2: return world_velocity / WORLD_SCALE
	)
	_expect(ball_error.is_empty(), "고속 충돌 시험 공을 설정하지 못했습니다: %s" % ball_error)
	ball.gravity_scale = 0.0
	ball.freeze = false
	ball.add_to_group(&"pinball_ball_2d")
	ball.set_meta(&"shot_id", &"shot_high_speed")
	ball.set_meta(&"ball_id", &"standard_ball")
	ball.global_position = Vector2.ZERO
	ball.linear_velocity = Vector2.ZERO
	_expect(not runtime.is_safe_clear_for_balls(0.016), "실제 플레이 보드의 형제 공을 안전 복구 검사에서 건너뛰었습니다.")
	ball.global_position = Vector2(-100.0, 0.0)
	ball.linear_velocity = Vector2(BALL_PROFILE.max_linear_speed_board_per_second * WORLD_SCALE, 0.0)
	_expect(not runtime.is_safe_clear_for_balls(0.2), "공의 예상 이동 경로가 안전 복구 영역을 통과하는데 복구 가능으로 판정했습니다.")
	adapter.physics_tick(0.2)
	_expect(_hit_results.size() == 1, "최대 속도 이동 경로에서 범퍼 타격을 정확히 한 번 감지하지 못했습니다: %d" % _hit_results.size())
	_expect(ball.global_position.x < 0.0, "고속 공이 범퍼 중심을 관통했습니다: %s" % ball.global_position)
	_expect(ball.linear_velocity.x < 0.0, "반동 범퍼가 고속 공을 반사하지 못했습니다: %s" % ball.linear_velocity)
	_expect(ball.linear_velocity.length() <= BALL_PROFILE.max_linear_speed_board_per_second * WORLD_SCALE + 0.01, "반동 뒤 공이 표준 공 최대 속도를 넘었습니다: %s" % ball.linear_velocity.length())
	adapter.physics_tick(0.01)
	_expect(_hit_results.size() == 1, "지속 접촉 중 타격 결과가 중복됐습니다.")
	runtime._on_sensor_body_exited(ball)
	ball.global_position = Vector2(-100.0, 0.0)
	ball.linear_velocity = Vector2(BALL_PROFILE.max_linear_speed_board_per_second * WORLD_SCALE, 0.0)
	adapter.physics_tick(0.2)
	_expect(_hit_results.size() == 2, "실제 분리 뒤 재접촉이 두 번째 타격을 만들지 않았습니다.")

	_expect_multiple_high_speed_angles(adapter, runtime, ball)
	_expect_track_completion_and_release(adapter, ball)
	_expect_shot_target_launch(adapter, ball)

	ball.queue_free()
	parent.queue_free()
	_finish()


func _expect_multiple_high_speed_angles(
	adapter: BumperPhysics2DAdapter,
	runtime: BumperRuntime2D,
	ball: Ball2D
) -> void:
	for angle_degrees in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		runtime._on_sensor_body_exited(ball)
		var start := Vector2(-100.0, 0.0).rotated(deg_to_rad(angle_degrees))
		var inward_direction := start.direction_to(Vector2.ZERO)
		var hits_before := _hit_results.size()
		ball.global_position = start
		ball.linear_velocity = (
			inward_direction
			* BALL_PROFILE.max_linear_speed_board_per_second
			* WORLD_SCALE
		)
		adapter.physics_tick(0.2)
		_expect(
			_hit_results.size() == hits_before + 1,
			"최대 속도 %s도 입사에서 타격을 정확히 한 번 감지하지 못했습니다." % angle_degrees
		)
		_expect(
			ball.global_position.distance_to(Vector2.ZERO) >= runtime.collision_radius_pixels,
			"최대 속도 %s도 입사에서 공 중심이 범퍼 중심을 관통했습니다." % angle_degrees
		)
		_expect(
			ball.linear_velocity.normalized().dot(-inward_direction) > 0.999,
			"최대 속도 %s도 입사에서 반동 방향이 바깥쪽이 아닙니다." % angle_degrees
		)
		_expect(
			ball.linear_velocity.length() <= BALL_PROFILE.max_linear_speed_board_per_second * WORLD_SCALE + 0.01,
			"최대 속도 %s도 입사 반동이 표준 공 속도 상한을 넘었습니다." % angle_degrees
		)


func _expect_track_completion_and_release(
	adapter: BumperPhysics2DAdapter,
	ball: Ball2D
) -> void:
	ball.global_position = Vector2(250.0, 250.0)
	ball.linear_velocity = Vector2.ZERO
	var result := BumperHitResult.new()
	result.effect_type = BumperHitResult.EFFECT_TRACK
	result.output_board_velocity = Vector2.RIGHT
	result.track_path_board_positions = PackedVector2Array([
		Vector2(0.6, 0.5),
		Vector2(0.7, 0.6),
	])
	result.track_speed_board_per_second = 1.2
	adapter._apply_hit_result(ball, result)
	_expect(ball.freeze, "경로 범퍼가 공의 일반 물리를 잠시 제어하지 않았습니다.")
	adapter.physics_tick(0.4)
	_expect(not ball.freeze, "경로 범퍼의 전체 경로를 완주한 뒤 일반 물리로 복귀하지 않았습니다.")
	_expect(
		ball.global_position.is_equal_approx(Vector2(0.7, 0.6) * WORLD_SCALE),
		"경로 범퍼가 마지막 경로 지점까지 이동하지 않았습니다: %s" % ball.global_position
	)
	var expected_exit_velocity := Vector2(0.1, 0.1).normalized() * 1.2 * WORLD_SCALE
	_expect(
		ball.linear_velocity.is_equal_approx(expected_exit_velocity),
		"경로 범퍼 완주 뒤 마지막 구간 방향으로 이탈하지 않았습니다: %s" % ball.linear_velocity
	)


func _expect_shot_target_launch(
	adapter: BumperPhysics2DAdapter,
	ball: Ball2D
) -> void:
	var result := BumperHitResult.new()
	result.effect_type = BumperHitResult.EFFECT_SHOT
	result.output_board_velocity = Vector2(0.6, -1.4)
	adapter._apply_hit_result(ball, result)
	_expect(not ball.freeze, "발사 범퍼가 공을 일반 물리에서 멈춘 채로 남겼습니다.")
	_expect(
		ball.linear_velocity.is_equal_approx(result.output_board_velocity * WORLD_SCALE),
		"발사 범퍼가 목표 방향·속도를 2D 공에 적용하지 않았습니다: %s" % ball.linear_velocity
	)


func _on_hit_applied(result: BumperHitResult) -> void:
	_hit_results.append(result)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BUMPER_PHYSICS_2D_SMOKE: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("BUMPER_PHYSICS_2D_SMOKE: %s" % failure)
	quit(1)
