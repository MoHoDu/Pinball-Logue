class_name RunProgress
extends RefCounted

const STATE_INACTIVE: StringName = &"inactive"
const STATE_STAGE_READY: StringName = &"stage_ready"
const STATE_STAGE_ACTIVE: StringName = &"stage_active"
const STATE_STAGE_RESULT: StringName = &"stage_result"
const STATE_COMPLETED: StringName = &"completed"

var state: StringName = STATE_INACTIVE
var stage_count: int
var normal_wave_count: int
var current_stage_number := 0
var current_stage: StageProgress
var completed_stage_numbers: Array[int] = []


func _init(p_stage_count: int = 3, p_normal_wave_count: int = 3) -> void:
	stage_count = p_stage_count
	normal_wave_count = p_normal_wave_count


func start_run() -> bool:
	if state != STATE_INACTIVE:
		return false

	current_stage_number = 1
	current_stage = null
	completed_stage_numbers.clear()
	state = STATE_STAGE_READY
	return true


func start_current_stage() -> bool:
	if state != STATE_STAGE_READY:
		return false

	current_stage = StageProgress.new(current_stage_number, normal_wave_count)
	if not current_stage.begin():
		current_stage = null
		return false
	state = STATE_STAGE_ACTIVE
	return true


func submit_wave_outcome(outcome: StringName) -> bool:
	if state != STATE_STAGE_ACTIVE or current_stage == null:
		return false
	if not current_stage.submit_wave_outcome(outcome):
		return false

	if current_stage.state == StageProgress.STATE_CLEARED:
		if current_stage_number not in completed_stage_numbers:
			completed_stage_numbers.append(current_stage_number)
		state = STATE_COMPLETED if current_stage_number == stage_count else STATE_STAGE_RESULT
	elif current_stage.state == StageProgress.STATE_FAILED:
		state = STATE_STAGE_RESULT
	return true


func complete_reward() -> bool:
	if state != STATE_STAGE_ACTIVE or current_stage == null:
		return false
	return current_stage.complete_reward()


func continue_from_result() -> bool:
	if state == STATE_COMPLETED:
		_reset_to_inactive()
		return true
	if state != STATE_STAGE_RESULT or current_stage == null:
		return false

	if current_stage.state == StageProgress.STATE_FAILED:
		if not current_stage.retry():
			return false
		state = STATE_STAGE_ACTIVE
		return true
	if current_stage.state != StageProgress.STATE_CLEARED:
		return false

	current_stage_number += 1
	current_stage = null
	state = STATE_STAGE_READY
	return true


func get_phase() -> StringName:
	match state:
		STATE_INACTIVE:
			return ProgressionPhases.RUN_INACTIVE
		STATE_STAGE_READY:
			return ProgressionPhases.STAGE_READY
		STATE_STAGE_ACTIVE:
			return current_stage.get_phase() if current_stage != null else ProgressionPhases.STAGE_READY
		STATE_STAGE_RESULT:
			return ProgressionPhases.STAGE_RESULT
		STATE_COMPLETED:
			return ProgressionPhases.RUN_RESULT
	return ProgressionPhases.RUN_INACTIVE


func get_current_normal_wave_number() -> int:
	if current_stage == null:
		return 0
	return current_stage.current_normal_wave_number


func get_stage_outcome() -> StringName:
	if current_stage == null:
		return StageProgress.OUTCOME_NONE
	return current_stage.get_outcome()


func get_completed_stage_numbers() -> Array[int]:
	return completed_stage_numbers.duplicate()


func _reset_to_inactive() -> void:
	state = STATE_INACTIVE
	current_stage_number = 0
	current_stage = null
	completed_stage_numbers.clear()
