class_name MockBallPhysicsAdapter
extends BallPhysicsAdapter

var prepare_count := 0
var launch_count := 0
var remove_count := 0

var _definition: BallDefinition
var _snapshot: BallPhysicsSnapshot


func has_active_ball() -> bool:
	return _snapshot != null and _snapshot.is_active


func prepare_ball(
	shot_id: StringName,
	slot_id: StringName,
	definition: BallDefinition,
	board_position: Vector2
) -> String:
	if has_active_ball():
		return "이미 활성 공이 있어 새 공을 준비할 수 없습니다."
	if shot_id == &"":
		return "발사 식별자는 비어 있을 수 없습니다."
	if slot_id == &"":
		return "공 슬롯 식별자는 비어 있을 수 없습니다."
	if definition == null:
		return "준비할 공 원형이 없습니다."
	var definition_errors := definition.get_validation_errors()
	if not definition_errors.is_empty():
		return definition_errors[0]
	if not _is_finite_vector(board_position):
		return "공 생성 위치는 유한한 보드 평면 좌표여야 합니다."

	_definition = definition
	_snapshot = BallPhysicsSnapshot.new()
	_snapshot.shot_id = shot_id
	_snapshot.slot_id = slot_id
	_snapshot.ball_id = definition.ball_id
	_snapshot.is_active = true
	_snapshot.board_position = board_position
	prepare_count += 1
	return ""


func apply_launch(solution: LaunchSolution) -> String:
	if not has_active_ball():
		return "발사할 활성 공이 없습니다."
	if solution == null or not solution.is_valid():
		return "유효한 발사 계산 결과가 없습니다."
	if solution.shot_id != _snapshot.shot_id:
		return "현재 공과 발사 계산 결과의 발사 식별자가 다릅니다."
	if solution.slot_id != _snapshot.slot_id:
		return "현재 공과 발사 계산 결과의 공 슬롯이 다릅니다."
	if solution.ball_id != _snapshot.ball_id:
		return "현재 공과 발사 계산 결과의 공 식별자가 다릅니다."
	if _snapshot.is_launched:
		return "현재 공은 이미 발사되었습니다."

	_snapshot.is_launched = true
	_snapshot.board_velocity = solution.initial_board_velocity
	launch_count += 1
	return ""


func get_snapshot(shot_id: StringName) -> BallPhysicsSnapshot:
	if _snapshot == null or _snapshot.shot_id != shot_id:
		return null
	return _snapshot.copy()


func simulate_motion(board_position: Vector2, board_velocity: Vector2) -> String:
	if not has_active_ball():
		return "움직임을 적용할 활성 공이 없습니다."
	if not _is_finite_vector(board_position) or not _is_finite_vector(board_velocity):
		return "공의 위치와 속도는 유한한 값이어야 합니다."
	_snapshot.board_position = board_position
	_snapshot.board_velocity = board_velocity
	return ""


func simulate_end(end_reason: StringName) -> String:
	if not has_active_ball():
		return "종료할 활성 공이 없습니다."
	if not ShotEndReasons.is_supported(end_reason):
		return "지원하지 않는 발사 종료 이유입니다: %s" % end_reason
	ball_ended.emit(_snapshot.shot_id, end_reason, _snapshot.copy())
	return ""


func remove_ball(shot_id: StringName) -> String:
	if not has_active_ball():
		return "제거할 활성 공이 없습니다."
	if _snapshot.shot_id != shot_id:
		return "현재 공과 제거 요청의 발사 식별자가 다릅니다."
	_snapshot.is_active = false
	_definition = null
	remove_count += 1
	return ""


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
