class_name AppRoot
extends Node

signal progression_transitioned(result: ProgressionTransitionResult)
signal progression_rejected(result: ProgressionTransitionResult)

@export_node_path("ScreenNavigator") var navigator_path: NodePath
@export var progression_config: ProgressionConfig

var _initialized := false
var _progression: GameProgression

const PHASE_TO_SCREEN := {
	ProgressionPhases.RUN_INACTIVE: ScreenIds.MAIN_LOBBY,
	ProgressionPhases.STAGE_READY: ScreenIds.STAGE_SELECTION,
	ProgressionPhases.NORMAL_WAVE: ScreenIds.WAVE,
	ProgressionPhases.REWARD: ScreenIds.REWARD,
	ProgressionPhases.BOSS_WAVE: ScreenIds.BOSS,
	ProgressionPhases.STAGE_RESULT: ScreenIds.RESULTS,
	ProgressionPhases.RUN_RESULT: ScreenIds.RESULTS,
}


func _ready() -> void:
	if _initialized:
		return
	_progression = GameProgression.new(progression_config)

	var navigator := get_navigator()
	if navigator == null:
		push_error("앱 내비게이터를 찾을 수 없습니다: %s" % navigator_path)
		return

	navigator.progression_action_requested.connect(_on_progression_action_requested)
	_initialized = navigator.initialize()
	if not _initialized:
		push_error("앱 초기화에 실패했습니다.")


func get_navigator() -> ScreenNavigator:
	return get_node_or_null(navigator_path) as ScreenNavigator


func get_progression() -> GameProgression:
	return _progression


func request_progression_action(action_id: StringName) -> ProgressionTransitionResult:
	var result := _progression.request_action(action_id)
	if not result.accepted:
		progression_rejected.emit(result)
		return result

	var target_screen_id: StringName = PHASE_TO_SCREEN.get(result.current_phase, &"")
	var navigator := get_navigator()
	if target_screen_id == &"" or navigator == null or not navigator.request_navigation(target_screen_id):
		push_error("진행 단계 '%s'의 화면 전환에 실패했습니다." % result.current_phase)
	progression_transitioned.emit(result)
	return result


func _on_progression_action_requested(action_id: StringName) -> void:
	request_progression_action(action_id)
