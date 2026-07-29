class_name ScoreAwardResult
extends RefCounted

var applied := false
var ignored_reason := ""
var hit_id: StringName = &""
var base_score := 0
var combo_count := 0
var multiplier := 0.0
var score_added := 0
var total_score := 0
var target_reached_now := false


static func ignored(reason: String, requested_hit_id: StringName = &"") -> ScoreAwardResult:
	var result := ScoreAwardResult.new()
	result.hit_id = requested_hit_id
	result.ignored_reason = reason
	return result


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not applied:
		if ignored_reason.strip_edges().is_empty():
			errors.append("적용되지 않은 스코어 결과에는 무시 이유가 필요합니다.")
		return errors
	if hit_id == &"":
		errors.append("스코어 결과의 타격 식별자가 비어 있습니다.")
	if base_score <= 0:
		errors.append("적용된 스코어 결과의 기본 점수는 1 이상이어야 합니다.")
	if combo_count <= 0:
		errors.append("적용된 스코어 결과의 콤보 수는 1 이상이어야 합니다.")
	if not is_finite(multiplier) or multiplier < 1.0:
		errors.append("적용된 스코어 결과의 배수는 유한한 1 이상의 값이어야 합니다.")
	var expected_score_added := roundi(float(base_score) * multiplier)
	if score_added != expected_score_added:
		errors.append(
			"스코어 증가량이 기본 점수와 배수의 반올림 결과와 다릅니다: %d != %d"
			% [score_added, expected_score_added]
		)
	if score_added <= 0:
		errors.append("적용된 스코어 증가량은 1 이상이어야 합니다.")
	if total_score < score_added:
		errors.append("누적 스코어는 이번 증가량보다 작을 수 없습니다.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()
