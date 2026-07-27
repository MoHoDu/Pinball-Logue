class_name WaveProgress
extends RefCounted

const KIND_NORMAL: StringName = &"normal"
const KIND_BOSS: StringName = &"boss"

const STATUS_READY: StringName = &"ready"
const STATUS_PLAYING: StringName = &"playing"
const STATUS_CLEARED: StringName = &"cleared"
const STATUS_FAILED: StringName = &"failed"

const OUTCOME_CLEARED: StringName = &"cleared"
const OUTCOME_FAILED: StringName = &"failed"

var kind: StringName
var number: int
var status: StringName = STATUS_READY


func _init(p_kind: StringName, p_number: int = 0) -> void:
	kind = p_kind
	number = p_number


func begin() -> bool:
	if status != STATUS_READY:
		return false
	if kind != KIND_NORMAL and kind != KIND_BOSS:
		return false
	if kind == KIND_NORMAL and number <= 0:
		return false

	status = STATUS_PLAYING
	return true


func submit_outcome(outcome: StringName) -> bool:
	if status != STATUS_PLAYING:
		return false
	if outcome != OUTCOME_CLEARED and outcome != OUTCOME_FAILED:
		return false

	status = STATUS_CLEARED if outcome == OUTCOME_CLEARED else STATUS_FAILED
	return true


func is_finished() -> bool:
	return status == STATUS_CLEARED or status == STATUS_FAILED
