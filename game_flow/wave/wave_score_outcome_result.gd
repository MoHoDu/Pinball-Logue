class_name WaveScoreOutcomeResult
extends RefCounted

const OUTCOME_CONTINUE: StringName = &"continue"
const OUTCOME_CLEARED: StringName = &"cleared"
const OUTCOME_FAILED: StringName = &"failed"

var accepted := false
var rejection_reason := ""
var outcome: StringName = &""
var shot_id: StringName = &""
var current_score := 0
var target_score := 0
var remaining_ball_count := 0


static func create_accepted(
	requested_outcome: StringName,
	resolved_shot_id: StringName,
	resolved_current_score: int,
	resolved_target_score: int,
	resolved_remaining_ball_count: int
) -> WaveScoreOutcomeResult:
	var result := WaveScoreOutcomeResult.new()
	result.accepted = true
	result.outcome = requested_outcome
	result.shot_id = resolved_shot_id
	result.current_score = resolved_current_score
	result.target_score = resolved_target_score
	result.remaining_ball_count = resolved_remaining_ball_count
	return result


static func create_rejected(reason: String) -> WaveScoreOutcomeResult:
	var result := WaveScoreOutcomeResult.new()
	result.rejection_reason = reason
	return result


func is_final() -> bool:
	return outcome == OUTCOME_CLEARED or outcome == OUTCOME_FAILED
