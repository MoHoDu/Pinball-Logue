class_name ScoreTracker
extends RefCounted

var current_score := 0
var combo_count := 0
var current_multiplier := 1.0
var target_reached := false

var _config: ScoreConfig
var _target_score := 0
var _processed_hit_ids: Dictionary = {}
var _has_last_hit := false
var _last_hit_seconds := 0.0


func configure(config: ScoreConfig, target_score: int) -> String:
	_config = null
	_target_score = 0
	_reset_state()
	if config == null:
		return "스코어 계산 설정이 없습니다."
	var config_errors := config.get_validation_errors()
	if not config_errors.is_empty():
		return config_errors[0]
	if target_score <= 0:
		return "목표 스코어는 1 이상이어야 합니다."
	_config = config
	_target_score = target_score
	return ""


func register_bumper_hit(
	hit_result: BumperHitResult,
	occurred_at_seconds: float
) -> ScoreAwardResult:
	if _config == null:
		return ScoreAwardResult.ignored("먼저 스코어 계산 설정과 목표 스코어를 연결해야 합니다.")
	if hit_result == null:
		return ScoreAwardResult.ignored("반영할 범퍼 타격 결과가 없습니다.")
	if not hit_result.is_applied:
		return ScoreAwardResult.ignored("적용되지 않은 범퍼 타격은 스코어에 반영하지 않습니다.", hit_result.hit_id)
	var hit_errors := hit_result.get_validation_errors()
	if not hit_errors.is_empty():
		return ScoreAwardResult.ignored(hit_errors[0], hit_result.hit_id)
	if hit_result.base_score_value <= 0:
		return ScoreAwardResult.ignored("기본 점수가 0인 범퍼 타격은 스코어에 반영하지 않습니다.", hit_result.hit_id)
	if _processed_hit_ids.has(hit_result.hit_id):
		return ScoreAwardResult.ignored("같은 범퍼 타격은 스코어에 두 번 반영할 수 없습니다.", hit_result.hit_id)
	if not is_finite(occurred_at_seconds) or occurred_at_seconds < 0.0:
		return ScoreAwardResult.ignored("범퍼 타격 시각은 유한한 0 이상의 초 값이어야 합니다.", hit_result.hit_id)
	if _has_last_hit and occurred_at_seconds < _last_hit_seconds:
		return ScoreAwardResult.ignored("범퍼 타격 시각은 이전 유효 타격보다 빠를 수 없습니다.", hit_result.hit_id)

	if (
		_has_last_hit
		and occurred_at_seconds - _last_hit_seconds <= _config.combo_window_seconds
	):
		combo_count += 1
	else:
		combo_count = 1
	current_multiplier = minf(
		_config.maximum_multiplier,
		1.0 + float(combo_count - 1) * _config.multiplier_step
	)
	var score_added := roundi(float(hit_result.base_score_value) * current_multiplier)
	var was_target_reached := target_reached
	current_score += score_added
	target_reached = current_score >= _target_score
	_processed_hit_ids[hit_result.hit_id] = true
	_has_last_hit = true
	_last_hit_seconds = occurred_at_seconds

	var result := ScoreAwardResult.new()
	result.applied = true
	result.hit_id = hit_result.hit_id
	result.base_score = hit_result.base_score_value
	result.combo_count = combo_count
	result.multiplier = current_multiplier
	result.score_added = score_added
	result.total_score = current_score
	result.target_reached_now = target_reached and not was_target_reached
	return result


func expire_combo_if_needed(occurred_at_seconds: float) -> bool:
	if (
		_config == null
		or not _has_last_hit
		or not is_finite(occurred_at_seconds)
		or occurred_at_seconds <= _last_hit_seconds + _config.combo_window_seconds
	):
		return false
	combo_count = 0
	current_multiplier = 1.0
	_has_last_hit = false
	return true


func _reset_state() -> void:
	current_score = 0
	combo_count = 0
	current_multiplier = 1.0
	target_reached = false
	_processed_hit_ids.clear()
	_has_last_hit = false
	_last_hit_seconds = 0.0
