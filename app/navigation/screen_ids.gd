class_name ScreenIds
extends RefCounted

const MAIN_LOBBY: StringName = &"main_lobby"
const STAGE_SELECTION: StringName = &"stage_selection"
const WAVE: StringName = &"wave"
const REWARD: StringName = &"reward"
const BOSS: StringName = &"boss"
const RESULTS: StringName = &"results"


static func all() -> Array[StringName]:
	return [
		MAIN_LOBBY,
		STAGE_SELECTION,
		WAVE,
		REWARD,
		BOSS,
		RESULTS,
	]
