class_name Ball
extends RigidBody2D


signal launched(direction: Vector2, speed: float)
signal reset_completed(reason: String)
signal toggle_balance_panel_requested


enum BallState {
	READY,
	AIMING,
	ACTIVE
}


# =========================================================
# 공 크기
# =========================================================

@export_category("공 크기")

@export_range(12.0, 40.0, 1.0)
var radius_px: float = 22.0


# =========================================================
# 공 속도
# =========================================================

@export_category("공 속도")

@export_range(50.0, 1000.0, 10.0)
var min_speed: float = 300.0

@export_range(100.0, 2000.0, 10.0)
var launch_speed: float = 850.0

@export_range(300.0, 3000.0, 10.0)
var max_speed: float = 1450.0

@export_range(0.0, 1.0, 0.01)
var low_speed_grace: float = 0.25


# =========================================================
# 충돌
# =========================================================

@export_category("충돌")

@export_range(0.0, 1.0, 0.01)
var bounce: float = 0.85

@export_range(0.0, 1.0, 0.01)
var friction: float = 0.02


# =========================================================
# 조준
# =========================================================

@export_category("조준")

@export_range(10.0, 89.0, 1.0)
var aim_max_angle_deg: float = 70.0

@export_range(20.0, 360.0, 5.0)
var aim_turn_speed_deg: float = 100.0

@export_range(100.0, 800.0, 10.0)
var aim_line_length: float = 360.0

@export_range(0.0, 0.8, 0.01)
var aim_curve_strength: float = 0.28

@export_range(8, 64, 1)
var aim_line_segments: int = 24


# =========================================================
# 위치
# =========================================================

@export_category("위치")

@export var launch_origin: Vector2 = Vector2(960.0, 820.0)

@export var board_center: Vector2 = Vector2(960.0, 540.0)


# =========================================================
# 노드 참조
# =========================================================

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_root: Node2D = $VisualRoot
@onready var aim_line: Line2D = $AimLine


# =========================================================
# 현재 상태
# =========================================================

var ball_state: BallState = BallState.READY

# 0도는 정면 위쪽이다.
# 음수는 왼쪽, 양수는 오른쪽이다.
var aim_angle_deg: float = 0.0
var aim_direction: Vector2 = Vector2.UP

var last_valid_direction: Vector2 = Vector2.UP
var low_speed_elapsed: float = 0.0

# 밸런스 패널 표시용 횟수
var max_clamp_count: int = 0
var min_recovery_count: int = 0


# =========================================================
# 초기화
# =========================================================

func _ready() -> void:
	if not _validate_required_nodes():
		set_process(false)
		set_physics_process(false)
		return

	_prepare_collision_shape()
	_prepare_physics_material()
	_prepare_rigid_body()
	_apply_balance_values()

	reset_ball("startup")


func _validate_required_nodes() -> bool:
	if collision_shape == null:
		push_error(
			"Ball 아래에 CollisionShape2D 노드가 없습니다."
		)
		return false

	if aim_line == null:
		push_error(
			"Ball 아래에 AimLine이라는 Line2D 노드가 없습니다."
		)
		return false

	if visual_root == null:
		push_error(
			"Ball 아래에 VisualRoot라는 Node2D 노드가 없습니다."
		)
		return false

	return true


func _prepare_collision_shape() -> void:
	var circle := collision_shape.shape as CircleShape2D

	if circle == null:
		circle = CircleShape2D.new()
	else:
		# 다른 인스턴스와 Shape 리소스를 공유하지 않도록 복제
		circle = circle.duplicate(true) as CircleShape2D

	collision_shape.shape = circle
	circle.radius = radius_px


func _prepare_physics_material() -> void:
	var material := physics_material_override

	if material == null:
		material = PhysicsMaterial.new()
	else:
		material = material.duplicate(true) as PhysicsMaterial

	physics_material_override = material

	material.bounce = bounce
	material.friction = friction
	material.absorbent = false
	material.rough = false


