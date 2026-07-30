extends SceneTree

const FLIPPER_SCENE := preload("res://pinball/flippers/flipper_2d.tscn")
const BALL_SCENE := preload("res://pinball/ball/ball_2d.tscn")
const BALL_PROFILE := preload("res://pinball/ball/standard_ball_physics_profile.tres")

var _failures := PackedStringArray()
var _parry_applied_count := 0
var _last_parry_action_id: StringName = &""
var _last_parry_anchor_id: StringName = &""
var _last_parry_shot_id: StringName = &""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var adapter := FlipperPhysics2DAdapter.new()
	var configure_error := adapter.configure(
		func(world_position: Vector2) -> Vector2: return world_position,
		func(_board_position: Vector2, board_velocity: Vector2) -> Vector2: return board_velocity,
		func(_world_position: Vector2, world_velocity: Vector2) -> Vector2: return world_velocity
	)
	_expect(configure_error.is_empty(), "2D 플리퍼 어댑터 좌표 변환을 설정하지 못했습니다: %s" % configure_error)
	adapter.parry_applied.connect(_on_parry_applied)

	var profile := FlipperMotionProfile.new()
	profile.activation_seconds = 0.1
	profile.hold_seconds = 0.05
	profile.return_seconds = 0.1
	profile.parry_window_seconds = 0.08
	var left := _make_flipper(&"flipper_left", Flipper2D.ROLE_LEFT, profile)
	var right := _make_flipper(&"flipper_right", Flipper2D.ROLE_RIGHT, profile)
	root.add_child(left)
	root.add_child(right)
	_expect(adapter.register_flipper(left.anchor_id, left).is_empty(), "왼쪽 플리퍼를 등록하지 못했습니다.")
	_expect(adapter.register_flipper(right.anchor_id, right).is_empty(), "오른쪽 플리퍼를 등록하지 못했습니다.")

	var command := FlipperActionCommand.create(
		&"pair_action_001",
		&"shot_001",
		&"down",
		PackedStringArray(["flipper_left", "flipper_right"])
	)
	_expect(adapter.activate(command).is_empty(), "좌우 쌍 작동 명령을 시작하지 못했습니다.")
	_expect(left.is_action_active() and right.is_action_active(), "좌우 쌍이 같은 호출에서 함께 시작되지 않았습니다.")
	var overlapping_command := FlipperActionCommand.create(
		&"pair_action_overlap",
		&"shot_001",
		&"down",
		PackedStringArray(["flipper_left", "flipper_right"])
	)
	_expect(not adapter.activate(overlapping_command).is_empty(), "작동 중 Space에 해당하는 중복 명령이 허용됐습니다.")
	adapter.physics_tick(0.05)
	await physics_frame
	_expect(
		left.rotation < 0.0 and right.rotation > 0.0,
		"좌우 플리퍼가 서로 거울 방향으로 움직이지 않았습니다: %.4f / %.4f" % [
			left.rotation,
			right.rotation,
		]
	)

	var ball := BALL_SCENE.instantiate() as Ball2D
	root.add_child(ball)
	var ball_error := ball.configure(
		BALL_PROFILE,
		8.0,
		func(_board_position: Vector2, board_velocity: Vector2) -> Vector2: return board_velocity,
		func(world_position: Vector2) -> Vector2: return world_position,
		func(_world_position: Vector2, world_velocity: Vector2) -> Vector2: return world_velocity
	)
	_expect(ball_error.is_empty(), "패링 시험용 공을 설정하지 못했습니다: %s" % ball_error)
	ball.set_meta(&"shot_id", &"shot_001")
	ball.gravity_scale = 0.0
	ball.global_position = Vector2(30.0, -5.0)
	right.global_position = Vector2(0.0, 200.0)
	right.collision_layer = 0
	ball.linear_velocity = Vector2(2.9, 0.0)
	await physics_frame
	await physics_frame
	adapter.physics_tick(0.01)
	var first_parry_velocity := ball.linear_velocity
	var sensor := left.get_node("ParrySensor") as Area2D
	var overlap_labels := PackedStringArray()
	for body in sensor.get_overlapping_bodies():
		overlap_labels.append(body.get_class())
	_expect(
		not first_parry_velocity.is_equal_approx(Vector2(2.9, 0.0)),
		"공 패링 시간 안의 실제 센서 접촉이 공 속도를 바꾸지 않았습니다: %s / ball=%s / reported=%s" % [overlap_labels, ball.global_position, left._contact_reported]
	)
	_expect(
		first_parry_velocity.length() <= BALL_PROFILE.max_linear_speed_board_per_second + 0.0001,
		"공 패링이 공 최대 속도를 넘었습니다: %.6f" % first_parry_velocity.length()
	)
	_expect(_parry_applied_count == 1, "실제 공 패링이 패링 적용 신호를 정확히 한 번 만들지 않았습니다.")
	_expect(
		_last_parry_action_id == &"pair_action_001"
		and _last_parry_anchor_id == &"flipper_left"
		and _last_parry_shot_id == &"shot_001",
		"패링 적용 신호의 작동·플리퍼·발사 식별자가 실제 접촉과 일치하지 않습니다."
	)
	adapter._on_parry_contact(&"pair_action_001", right.anchor_id, ball, Vector2.LEFT, 5.0, 5.0)
	_expect(ball.linear_velocity.is_equal_approx(first_parry_velocity), "좌우 쌍 한 번의 작동에 패링 힘이 중복 적용됐습니다.")
	_expect(_parry_applied_count == 1, "좌우 쌍 한 번의 작동에 패링 적용 신호가 중복 발생했습니다.")

	adapter.physics_tick(0.25)
	_expect(not left.is_action_active() and not right.is_action_active(), "좌우 플리퍼가 설정 시간 뒤 자동 복귀하지 않았습니다.")
	_expect(not adapter.is_action_active(&"pair_action_001"), "좌우 쌍 작동 기록이 두 플리퍼 복귀 뒤 종료되지 않았습니다.")
	_expect(not adapter.activate(command).is_empty(), "같은 플리퍼 작동 식별자의 재사용이 허용됐습니다.")

	var left_only := FlipperActionCommand.create(
		&"left_action_001",
		&"shot_001",
		&"left",
		PackedStringArray(["flipper_left"])
	)
	_expect(adapter.activate(left_only).is_empty(), "왼쪽만 작동 명령을 시작하지 못했습니다.")
	_expect(left.is_action_active() and not right.is_action_active(), "왼쪽만 대상이 오른쪽 플리퍼까지 작동했습니다.")
	ball.linear_velocity = Vector2.ZERO
	adapter.physics_tick(profile.parry_window_seconds + 0.01)
	_expect(ball.linear_velocity.is_zero_approx(), "공 패링 시간이 지난 접촉에 추가 패링 힘이 적용됐습니다.")
	adapter.physics_tick(0.25)
	var right_only := FlipperActionCommand.create(
		&"right_action_001",
		&"shot_001",
		&"right",
		PackedStringArray(["flipper_right"])
	)
	_expect(adapter.activate(right_only).is_empty(), "오른쪽만 작동 명령을 시작하지 못했습니다.")
	_expect(not left.is_action_active() and right.is_action_active(), "오른쪽만 대상이 왼쪽 플리퍼까지 작동했습니다.")
	adapter.physics_tick(0.25)

	var top_left := FLIPPER_SCENE.instantiate() as Flipper2D
	var top_error := top_left.configure(
		&"flipper_top_left",
		Flipper2D.ROLE_LEFT,
		profile,
		Vector2.RIGHT,
		Vector2.DOWN,
		80.0,
		18.0
	)
	root.add_child(top_left)
	_expect(top_error.is_empty(), "상단 플리퍼의 보드 중심 방향을 설정하지 못했습니다.")
	_expect(top_left.start_action(&"top_center_action").is_empty(), "상단 플리퍼 작동을 시작하지 못했습니다.")
	top_left.physics_tick(0.05)
	await physics_frame
	_expect(top_left.rotation > 0.0, "플리퍼 회전 방향이 좌우 역할 고정값 대신 실제 보드 중심을 따르지 않았습니다.")

	left.queue_free()
	right.queue_free()
	ball.queue_free()
	top_left.queue_free()
	_finish()


func _on_parry_applied(
	action_id: StringName,
	anchor_id: StringName,
	shot_id: StringName
) -> void:
	_parry_applied_count += 1
	_last_parry_action_id = action_id
	_last_parry_anchor_id = anchor_id
	_last_parry_shot_id = shot_id


func _make_flipper(
	anchor_id: StringName,
	role_id: StringName,
	profile: FlipperMotionProfile
) -> Flipper2D:
	var flipper := FLIPPER_SCENE.instantiate() as Flipper2D
	var center_direction := Vector2.UP if role_id == Flipper2D.ROLE_LEFT else Vector2.DOWN
	var error := flipper.configure(
		anchor_id,
		role_id,
		profile,
		Vector2.RIGHT,
		center_direction,
		80.0,
		18.0
	)
	_expect(error.is_empty(), "시험용 플리퍼를 설정하지 못했습니다: %s" % error)
	return flipper


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FLIPPER_PHYSICS_2D_SMOKE: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("FLIPPER_PHYSICS_2D_SMOKE: %s" % failure)
	quit(1)
