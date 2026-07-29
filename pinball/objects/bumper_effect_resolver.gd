class_name BumperEffectResolver
extends RefCounted


static func resolve(
	definition: BumperDefinition,
	request: BumperHitRequest,
	result: BumperHitResult
) -> String:
	if definition == null or request == null or result == null:
		return "범퍼 반응을 계산할 원형·타격 요청·결과가 모두 필요합니다."
	match definition.get_bumper_type_id():
		BumperDefinition.BUMPER_TYPE_NORMAL:
			result.effect_type = BumperHitResult.EFFECT_NORMAL_REFLECT
			result.output_board_velocity = _limit_speed(
				request.reflected_board_velocity,
				request.ball_max_speed_board_per_second
			)
		BumperDefinition.BUMPER_TYPE_BOUNCE:
			result.effect_type = BumperHitResult.EFFECT_BOUNCE
			result.output_board_velocity = _limit_speed(
				request.reflected_board_velocity * definition.bounce_speed_multiplier,
				request.ball_max_speed_board_per_second
			)
		BumperDefinition.BUMPER_TYPE_TRACK:
			if request.track_path_board_positions.is_empty():
				return "경로 범퍼에는 하나 이상의 경로 지점이 필요합니다: %s" % request.point_id
			result.effect_type = BumperHitResult.EFFECT_TRACK
			result.track_path_board_positions = request.track_path_board_positions.duplicate()
			result.track_speed_board_per_second = minf(
				definition.track_speed_board_per_second,
				request.ball_max_speed_board_per_second
			)
			var exit_direction := request.contact_board_position.direction_to(
				request.track_path_board_positions[0]
			)
			if request.track_path_board_positions.size() >= 2:
				exit_direction = request.track_path_board_positions[-2].direction_to(
					request.track_path_board_positions[-1]
				)
			if exit_direction.is_zero_approx():
				exit_direction = request.contact_board_normal.normalized()
			result.output_board_velocity = (
				exit_direction * result.track_speed_board_per_second
			)
		BumperDefinition.BUMPER_TYPE_SHOT:
			if not _is_finite_vector(request.shot_target_board_position):
				return "발사 범퍼에는 유효한 목표 지점이 필요합니다: %s" % request.point_id
			var target_direction := request.contact_board_position.direction_to(
				request.shot_target_board_position
			)
			if target_direction.is_zero_approx():
				return "발사 범퍼의 목표 지점은 접촉 위치와 달라야 합니다: %s" % request.point_id
			result.effect_type = BumperHitResult.EFFECT_SHOT
			result.shot_target_board_position = request.shot_target_board_position
			result.shot_speed_board_per_second = minf(
				definition.shot_speed_board_per_second,
				request.ball_max_speed_board_per_second
			)
			result.shot_direction_error_degrees = _get_deterministic_direction_error(
				request.hit_id,
				definition.shot_direction_error_degrees
			)
			target_direction = target_direction.rotated(
				deg_to_rad(result.shot_direction_error_degrees)
			)
			result.output_board_velocity = (
				target_direction * result.shot_speed_board_per_second
			)
		_:
			return "지원하지 않는 범퍼 종류입니다: %s" % definition.bumper_type
	return ""


static func _limit_speed(velocity: Vector2, maximum_speed: float) -> Vector2:
	return velocity.limit_length(maximum_speed)


static func _get_deterministic_direction_error(
	hit_id: StringName,
	maximum_error_degrees: float
) -> float:
	if maximum_error_degrees <= 0.0:
		return 0.0
	# 같은 타격 ID는 실행 차원과 프레임률에 관계없이 같은 -1~1 표본을 사용한다.
	var sample_index := posmod(hash(String(hit_id)), 20001)
	var normalized_sample := float(sample_index) / 10000.0 - 1.0
	return normalized_sample * maximum_error_degrees


static func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
