class_name ShotController
extends RefCounted

signal phase_changed(previous_phase: StringName, current_phase: StringName)
signal shot_started(shot_id: StringName, slot_id: StringName, ball_id: StringName)
signal shot_finished(result: ShotResult)

var current_phase: StringName = ShotPhases.BALL_SELECTION
var selected_slot_id: StringName = &""
var selected_ball_id: StringName = &""
var active_command: LaunchCommand
var active_solution: LaunchSolution
var last_result: ShotResult

var _consumed_request_ids: Dictionary = {}


func select_ball(slot_id: StringName, ball_id: StringName) -> String:
	if current_phase != ShotPhases.BALL_SELECTION:
		return "공 선택 상태에서만 발사할 공을 선택할 수 있습니다."
	if slot_id == &"":
		return "선택할 공 슬롯 식별자는 비어 있을 수 없습니다."
	if ball_id == &"":
		return "선택할 공 식별자는 비어 있을 수 없습니다."
	selected_slot_id = slot_id
	selected_ball_id = ball_id
	return ""


func confirm_selection() -> String:
	if current_phase != ShotPhases.BALL_SELECTION:
		return "공 선택 상태에서만 선택을 확정할 수 있습니다."
	if selected_slot_id == &"" or selected_ball_id == &"":
		return "먼저 발사할 공을 선택해야 합니다."
	_set_phase(ShotPhases.AIMING)
	return ""


func start_shot(command: LaunchCommand, solution: LaunchSolution) -> String:
	if current_phase != ShotPhases.AIMING:
		return "공 조준 상태에서만 발사할 수 있습니다."
	if command == null or not command.is_valid():
		return "유효한 발사 명령이 없습니다."
	if solution == null or not solution.is_valid():
		return "유효한 발사 계산 결과가 없습니다."
	if _consumed_request_ids.has(command.request_id):
		return "이미 처리한 발사 요청입니다: %s" % command.request_id
	var identity_error := _get_identity_error(command, solution)
	if not identity_error.is_empty():
		return identity_error

	_consumed_request_ids[command.request_id] = true
	active_command = command
	active_solution = solution
	last_result = null
	_set_phase(ShotPhases.IN_PLAY)
	shot_started.emit(command.shot_id, command.slot_id, command.ball_id)
	return ""


func finish_shot(
	shot_id: StringName,
	end_reason: StringName,
	final_snapshot: BallPhysicsSnapshot
) -> ShotResult:
	if (
		current_phase == ShotPhases.RESOLVING
		and last_result != null
		and last_result.shot_id == shot_id
	):
		return last_result
	if current_phase != ShotPhases.IN_PLAY:
		return null
	if active_command == null or active_solution == null:
		return null
	if shot_id != active_command.shot_id:
		return null
	if not ShotEndReasons.is_supported(end_reason):
		return null
	if final_snapshot == null:
		return null
	if (
		final_snapshot.shot_id != active_command.shot_id
		or final_snapshot.slot_id != active_command.slot_id
		or final_snapshot.ball_id != active_command.ball_id
	):
		return null

	var result := ShotResult.new()
	result.request_id = active_command.request_id
	result.shot_id = active_command.shot_id
	result.slot_id = active_command.slot_id
	result.ball_id = active_command.ball_id
	result.end_reason = end_reason
	result.launch_solution = active_solution
	result.final_snapshot = final_snapshot.copy()
	if not result.is_valid():
		return null
	last_result = result
	_set_phase(ShotPhases.RESOLVING)
	shot_finished.emit(result)
	return result


func return_to_ball_selection() -> String:
	if current_phase != ShotPhases.RESOLVING or last_result == null:
		return "낙하 처리가 끝난 뒤에만 다음 공 선택으로 돌아갈 수 있습니다."
	selected_slot_id = &""
	selected_ball_id = &""
	active_command = null
	active_solution = null
	_set_phase(ShotPhases.BALL_SELECTION)
	return ""


func get_active_shot_id() -> StringName:
	if active_command == null:
		return &""
	return active_command.shot_id


func _get_identity_error(command: LaunchCommand, solution: LaunchSolution) -> String:
	if command.slot_id != selected_slot_id or command.ball_id != selected_ball_id:
		return "선택한 공 슬롯·공과 발사 명령이 일치하지 않습니다."
	if solution.request_id != command.request_id:
		return "발사 명령과 계산 결과의 요청 식별자가 다릅니다."
	if solution.shot_id != command.shot_id:
		return "발사 명령과 계산 결과의 발사 식별자가 다릅니다."
	if solution.slot_id != command.slot_id:
		return "발사 명령과 계산 결과의 공 슬롯이 다릅니다."
	if solution.ball_id != command.ball_id:
		return "발사 명령과 계산 결과의 공 식별자가 다릅니다."
	if solution.launch_anchor_id != command.launch_anchor_id:
		return "발사 명령과 계산 결과의 발사 지점이 다릅니다."
	return ""


func _set_phase(next_phase: StringName) -> void:
	if current_phase == next_phase:
		return
	var previous_phase := current_phase
	current_phase = next_phase
	phase_changed.emit(previous_phase, current_phase)
