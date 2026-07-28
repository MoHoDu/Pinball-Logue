class_name LaunchVelocityStrategy
extends RefCounted

const ANGLE_EPSILON := 0.0001


func calculate(
	command: LaunchCommand,
	config: LaunchConfig,
	physics_profile: BallPhysicsProfile,
	launch_forward_direction: Vector2
) -> LaunchSolution:
	var solution := LaunchSolution.new()
	if command == null:
		solution.validation_errors.append("발사 명령이 없습니다.")
		return solution
	_copy_command_identity(command, solution)
	solution.validation_errors.append_array(command.get_validation_errors())
	if config == null:
		solution.validation_errors.append("발사 설정이 없습니다.")
	else:
		solution.validation_errors.append_array(config.get_validation_errors())
	if physics_profile == null:
		solution.validation_errors.append("공 물리 설정이 없습니다.")
	else:
		solution.validation_errors.append_array(physics_profile.get_validation_errors())
	if not _is_finite_vector(launch_forward_direction):
		solution.validation_errors.append("발사 지점의 안쪽 방향은 유한한 값이어야 합니다.")
	elif launch_forward_direction.length_squared() <= 0.0:
		solution.validation_errors.append("발사 지점의 안쪽 방향은 길이가 0일 수 없습니다.")
	if not solution.validation_errors.is_empty():
		return solution

	var forward := launch_forward_direction.normalized()
	var requested_direction := command.board_direction.normalized()
	var requested_angle_degrees := rad_to_deg(forward.angle_to(requested_direction))
	var resolved_angle_degrees := config.clamp_aim_angle_degrees(requested_angle_degrees)
	solution.direction_was_clamped = (
		absf(resolved_angle_degrees - requested_angle_degrees) > ANGLE_EPSILON
	)
	solution.board_direction = forward.rotated(deg_to_rad(resolved_angle_degrees)).normalized()
	solution.normalized_strength = config.clamp_strength(command.normalized_strength)
	var requested_speed := config.get_speed_for_strength(solution.normalized_strength)
	solution.speed_board_per_second = calculate_speed_board_per_second(
		config, physics_profile, solution.normalized_strength
	)
	solution.speed_was_clamped = solution.speed_board_per_second < requested_speed
	solution.initial_board_velocity = (
		solution.board_direction * solution.speed_board_per_second
	)
	return solution


func calculate_speed_board_per_second(
	config: LaunchConfig,
	physics_profile: BallPhysicsProfile,
	normalized_strength: float
) -> float:
	if config == null or physics_profile == null:
		return 0.0
	return minf(
		config.get_speed_for_strength(normalized_strength),
		physics_profile.max_linear_speed_board_per_second
	)


func _copy_command_identity(command: LaunchCommand, solution: LaunchSolution) -> void:
	solution.request_id = command.request_id
	solution.shot_id = command.shot_id
	solution.slot_id = command.slot_id
	solution.ball_id = command.ball_id
	solution.launch_anchor_id = command.launch_anchor_id
	solution.normalized_strength = command.normalized_strength
	solution.board_direction = command.board_direction


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