func _prepare_rigid_body() -> void:
	gravity_scale = 0.0

	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0

	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = 0.0

	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

	lock_rotation = true
	can_sleep = false


# =========================================================
# 입력
# =========================================================

func _physics_process(delta: float) -> void:
	_handle_global_input()

	if ball_state == BallState.ACTIVE:
		return

	_handle_aim_input(delta)
	_handle_launch_input()


func _handle_global_input() -> void:
	if Input.is_action_just_pressed("reset_ball"):
		reset_ball("keyboard")

	if Input.is_action_just_pressed(
		"toggle_balance_panel"
	):
		toggle_balance_panel_requested.emit()


func _handle_aim_input(delta: float) -> void:
	var input_axis := Input.get_axis(
		"aim_left",
		"aim_right"
	)

	if is_zero_approx(input_axis):
		return

	ball_state = BallState.AIMING

	aim_angle_deg += (
		input_axis
		* aim_turn_speed_deg
		* delta
	)

	aim_angle_deg = clampf(
		aim_angle_deg,
		-aim_max_angle_deg,
		aim_max_angle_deg
	)

	_update_aim_direction()
	_update_aim_line()


func _handle_launch_input() -> void:
	if not Input.is_action_just_pressed("launch"):
		return

	launch_ball()


# =========================================================
# 조준
# =========================================================

func _update_aim_direction() -> void:
	aim_direction = Vector2.UP.rotated(
		deg_to_rad(aim_angle_deg)
	)

	if aim_direction.length_squared() > 0.0001:
		last_valid_direction = aim_direction.normalized()


func _update_aim_line() -> void:
	if aim_line == null:
		return

	aim_line.clear_points()

	if ball_state == BallState.ACTIVE:
		aim_line.visible = false
		return

	aim_line.visible = true

	var segment_count := maxi(
		aim_line_segments,
		2
	)

	var normalized_angle := 0.0

	if aim_max_angle_deg > 0.0:
		normalized_angle = (
			aim_angle_deg
			/ aim_max_angle_deg
		)

	var end_point := (
		aim_direction.normalized()
		* aim_line_length
	)

	# 방향키를 왼쪽으로 누를수록 음수,
	# 오른쪽으로 누를수록 양수가 된다.
	var bend_offset_x := (
		normalized_angle
		* aim_line_length
		* aim_curve_strength
	)

	var control_point := Vector2(
		bend_offset_x,
		-aim_line_length * 0.48
	)

	for index in range(segment_count + 1):
		var t := (
			float(index)
			/ float(segment_count)
		)

		var point := _quadratic_bezier(
			Vector2.ZERO,
			control_point,
			end_point,
			t
		)

		aim_line.add_point(point)


func _quadratic_bezier(
	start_point: Vector2,
	control_point: Vector2,
	end_point: Vector2,
	t: float
) -> Vector2:
	var inverse_t := 1.0 - t

	return (
		inverse_t * inverse_t * start_point
		+ 2.0 * inverse_t * t * control_point
		+ t * t * end_point
	)


# =========================================================
# 발사
# =========================================================

func launch_ball() -> bool:
	if ball_state == BallState.ACTIVE:
		print("발사 무시: 이미 ACTIVE 상태입니다.")
		return false

	if aim_direction.length_squared() < 0.0001:
		push_warning("발사 실패: 조준 방향이 없습니다.")
		return false

	var direction := aim_direction.normalized()

	freeze = false
	sleeping = false

	# 발사 순간 한 번만 속도를 지정한다.
	linear_velocity = direction * launch_speed
	angular_velocity = 0.0

	last_valid_direction = direction
	low_speed_elapsed = 0.0

	ball_state = BallState.ACTIVE
	aim_line.visible = false

	print(
		"공 발사 | 방향: ",
		direction,
		" | 속도: ",
		launch_speed
	)

	launched.emit(
		direction,
		launch_speed
	)

	return true


# =========================================================
# 물리 속도 보정
# =========================================================

