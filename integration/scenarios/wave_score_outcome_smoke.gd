extends SceneTree

const DEFAULT_OBJECTIVE_PATH := "res://stages/objectives/default_score_objective.tres"

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_objective_validation()
	_test_continue_with_remaining_ball()
	_test_equal_and_exceeded_target()
	_test_last_ball_failure_and_success()
	_test_duplicate_and_finished_rejection()
	_finish()


func _test_objective_validation() -> void:
	var objective := ScoreObjectiveConfig.new()
	_expect(objective.target_score == 1000, "새 목표 설정의 기본값은 1,000점이어야 합니다.")
	_expect(objective.is_valid(), "새 목표 설정의 기본값이 유효해야 합니다.")
	objective.target_score = 0
	_expect(not objective.is_valid(), "0점 목표를 승인했습니다.")
	objective.target_score = -1
	_expect(not objective.is_valid(), "음수 목표를 승인했습니다.")
	var resolver := NormalWaveScoreOutcomeResolver.new()
	_expect(not resolver.configure(objective).is_empty(), "잘못된 목표로 판정기를 설정했습니다.")


func _test_continue_with_remaining_ball() -> void:
	var resolver := _create_default_resolver()
	var result := resolver.resolve_after_shot(&"shot_continue", 999, 1)
	_expect(result.accepted, "목표 미만이고 공이 남은 판정을 거부했습니다.")
	_expect(
		result.outcome == WaveScoreOutcomeResult.OUTCOME_CONTINUE,
		"목표 미만이고 공이 남으면 다음 공 선택을 계속해야 합니다."
	)
	_expect(not result.is_final(), "계속 결과를 최종 결과로 표시했습니다.")


func _test_equal_and_exceeded_target() -> void:
	var equal_resolver := _create_default_resolver()
	var equal_result := equal_resolver.resolve_after_shot(&"shot_equal", 1000, 2)
	_expect(equal_result.accepted, "목표와 같은 스코어 판정을 거부했습니다.")
	_expect(
		equal_result.outcome == WaveScoreOutcomeResult.OUTCOME_CLEARED,
		"목표와 같은 스코어는 클리어여야 합니다."
	)
	var exceeded_resolver := _create_default_resolver()
	var exceeded_result := exceeded_resolver.resolve_after_shot(&"shot_exceeded", 1200, 1)
	_expect(
		exceeded_result.outcome == WaveScoreOutcomeResult.OUTCOME_CLEARED,
		"목표를 초과한 스코어는 클리어여야 합니다."
	)


func _test_last_ball_failure_and_success() -> void:
	var failed_resolver := _create_default_resolver()
	var failed_result := failed_resolver.resolve_after_shot(&"shot_last_failed", 999, 0)
	_expect(failed_result.accepted, "마지막 공 실패 판정을 거부했습니다.")
	_expect(
		failed_result.outcome == WaveScoreOutcomeResult.OUTCOME_FAILED,
		"마지막 공 뒤 목표 미달은 실패여야 합니다."
	)
	var cleared_resolver := _create_default_resolver()
	var cleared_result := cleared_resolver.resolve_after_shot(&"shot_last_cleared", 1000, 0)
	_expect(cleared_result.accepted, "마지막 공 성공 판정을 거부했습니다.")
	_expect(
		cleared_result.outcome == WaveScoreOutcomeResult.OUTCOME_CLEARED,
		"마지막 공으로 목표를 채우면 실패보다 클리어가 우선해야 합니다."
	)


func _test_duplicate_and_finished_rejection() -> void:
	var resolver := _create_default_resolver()
	var first := resolver.resolve_after_shot(&"shot_first", 500, 1)
	_expect(first.accepted, "첫 낙하 판정을 거부했습니다.")
	var duplicate := resolver.resolve_after_shot(&"shot_first", 600, 1)
	_expect(not duplicate.accepted, "같은 발사 낙하 결과를 중복 판정했습니다.")
	var final := resolver.resolve_after_shot(&"shot_final", 1000, 0)
	_expect(final.accepted, "유효한 최종 판정을 거부했습니다.")
	_expect(resolver.is_finished(), "최종 판정 뒤 판정기가 종료 상태가 아닙니다.")
	var after_final := resolver.resolve_after_shot(&"shot_after_final", 1100, 0)
	_expect(not after_final.accepted, "종료된 웨이브를 다시 판정했습니다.")
	var empty_shot := _create_default_resolver().resolve_after_shot(&"", 0, 1)
	_expect(not empty_shot.accepted, "빈 발사 식별자를 승인했습니다.")
	var negative_score := _create_default_resolver().resolve_after_shot(&"shot_negative", -1, 1)
	_expect(not negative_score.accepted, "음수 현재 스코어를 승인했습니다.")
	var negative_remaining := _create_default_resolver().resolve_after_shot(&"shot_negative_ball", 0, -1)
	_expect(not negative_remaining.accepted, "음수 남은 공 수를 승인했습니다.")


func _create_default_resolver() -> NormalWaveScoreOutcomeResolver:
	var objective := load(DEFAULT_OBJECTIVE_PATH) as ScoreObjectiveConfig
	var resolver := NormalWaveScoreOutcomeResolver.new()
	var configure_error := resolver.configure(objective)
	_expect(configure_error.is_empty(), "기본 목표 판정기를 설정하지 못했습니다: %s" % configure_error)
	return resolver


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("WAVE_SCORE_OUTCOME_SMOKE: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("WAVE_SCORE_OUTCOME_SMOKE: %s" % failure)
	quit(1)
