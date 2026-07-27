class_name ProgressionTransitionResult
extends RefCounted

var accepted: bool
var action_id: StringName
var previous_phase: StringName
var current_phase: StringName
var rejection_reason: String
var stage_number: int
var normal_wave_number: int
var stage_outcome: StringName
var completed_stage_numbers: Array[int]


func _init(
	p_accepted: bool,
	p_action_id: StringName,
	p_previous_phase: StringName,
	p_current_phase: StringName,
	p_rejection_reason: String,
	p_stage_number: int,
	p_normal_wave_number: int,
	p_stage_outcome: StringName,
	p_completed_stage_numbers: Array[int]
) -> void:
	accepted = p_accepted
	action_id = p_action_id
	previous_phase = p_previous_phase
	current_phase = p_current_phase
	rejection_reason = p_rejection_reason
	stage_number = p_stage_number
	normal_wave_number = p_normal_wave_number
	stage_outcome = p_stage_outcome
	completed_stage_numbers = p_completed_stage_numbers.duplicate()