func _integrate_forces(
	physics_state: PhysicsDirectBodyState2D
) -> void:
	if ball_state != BallState.ACTIVE:
		return

	var velocity := physics_state.linear_velocity
	var speed := velocity.length()

	if speed > 0.001:
		last_valid_direction = velocity.normalized()

	# 최대 속도 제한
	if speed > max_speed:
		physics_state.linear_velocity = (
			velocity.normalized()
			* max_speed
		)

		max_clamp_count += 1
		low_speed_elapsed = 0.0
		return

	# 최소 속도 보정
	if speed < min_speed:
		low_speed_elapsed += physics_state.step

		if low_speed_elapsed >= low_speed_grace:
			var recovery_direction := (
				_get_recovery_direction(velocity)
			)

			physics_state.linear_velocity = (
				recovery_direction
				* min_speed
			)

			min_recovery_count += 1
			low_speed_elapsed = 0.0

		return

	low_speed_elapsed = 0.0


func _get_recovery_direction(
	current_velocity: Vector2
) -> Vector2:
	if current_velocity.length_squared() > 0.0001:
		return current_velocity.normalized()

	if last_valid_direction.length_squared() > 0.0001:
		return last_valid_direction.normalized()

	var away_from_center := (
		global_position
		- board_center
	)

	if away_from_center.length_squared() > 0.0001:
		return away_from_center.normalized()

	return Vector2.UP


# =========================================================
# 리셋
# =========================================================

func reset_ball(
	reason: String = "unknown"
) -> void:
	freeze = true
	sleeping = false

	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	global_position = launch_origin
	rotation = 0.0

	ball_state = BallState.READY

	aim_angle_deg = 0.0
	aim_direction = Vector2.UP
	last_valid_direction = Vector2.UP

	low_speed_elapsed = 0.0

	_update_aim_line()

	print("공 리셋 | 사유: ", reason)

	reset_completed.emit(reason)


# =========================================================
# 밸런스값 적용
# =========================================================

func apply_balance_values() -> void:
	_apply_balance_values()


func _apply_balance_values() -> void:
	_validate_balance_values()

	var circle := (
		collision_shape.shape
		as CircleShape2D
	)

	if circle != null:
		circle.radius = radius_px

	if visual_root.has_method("set_radius_px"):
		visual_root.call(
			"set_radius_px",
			radius_px
		)

	if physics_material_override != null:
		physics_material_override.bounce = bounce
		physics_material_override.friction = friction

	aim_angle_deg = clampf(
		aim_angle_deg,
		-aim_max_angle_deg,
		aim_max_angle_deg
	)

	_update_aim_direction()
	_update_aim_line()


func _validate_balance_values() -> void:
	radius_px = maxf(radius_px, 1.0)

	min_speed = maxf(min_speed, 1.0)
	max_speed = maxf(max_speed, min_speed)

	launch_speed = clampf(
		launch_speed,
		min_speed,
		max_speed
	)

	bounce = clampf(bounce, 0.0, 1.0)
	friction = clampf(friction, 0.0, 1.0)

	low_speed_grace = maxf(
		low_speed_grace,
		0.0
	)

	aim_max_angle_deg = clampf(
		aim_max_angle_deg,
		1.0,
		89.0
	)

	aim_line_length = maxf(
		aim_line_length,
		1.0
	)

	aim_line_segments = maxi(
		aim_line_segments,
		2
	)


# =========================================================
# UI·디버그용 조회
# =========================================================

func get_state_name() -> String:
	match ball_state:
		BallState.READY:
			return "READY"

		BallState.AIMING:
			return "AIMING"

		BallState.ACTIVE:
			return "ACTIVE"

	return "UNKNOWN"


func get_current_speed() -> float:
	return linear_velocity.length()


func get_speed_per_frame(
	render_fps: float = 60.0
) -> float:
	if render_fps <= 0.0:
		return 0.0

	return get_current_speed() / render_fps
