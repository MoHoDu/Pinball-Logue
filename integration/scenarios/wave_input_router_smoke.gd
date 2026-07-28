extends SceneTree

var _failures := PackedStringArray()
var _router: WaveInputRouter
var _selection_confirm_count := 0
var _launch_count := 0
var _keyboard_aim_count := 0
var _mouse_aim_count := 0
var _flipper_action_count := 0
var _last_slot := 0
var _last_flipper_direction: StringName = &""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_router = WaveInputRouter.new()
	root.add_child(_router)
	_router.ball_slot_requested.connect(func(slot_number: int) -> void: _last_slot = slot_number)
	_router.ball_selection_confirm_requested.connect(_on_selection_confirm_requested)
	_router.launch_requested.connect(func() -> void: _launch_count += 1)
	_router.keyboard_aim_requested.connect(
		func(_angle_steps: int, _strength_steps: int) -> void: _keyboard_aim_count += 1
	)
	_router.mouse_aim_requested.connect(func(_position: Vector2) -> void: _mouse_aim_count += 1)
	_router.flipper_selection_requested.connect(
		func(direction_id: StringName) -> void: _last_flipper_direction = direction_id
	)
	_router.flipper_action_requested.connect(func() -> void: _flipper_action_count += 1)

	_test_selection_and_single_space_consumption()
	_test_aim_mode_snapshot_and_filtering()
	_test_ball_in_play_routing()
	_finish()


func _test_selection_and_single_space_consumption() -> void:
	_router.enter_ball_selection()
	_router._unhandled_input(_key_event(KEY_2))
	_expect(_last_slot == 2, "숫자 2 입력이 두 번째 공 슬롯을 선택하지 않았습니다.")

	_router._unhandled_input(_key_event(KEY_SPACE))
	_expect(_selection_confirm_count == 1, "공 선택 Space가 선택 확정을 한 번 요청해야 합니다.")
	_expect(_launch_count == 0, "공 선택 Space 하나가 조준 상태의 발사까지 연쇄 실행했습니다.")

	_router._unhandled_input(_key_event(KEY_SPACE, true))
	_expect(_launch_count == 0, "키 반복 echo가 발사 요청으로 처리됐습니다.")
	_router._unhandled_input(_key_event(KEY_SPACE))
	_expect(_launch_count == 1, "두 번째 Space가 조준 상태에서 발사를 요청하지 않았습니다.")


func _test_aim_mode_snapshot_and_filtering() -> void:
	_expect(
		_router.configure_aim_mode(WaveInputRouter.AIM_MODE_DIRECTION_KEYS),
		"유효한 방향키 조준 설정이 거부됐습니다."
	)
	_router.enter_aiming()
	_router.configure_aim_mode(WaveInputRouter.AIM_MODE_MOUSE)
	_router._unhandled_input(_key_event(KEY_LEFT))
	_expect(_keyboard_aim_count == 1, "조준 중 설정 변경이 현재 방향키 조준을 덮어썼습니다.")
	_router._unhandled_input(_key_event(KEY_LEFT, true))
	_router._unhandled_input(_key_event(KEY_LEFT, true))
	_expect(
		_keyboard_aim_count == 3,
		"방향키를 길게 눌렀을 때 반복 입력이 조준값을 계속 변경하지 않았습니다."
	)
	_router._unhandled_input(_key_release_event(KEY_LEFT))
	_expect(_keyboard_aim_count == 3, "방향키 해제가 조준값을 한 번 더 변경했습니다.")

	_router.enter_ball_selection()
	_router.enter_aiming()
	_router._unhandled_input(_key_event(KEY_LEFT))
	_router._unhandled_input(_key_event(KEY_LEFT, true))
	_expect(_keyboard_aim_count == 3, "마우스 조준에서 방향키가 조준값을 변경했습니다.")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(320.0, 240.0)
	_router._unhandled_input(motion)
	_expect(_mouse_aim_count == 1, "마우스 조준에서 포인터 위치를 전달하지 않았습니다.")
	_expect(
		not _router.configure_aim_mode(&"invalid_mode"),
		"알 수 없는 조준 방식이 승인됐습니다."
	)


func _test_ball_in_play_routing() -> void:
	_router.enter_ball_in_play()
	_router._unhandled_input(_key_event(KEY_UP))
	_expect(_last_flipper_direction == &"up", "공 진행 중 위 방향키가 위쪽 플리퍼를 선택하지 않았습니다.")
	_router._unhandled_input(_key_event(KEY_SPACE))
	_expect(_flipper_action_count == 1, "공 진행 중 Space가 플리퍼 작동 요청을 보내지 않았습니다.")


func _on_selection_confirm_requested() -> void:
	_selection_confirm_count += 1
	_router.enter_aiming()


func _key_event(keycode: Key, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = echo
	return event


func _key_release_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = false
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	_router.queue_free()
	if _failures.is_empty():
		print("WAVE_INPUT_ROUTER_SMOKE: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("WAVE_INPUT_ROUTER_SMOKE: %s" % failure)
	quit(1)
