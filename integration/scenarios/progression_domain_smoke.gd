extends SceneTree

const GAME_PROGRESSION := preload("res://game_flow/game_progression.gd")
const ACTIONS := preload("res://game_flow/progression_actions.gd")
const PHASES := preload("res://game_flow/progression_phases.gd")
const PROGRESSION_CONFIG := preload("res://game_flow/progression_config.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_invalid_and_duplicate_requests()
	_test_full_three_stage_run()
	_test_custom_wave_and_stage_counts()
	_test_failure_retry_preserves_completed_stages()
	_finish()


func _test_invalid_and_duplicate_requests() -> void:
	var progression := GAME_PROGRESSION.new()
	_expect_phase(progression, PHASES.RUN_INACTIVE, "새 진행 모델")

	_expect_rejected(
		progression.request_action(ACTIONS.START_STAGE),
		"런 시작 전 스테이지 시작"
	)
	_expect_rejected(
		progression.request_action(&"unknown_action"),
		"알 수 없는 요청"
	)
	_expect_phase(progression, PHASES.RUN_INACTIVE, "거부 뒤 진행 모델")

	_expect_accepted(progression.request_action(ACTIONS.START_RUN), "런 시작")
	_expect_rejected(progression.request_action(ACTIONS.START_RUN), "중복 런 시작")
	_expect_phase(progression, PHASES.STAGE_READY, "중복 런 시작 거부 뒤")


func _test_full_three_stage_run() -> void:
	var progression := GAME_PROGRESSION.new()
	_expect_accepted(progression.request_action(ACTIONS.START_RUN), "정상 런 시작")

	for stage_number in range(1, 4):
		_expect(progression.get_current_stage_number() == stage_number, "현재 스테이지 번호가 %d이어야 합니다." % stage_number)
		_expect_accepted(progression.request_action(ACTIONS.START_STAGE), "스테이지 %d 시작" % stage_number)

		for wave_number in range(1, 4):
			_expect_phase(progression, PHASES.NORMAL_WAVE, "스테이지 %d 일반 웨이브 %d" % [stage_number, wave_number])
			_expect(
				progression.get_current_normal_wave_number() == wave_number,
				"스테이지 %d의 현재 일반 웨이브는 %d이어야 합니다." % [stage_number, wave_number]
			)
			_expect_accepted(progression.request_action(ACTIONS.WAVE_CLEARED), "일반 웨이브 클리어")
			_expect_rejected(progression.request_action(ACTIONS.WAVE_CLEARED), "일반 웨이브 중복 클리어")
			_expect_phase(progression, PHASES.REWARD, "일반 웨이브 뒤 보상")
			_expect_accepted(progression.request_action(ACTIONS.REWARD_COMPLETED), "보상 완료")

		var expected_after_third_reward := PHASES.BOSS_WAVE
		_expect_phase(progression, expected_after_third_reward, "세 번째 보상 뒤 보스")
		_expect_rejected(progression.request_action(ACTIONS.REWARD_COMPLETED), "보스 전 보상 중복 완료")
		_expect_accepted(progression.request_action(ACTIONS.WAVE_CLEARED), "보스 웨이브 클리어")
		_expect_rejected(progression.request_action(ACTIONS.WAVE_CLEARED), "보스 웨이브 중복 클리어")

		var completed := progression.get_completed_stage_numbers()
		_expect(completed.size() == stage_number, "완료 스테이지 수가 %d이어야 합니다." % stage_number)
		_expect(completed[-1] == stage_number, "완료 목록 마지막 값이 스테이지 %d이어야 합니다." % stage_number)

		if stage_number < 3:
			_expect_phase(progression, PHASES.STAGE_RESULT, "스테이지 %d 결과" % stage_number)
			_expect_accepted(progression.request_action(ACTIONS.CONTINUE_FROM_RESULT), "다음 스테이지 준비")
			_expect_phase(progression, PHASES.STAGE_READY, "다음 스테이지 준비 상태")
		else:
			_expect_phase(progression, PHASES.RUN_RESULT, "스테이지 3 뒤 런 결과")

	_expect_accepted(progression.request_action(ACTIONS.CONTINUE_FROM_RESULT), "런 결과 확인")
	_expect_phase(progression, PHASES.RUN_INACTIVE, "런 결과 확인 뒤 대기")
	_expect(progression.get_completed_stage_numbers().is_empty(), "새 런 대기 상태에는 이전 완료 목록이 남지 않아야 합니다.")


func _test_failure_retry_preserves_completed_stages() -> void:
	var progression := GAME_PROGRESSION.new()
	_expect_accepted(progression.request_action(ACTIONS.START_RUN), "실패 경로 런 시작")
	_expect_accepted(progression.request_action(ACTIONS.START_STAGE), "실패 경로 스테이지 1 시작")
	_complete_current_stage(progression)
	_expect_accepted(progression.request_action(ACTIONS.CONTINUE_FROM_RESULT), "스테이지 2 준비")
	_expect_accepted(progression.request_action(ACTIONS.START_STAGE), "스테이지 2 시작")

	_expect_accepted(progression.request_action(ACTIONS.WAVE_FAILED), "스테이지 2 웨이브 실패")
	_expect_phase(progression, PHASES.STAGE_RESULT, "웨이브 실패 뒤 스테이지 결과")
	_expect(progression.get_completed_stage_numbers() == [1], "실패 시 완료한 스테이지 1이 보존돼야 합니다.")
	_expect_rejected(progression.request_action(ACTIONS.WAVE_FAILED), "실패 결과 중복 전달")

	_expect_accepted(progression.request_action(ACTIONS.CONTINUE_FROM_RESULT), "스테이지 2 리트라이")
	_expect_phase(progression, PHASES.NORMAL_WAVE, "리트라이 일반 웨이브")
	_expect(progression.get_current_stage_number() == 2, "리트라이는 같은 스테이지 2를 유지해야 합니다.")
	_expect(progression.get_current_normal_wave_number() == 1, "리트라이는 일반 웨이브 1부터 시작해야 합니다.")
	_expect(progression.get_completed_stage_numbers() == [1], "리트라이 뒤에도 스테이지 1 완료가 보존돼야 합니다.")


func _test_custom_wave_and_stage_counts() -> void:
	var config := PROGRESSION_CONFIG.new()
	config.stage_count = 1
	config.normal_wave_count = 2
	var progression := GAME_PROGRESSION.new(config)

	_expect_accepted(progression.request_action(ACTIONS.START_RUN), "커스텀 런 시작")
	_expect_accepted(progression.request_action(ACTIONS.START_STAGE), "커스텀 스테이지 시작")
	for wave_number in range(1, 3):
		_expect(progression.get_current_normal_wave_number() == wave_number, "커스텀 일반 웨이브 번호가 %d이어야 합니다." % wave_number)
		_expect_accepted(progression.request_action(ACTIONS.WAVE_CLEARED), "커스텀 일반 웨이브 클리어")
		_expect_accepted(progression.request_action(ACTIONS.REWARD_COMPLETED), "커스텀 보상 완료")
	_expect_phase(progression, PHASES.BOSS_WAVE, "커스텀 두 번째 보상 뒤 보스")
	_expect_accepted(progression.request_action(ACTIONS.WAVE_CLEARED), "커스텀 보스 클리어")
	_expect_phase(progression, PHASES.RUN_RESULT, "커스텀 단일 스테이지 런 결과")


func _complete_current_stage(progression) -> void:
	for wave_number in 3:
		_expect_accepted(progression.request_action(ACTIONS.WAVE_CLEARED), "완료 도우미 일반 웨이브 %d" % (wave_number + 1))
		_expect_accepted(progression.request_action(ACTIONS.REWARD_COMPLETED), "완료 도우미 보상 %d" % (wave_number + 1))
	_expect_accepted(progression.request_action(ACTIONS.WAVE_CLEARED), "완료 도우미 보스")


func _expect_phase(progression, expected_phase: StringName, context: String) -> void:
	_expect(
		progression.get_phase() == expected_phase,
		"%s 단계는 '%s'이어야 하지만 '%s'입니다." % [context, expected_phase, progression.get_phase()]
	)


func _expect_accepted(result, context: String) -> void:
	_expect(result.accepted, "%s 요청이 승인돼야 합니다: %s" % [context, result.rejection_reason])


func _expect_rejected(result, context: String) -> void:
	_expect(not result.accepted, "%s 요청이 거부돼야 합니다." % context)
	_expect(result.current_phase == result.previous_phase, "%s 거부는 진행 단계를 보존해야 합니다." % context)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PROGRESSION_DOMAIN_SMOKE: PASS")
		quit(0)
		return

	for failure in _failures:
		push_error("PROGRESSION_DOMAIN_SMOKE: %s" % failure)
	quit(1)
