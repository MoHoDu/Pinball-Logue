class_name ProgressionActions
extends RefCounted

const START_RUN: StringName = &"start_run"
const START_STAGE: StringName = &"start_stage"
const WAVE_CLEARED: StringName = &"wave_cleared"
const WAVE_FAILED: StringName = &"wave_failed"
const REWARD_COMPLETED: StringName = &"reward_completed"
const CONTINUE_FROM_RESULT: StringName = &"continue_from_result"


static func all() -> Array[StringName]:
	return [
		START_RUN,
		START_STAGE,
		WAVE_CLEARED,
		WAVE_FAILED,
		REWARD_COMPLETED,
		CONTINUE_FROM_RESULT,
	]


static func is_known(action_id: StringName) -> bool:
	return action_id in all()
