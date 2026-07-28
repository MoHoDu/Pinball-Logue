class_name Ball2D
extends RigidBody2D

@export var fill_color := Color("f4ead5")
@export var outline_color := Color("5b4636")
@export_range(0.5, 8.0, 0.5) var outline_width := 2.0

var max_linear_speed_board_per_second := 0.0
var max_angular_speed_radians := 0.0

var _radius_pixels := 8.0
var _board_to_world_velocity := Callable()
var _world_to_board_position := Callable()
var _world_to_board_velocity := Callable()


func configure(
	profile: BallPhysicsProfile,
	radius_pixels: float,
	board_to_world_velocity: Callable,
	world_to_board_position: Callable,
	world_to_board_velocity: Callable
) -> String:
	if profile == null:
		return "공 물리 설정이 없습니다."
	var profile_errors := profile.get_validation_errors()
	if not profile_errors.is_empty():
		return profile_errors[0]
	if not is_finite(radius_pixels) or radius_pixels <= 0.0:
		return "2D 공 반지름은 유한한 양수여야 합니다."
	if not board_to_world_velocity.is_valid():
		return "보드 속도를 2D 속도로 바꾸는 변환이 없습니다."
	if not world_to_board_position.is_valid():
		return "2D 위치를 보드 위치로 바꾸는 변환이 없습니다."
	if not world_to_board_velocity.is_valid():
		return "2D 속도를 보드 속도로 바꾸는 변환이 없습니다."

	mass = profile.mass
	gravity_scale = profile.gravity_scale
	linear_damp = profile.linear_damping
	angular_damp = profile.angular_damping
	continuous_cd = (
		CCD_MODE_CAST_SHAPE
		if profile.continuous_collision_detection
		else CCD_MODE_DISABLED
	)
	can_sleep = profile.can_sleep
	max_linear_speed_board_per_second = profile.max_linear_speed_board_per_second
	max_angular_speed_radians = profile.max_angular_speed_radians

	var physics_material := PhysicsMaterial.new()
	physics_material.bounce = profile.bounce
	physics_material.friction = profile.friction
	physics_material_override = physics_material

	_radius_pixels = radius_pixels
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return "2D 공 장면에 원형 충돌 영역이 없습니다."
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = radius_pixels
	collision_shape.shape = circle_shape

	_board_to_world_velocity = board_to_world_velocity
	_world_to_board_position = world_to_board_position
	_world_to_board_velocity = world_to_board_velocity
	queue_redraw()
	return ""


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius_pixels, outline_color)
	draw_circle(
		Vector2.ZERO,
		maxf(_radius_pixels - outline_width, _radius_pixels * 0.2),
		fill_color
	)
	draw_circle(
		Vector2(-_radius_pixels * 0.28, -_radius_pixels * 0.28),
		maxf(_radius_pixels * 0.16, 1.0),
		Color(1.0, 1.0, 1.0, 0.72)
	)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if (
		max_linear_speed_board_per_second > 0.0
		and _world_to_board_position.is_valid()
		and _world_to_board_velocity.is_valid()
		and _board_to_world_velocity.is_valid()
	):
		var board_position_variant: Variant = _world_to_board_position.call(
			state.transform.origin
		)
		var board_velocity_variant: Variant = _world_to_board_velocity.call(
			state.transform.origin,
			state.linear_velocity
		)
		if board_position_variant is Vector2 and board_velocity_variant is Vector2:
			var board_position: Vector2 = board_position_variant
			var board_velocity: Vector2 = board_velocity_variant
			if _is_finite_vector(board_velocity):
				board_velocity = board_velocity.limit_length(
					max_linear_speed_board_per_second
				)
				var world_velocity_variant: Variant = _board_to_world_velocity.call(
					board_position,
					board_velocity
				)
				if world_velocity_variant is Vector2:
					var world_velocity: Vector2 = world_velocity_variant
					if _is_finite_vector(world_velocity):
						state.linear_velocity = world_velocity
	if max_angular_speed_radians >= 0.0 and is_finite(state.angular_velocity):
		state.angular_velocity = clampf(
			state.angular_velocity,
			-max_angular_speed_radians,
			max_angular_speed_radians
		)


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
