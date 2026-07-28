class_name BallPhysics2DAdapter
extends BallPhysicsAdapter

const BALL_SCENE := preload("res://pinball/ball/ball_2d.tscn")

var _parent: Node
var _board_to_world_position := Callable()
var _world_to_board_position := Callable()
var _board_to_world_velocity := Callable()
var _world_to_board_velocity := Callable()
var _board_radius_to_world := Callable()

var _ball: Ball2D
var _pending_removal_ball: Ball2D
var _definition: BallDefinition
var _shot_id: StringName = &""
var _slot_id: StringName = &""
var _is_launched := false


func configure(
	parent: Node,
	board_to_world_position: Callable,
	world_to_board_position: Callable,
	board_to_world_velocity: Callable,
	world_to_board_velocity: Callable,
	board_radius_to_world: Callable
) -> String:
	if has_active_ball():
		return "활성 공이 있는 동안에는 2D 좌표 변환을 바꿀 수 없습니다."
	if parent == null:
		return "2D 공을 추가할 부모 노드가 없습니다."
	if not board_to_world_position.is_valid():
		return "보드 위치를 2D 위치로 바꾸는 변환이 없습니다."
	if not world_to_board_position.is_valid():
		return "2D 위치를 보드 위치로 바꾸는 변환이 없습니다."
	if not board_to_world_velocity.is_valid():
		return "보드 속도를 2D 속도로 바꾸는 변환이 없습니다."
	if not world_to_board_velocity.is_valid():
		return "2D 속도를 보드 속도로 바꾸는 변환이 없습니다."
	if not board_radius_to_world.is_valid():
		return "보드 반지름을 2D 반지름으로 바꾸는 변환이 없습니다."
	_parent = parent
	_board_to_world_position = board_to_world_position
	_world_to_board_position = world_to_board_position
	_board_to_world_velocity = board_to_world_velocity
	_world_to_board_velocity = world_to_board_velocity
	_board_radius_to_world = board_radius_to_world
	return ""


func has_active_ball() -> bool:
	return is_instance_valid(_ball)


func prepare_ball(
	shot_id: StringName,
	slot_id: StringName,
	definition: BallDefinition,
	board_position: Vector2
) -> String:
	if has_active_ball():
		return "이미 활성 공이 있어 새 공을 준비할 수 없습니다."
	if is_instance_valid(_pending_removal_ball):
		return "이전 공을 안전하게 제거하는 중이라 새 공을 준비할 수 없습니다."
	var configuration_error := _get_configuration_error()
	if not configuration_error.is_empty():
		return configuration_error
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

	var world_position_variant: Variant = _board_to_world_position.call(board_position)
	var radius_variant: Variant = _board_radius_to_world.call(
		board_position,
		definition.physics_profile.radius_board_ratio
	)
	if not world_position_variant is Vector2:
		return "보드 위치를 2D 위치로 변환하지 못했습니다."
	if not (radius_variant is float or radius_variant is int):
		return "보드 반지름을 2D 반지름으로 변환하지 못했습니다."
	var world_position: Vector2 = world_position_variant
	var radius_pixels := float(radius_variant)
	if not _is_finite_vector(world_position):
		return "변환된 2D 공 위치는 유한한 값이어야 합니다."
	if not is_finite(radius_pixels) or radius_pixels <= 0.0:
		return "변환된 2D 공 반지름은 유한한 양수여야 합니다."

	var ball := BALL_SCENE.instantiate() as Ball2D
	if ball == null:
		return "2D 공 장면을 만들 수 없습니다."
	var profile_error := ball.configure(
		definition.physics_profile,
		radius_pixels,
		_board_to_world_velocity,
		_world_to_board_position,
		_world_to_board_velocity
	)
	if not profile_error.is_empty():
		ball.free()
		return profile_error

	_parent.add_child(ball)
	ball.global_position = world_position
	ball.add_to_group(&"pinball_ball_2d")
	ball.set_meta(&"shot_id", shot_id)
	ball.set_meta(&"slot_id", slot_id)
	ball.set_meta(&"ball_id", definition.ball_id)
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.freeze = true
	_ball = ball
	_definition = definition
	_shot_id = shot_id
	_slot_id = slot_id
	_is_launched = false
	return ""


