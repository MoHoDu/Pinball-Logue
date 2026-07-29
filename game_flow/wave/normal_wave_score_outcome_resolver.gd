class_name NormalWaveScoreOutcomeResolver
extends RefCounted

var _objective: ScoreObjectiveConfig
var _resolved_shot_ids: Dictionary = {}
var _final_outcome: StringName = &""


func configure(objective: ScoreObjectiveConfig) -> String:
	_objective = null
	_resolved_shot_ids.clear()
	_final_outcome = &""
	if objective == null:
		return "일반 웨이브의 목표 스코어 설정이 없습니다."
	var objective_errors := objective.get_validation_errors()
	if not objective_errors.is_empty():
		return objective_errors[0]
	_objective = objective
	return ""


func resolve_after_shot(
	shot_id: StringName,
	current_score: int,
	remaining_ball_count: int
) -> WaveScoreOutcomeResult:
	if _objective == null:
		return WaveScoreOutcomeResult.create_rejected(
			"먼저 일반 웨이브의 목표 스코어를 설정해야 합니다."
		)
	if shot_id == &"":
		return WaveScoreOutcomeResult.create_rejected(
			"낙하 결과와 연결할 발사 식별자가 비어 있습니다."
		)
	if current_score < 0:
		return WaveScoreOutcomeResult.create_rejected(
			"현재 스코어는 0점 이상이어야 합니다."
		)
	if remaining_ball_count < 0:
		return WaveScoreOutcomeResult.create_rejected(
			"남은 공 수는 0개 이상이어야 합니다."
		)
	if _resolved_shot_ids.has(shot_id):
		return WaveScoreOutcomeResult.create_rejected(
			"같은 발사 낙하 결과를 두 번 판정할 수 없습니다: %s" % shot_id
		)
	if _final_outcome != &"":
		return WaveScoreOutcomeResult.create_rejected(
			"이미 일반 웨이브 결과가 확정되었습니다: %s" % _final_outcome
		)

	_resolved_shot_ids[shot_id] = true
	var outcome := WaveScoreOutcomeResult.OUTCOME_CONTINUE
	if current_score >= _objective.target_score:
		outcome = WaveScoreOutcomeResult.OUTCOME_CLEARED
	elif remaining_ball_count == 0:
		outcome = WaveScoreOutcomeResult.OUTCOME_FAILED
	if outcome != WaveScoreOutcomeResult.OUTCOME_CONTINUE:
		_final_outcome = outcome
	return WaveScoreOutcomeResult.create_accepted(
		outcome,
		shot_id,
		current_score,
		_objective.target_score,
		remaining_ball_count
	)


func get_final_outcome() -> StringName:
	return _final_outcome


func is_finished() -> bool:
	return _final_outcome != &""
