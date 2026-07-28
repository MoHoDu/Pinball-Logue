class_name StageProgress
extends RefCounted

const STATE_READY: StringName = &"ready"
const STATE_NORMAL_WAVE: StringName = &"normal_wave"
const STATE_REWARD: StringName = &"reward"
const STATE_BOSS_WAVE: StringName = &"boss_wave"
const STATE_CLEARED: StringName = &"cleared"
const STATE_FAILED: StringName = &"failed"

const OUTCOME_NONE: StringName = &"none"
const OUTCOME_CLEARED: StringName = &"cleared"
const OUTCOME_FAILED: StringName = &"failed"

var stage_number: int
var normal_wave_count: int
var state: StringName = STATE_READY
var current_normal_wave_number := 0
var current_wave: WaveProgress


func _init(p_stage_number: int, p_normal_wave_count: int = 3) -> void:
	stage_number = p_stage_number
	normal_wave_count = p_normal_wave_count


func begin() -> bool:
	if state != STATE_READY:
		return false
	current_normal_wave_number = 1
	return _begin_normal_wave()


func submit_wave_outcome(outcome: StringName) -> bool:
	if state != STATE_NORMAL_WAVE and state != STATE_BOSS_WAVE:
		return false
	if current_wave == null or not current_wave.submit_outcome(outcome):
		return false

	var was_normal_wave := state == STATE_NORMAL_WAVE
	if outcome == WaveProgress.OUTCOME_FAILED:
		state = STATE_FAILED
	elif was_normal_wave:
		state = STATE_REWARD
	else:
		state = STATE_CLEARED
	return true


func complete_reward() -> bool:
	if state != STATE_REWARD:
		return false

	if current_normal_wave_number < normal_wave_count:
		current_normal_wave_number += 1
		return _begin_normal_wave()
	return _begin_boss_wave()


func retry() -> bool:
	if state != STATE_FAILED:
		return false
	current_normal_wave_number = 1
	return _begin_normal_wave()


func get_phase() -> StringName:
	match state:
		STATE_NORMAL_WAVE:
			return ProgressionPhases.NORMAL_WAVE
		STATE_REWARD:
			return ProgressionPhases.REWARD
		STATE_BOSS_WAVE:
			return ProgressionPhases.BOSS_WAVE
		STATE_CLEARED, STATE_FAILED:
			return ProgressionPhases.STAGE_RESULT
	return ProgressionPhases.STAGE_READY


func get_outcome() -> StringName:
	if state == STATE_CLEARED:
		return OUTCOME_CLEARED
	if state == STATE_FAILED:
		return OUTCOME_FAILED
	return OUTCOME_NONE


func _begin_normal_wave() -> bool:
	current_wave = WaveProgress.new(WaveProgress.KIND_NORMAL, current_normal_wave_number)
	if not current_wave.begin():
		return false
	state = STATE_NORMAL_WAVE
	return true


func _begin_boss_wave() -> bool:
	current_wave = WaveProgress.new(WaveProgress.KIND_BOSS)
	if not current_wave.begin():
		return false
	state = STATE_BOSS_WAVE
	return true