func apply_launch(solution: LaunchSolution) -> String:
	if not has_active_ball():
		return "발사할 활성 공이 없습니다."
	if solution == null or not solution.is_valid():
		return "유효한 발사 계산 결과가 없습니다."
	if solution.shot_id != _shot_id:
		return "현재 공과 발사 계산 결과의 발사 식별자가 다릅니다."
	if solution.slot_id != _slot_id:
		return "현재 공과 발사 계산 결과의 공 슬롯이 다릅니다."
	if _definition == null or solution.ball_id != _definition.ball_id:
		return "현재 공과 발사 계산 결과의 공 식별자가 다릅니다."
	if _is_launched:
		return "현재 공은 이미 발사되었습니다."

	var board_position_variant: Variant = _world_to_board_position.call(_ball.global_position)
	if not board_position_variant is Vector2:
		return "현재 2D 공 위치를 보드 위치로 변환하지 못했습니다."
	var world_velocity_variant: Variant = _board_to_world_velocity.call(
		board_position_variant,
		solution.initial_board_velocity
	)
	if not world_velocity_variant is Vector2:
		return "초기 보드 속도를 2D 속도로 변환하지 못했습니다."
	var world_velocity: Vector2 = world_velocity_variant
	if not _is_finite_vector(world_velocity):
		return "변환된 2D 초기 속도는 유한한 값이어야 합니다."

	_ball.freeze = false
	_ball.sleeping = false
	_ball.linear_velocity = world_velocity
	_is_launched = true
	return ""


func get_snapshot(shot_id: StringName) -> BallPhysicsSnapshot:
	if not has_active_ball() or shot_id != _shot_id or _definition == null:
		return null
	var board_position_variant: Variant = _world_to_board_position.call(_ball.global_position)
	var board_velocity_variant: Variant = _world_to_board_velocity.call(
		_ball.global_position,
		_ball.linear_velocity
	)
	if not board_position_variant is Vector2 or not board_velocity_variant is Vector2:
		return null
	var board_position: Vector2 = board_position_variant
	var board_velocity: Vector2 = board_velocity_variant
	if not _is_finite_vector(board_position) or not _is_finite_vector(board_velocity):
		return null

	var snapshot := BallPhysicsSnapshot.new()
	snapshot.shot_id = _shot_id
	snapshot.slot_id = _slot_id
	snapshot.ball_id = _definition.ball_id
	snapshot.is_active = true
	snapshot.is_launched = _is_launched
	snapshot.board_position = board_position
	snapshot.board_velocity = board_velocity
	snapshot.angular_speed_radians = _ball.angular_velocity
	return snapshot


func remove_ball(shot_id: StringName) -> String:
	if not has_active_ball():
		return "제거할 활성 공이 없습니다."
	if shot_id != _shot_id:
		return "현재 공과 제거 요청의 발사 식별자가 다릅니다."
	var ball_to_remove := _ball
	_clear_active_references()
	_pending_removal_ball = ball_to_remove
	ball_to_remove.queue_free()
	return ""


func get_active_ball_2d() -> Ball2D:
	if not has_active_ball():
		return null
	return _ball


func _get_configuration_error() -> String:
	if _parent == null or not is_instance_valid(_parent):
		return "먼저 2D 공 어댑터의 부모 노드와 좌표 변환을 설정해야 합니다."
	if (
		not _board_to_world_position.is_valid()
		or not _world_to_board_position.is_valid()
		or not _board_to_world_velocity.is_valid()
		or not _world_to_board_velocity.is_valid()
		or not _board_radius_to_world.is_valid()
	):
		return "2D 공 어댑터의 좌표 변환 설정이 올바르지 않습니다."
	return ""


func _clear_active_references() -> void:
	_ball = null
	_definition = null
	_shot_id = &""
	_slot_id = &""
	_is_launched = false


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
