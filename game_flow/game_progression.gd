class_name GameProgression
extends RefCounted

var _config: ProgressionConfig
var _configuration_error := ""
var _run: RunProgress


func _init(config: ProgressionConfig = null) -> void:
	_config = config if config != null else ProgressionConfig.new()
	_configuration_error = _config.get_validation_error()
	_run = RunProgress.new(maxi(1, _config.stage_count), maxi(1, _config.normal_wave_count))


func request_action(action_id: StringName) -> ProgressionTransitionResult:
	var previous_phase := _run.get_phase()
	var accepted := false
	var rejection_reason := ""

	if not _configuration_error.is_empty():
		rejection_reason = _configuration_error
	elif not ProgressionActions.is_known(action_id):
		rejection_reason = "알 수 없는 진행 요청입니다: %s" % action_id
	else:
		match action_id:
			ProgressionActions.START_RUN:
				accepted = _run.start_run()
			ProgressionActions.START_STAGE:
				accepted = _run.start_current_stage()
			ProgressionActions.WAVE_CLEARED:
				accepted = _run.submit_wave_outcome(WaveProgress.OUTCOME_CLEARED)
			ProgressionActions.WAVE_FAILED:
				accepted = _run.submit_wave_outcome(WaveProgress.OUTCOME_FAILED)
			ProgressionActions.REWARD_COMPLETED:
				accepted = _run.complete_reward()
			ProgressionActions.CONTINUE_FROM_RESULT:
				accepted = _run.continue_from_result()
			_:
				pass

	if not accepted and rejection_reason.is_empty():
		rejection_reason = "현재 진행 단계 '%s'에서 요청 '%s'을 처리할 수 없습니다." % [
			previous_phase,
			action_id,
		]

	return ProgressionTransitionResult.new(
		accepted,
		action_id,
		previous_phase,
		_run.get_phase(),
		rejection_reason,
		_run.current_stage_number,
		_run.get_current_normal_wave_number(),
		_run.get_stage_outcome(),
		_run.get_completed_stage_numbers()
	)


func get_phase() -> StringName:
	return _run.get_phase()


func get_current_stage_number() -> int:
	return _run.current_stage_number


func get_current_normal_wave_number() -> int:
	return _run.get_current_normal_wave_number()


func get_completed_stage_numbers() -> Array[int]:
	return _run.get_completed_stage_numbers()
