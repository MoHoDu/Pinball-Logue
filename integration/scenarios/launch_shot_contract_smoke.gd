extends SceneTree

const BALL_PATH := "res://pinball/ball/standard_ball_definition.tres"
const LAUNCH_PATH := "res://pinball/launcher/default_launch_config.tres"

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ball := load(BALL_PATH) as BallDefinition
	var launch_config := load(LAUNCH_PATH) as LaunchConfig
	_expect(ball != null and ball.is_valid(), "표준 공 원형이 유효하지 않습니다.")
	_expect(launch_config != null and launch_config.is_valid(), "기본 발사 설정이 유효하지 않습니다.")
	if ball == null or launch_config == null:
		_finish()
		return

	_test_same_command_across_aim_modes(ball, launch_config)
	_test_single_shot_lifecycle(ball, launch_config)
	_test_invalid_boundaries(launch_config)
	_finish()


func _test_same_command_across_aim_modes(ball: BallDefinition, launch_config: LaunchConfig) -> void:
	var command := _create_command()
	var strategy := LaunchVelocityStrategy.new()
	var keyboard_config := launch_config.duplicate(true) as LaunchConfig
	keyboard_config.aim_mode = "direction_keys"
	var mouse_config := launch_config.duplicate(true) as LaunchConfig
	mouse_config.aim_mode = "mouse"
	var keyboard_solution := strategy.calculate(
		command,
		keyboard_config,
		ball.physics_profile,
		Vector2.UP
	)
	var mouse_solution := strategy.calculate(
		command,
		mouse_config,
		ball.physics_profile,
		Vector2.UP
	)
	_expect(keyboard_solution.is_valid(), "방향키 조준 발사 계산이 유효하지 않습니다.")
	_expect(mouse_solution.is_valid(), "마우스 조준 발사 계산이 유효하지 않습니다.")
	_expect(
		keyboard_solution.initial_board_velocity.is_equal_approx(
			mouse_solution.initial_board_velocity
		),
		"같은 방향·세기가 조준 방식에 따라 다른 초기 속도를 만들었습니다."
	)


func _test_single_shot_lifecycle(ball: BallDefinition, launch_config: LaunchConfig) -> void:
	var command := _create_command()
	var strategy := LaunchVelocityStrategy.new()
	var solution := strategy.calculate(command, launch_config, ball.physics_profile, Vector2.UP)
	var adapter := MockBallPhysicsAdapter.new()
	var controller := ShotController.new()
	_expect(controller.select_ball(command.slot_id, command.ball_id).is_empty(), "발사할 공을 선택하지 못했습니다.")
	_expect(controller.confirm_selection().is_empty(), "공 선택을 확정하지 못했습니다.")
	_expect(
		adapter.prepare_ball(command.shot_id, command.slot_id, ball, Vector2(0.25, 0.30)).is_empty(),
		"가짜 물리 어댑터에 공을 준비하지 못했습니다."
	)
	_expect(not adapter.prepare_ball(command.shot_id, command.slot_id, ball, Vector2.ZERO).is_empty(), "활성 공이 있는데 두 번째 공을 준비했습니다.")
	_expect(adapter.apply_launch(solution).is_empty(), "발사 계산 결과를 공에 적용하지 못했습니다.")
	_expect(not adapter.apply_launch(solution).is_empty(), "같은 공에 발사 힘을 두 번 적용했습니다.")
	_expect(controller.start_shot(command, solution).is_empty(), "한 발사를 시작하지 못했습니다.")
	_expect(not controller.start_shot(command, solution).is_empty(), "같은 발사 요청을 두 번 시작했습니다.")
	adapter.simulate_motion(Vector2(0.0, 0.55), Vector2(0.0, 1.0))
	var snapshot := adapter.get_snapshot(command.shot_id)
	var result := controller.finish_shot(command.shot_id, ShotEndReasons.DRAIN, snapshot)
	_expect(result != null and result.is_valid(), "드레인 결과를 한 번 확정하지 못했습니다.")
	_expect(controller.finish_shot(command.shot_id, ShotEndReasons.DRAIN, snapshot) == result, "중복 낙하가 다른 발사 결과를 만들었습니다.")
	_expect(controller.finish_shot(&"stale_shot", ShotEndReasons.DRAIN, snapshot) == null, "이전 발사 식별자의 지연 이벤트를 처리했습니다.")
	_expect(adapter.remove_ball(command.shot_id).is_empty(), "종료된 공을 제거하지 못했습니다.")
	_expect(not adapter.has_active_ball(), "제거 뒤 활성 공이 남았습니다.")
	_expect(controller.return_to_ball_selection().is_empty(), "낙하 뒤 공 선택 상태로 돌아가지 못했습니다.")
	_expect(controller.current_phase == ShotPhases.BALL_SELECTION, "다음 공 선택 상태가 아닙니다.")
	_expect(controller.finish_shot(command.shot_id, ShotEndReasons.DRAIN, snapshot) == null, "다음 공 선택 중 이전 발사 결과를 다시 반환했습니다.")


func _test_invalid_boundaries(launch_config: LaunchConfig) -> void:
	var invalid_angles := launch_config.duplicate(true) as LaunchConfig
	invalid_angles.minimum_aim_angle_degrees = 30.0
	invalid_angles.maximum_aim_angle_degrees = -30.0
	_expect(not invalid_angles.is_valid(), "최소 각도가 최대 각도보다 큰 발사 설정을 허용했습니다.")
	var invalid_speed := launch_config.duplicate(true) as LaunchConfig
	invalid_speed.minimum_speed_board_per_second = 3.0
	invalid_speed.maximum_speed_board_per_second = 1.0
	_expect(not invalid_speed.is_valid(), "최소 속도가 최대 속도보다 큰 발사 설정을 허용했습니다.")
	var invalid_command := _create_command()
	invalid_command.board_direction = Vector2(2.0, 0.0)
	_expect(not invalid_command.is_valid(), "정규화되지 않은 발사 방향을 허용했습니다.")
	var invalid_solution := LaunchSolution.new()
	invalid_solution.request_id = &"request_invalid"
	invalid_solution.shot_id = &"shot_invalid"
	invalid_solution.slot_id = &"ball_slot_1"
	invalid_solution.ball_id = &"standard_ball"
	invalid_solution.launch_anchor_id = &"launch_main"
	invalid_solution.board_direction = Vector2.ZERO
	invalid_solution.normalized_strength = 0.5
	invalid_solution.speed_board_per_second = -1.0
	invalid_solution.initial_board_velocity = Vector2(NAN, 0.0)
	_expect(not invalid_solution.is_valid(), "비정상 방향·속도의 수동 발사 계산 결과를 허용했습니다.")


func _create_command() -> LaunchCommand:
	var command := LaunchCommand.new()
	command.request_id = &"request_1"
	command.shot_id = &"shot_1"
	command.slot_id = &"ball_slot_1"
	command.ball_id = &"standard_ball"
	command.launch_anchor_id = &"launch_main"
	command.board_direction = Vector2.UP
	command.normalized_strength = 0.6
	return command


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("LAUNCH_SHOT_CONTRACT_SMOKE: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("LAUNCH_SHOT_CONTRACT_SMOKE: %s" % failure)
	quit(1)
