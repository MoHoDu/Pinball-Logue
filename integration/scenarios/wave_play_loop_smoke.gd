extends SceneTree

const WAVE_SCENE := preload("res://app/navigation/screens/wave_screen.tscn")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := WAVE_SCENE.instantiate() as WavePlayScreen
	screen.launch_config = screen.launch_config.duplicate(true) as LaunchConfig
	screen.launch_config.aim_mode = "mouse"
	root.add_child(screen)
	await process_frame
	var router := screen.get_node("WaveInputRouter") as WaveInputRouter
	var board := screen.get_node("PlayableBoard2D") as PlayableBoard2D
	_expect(
		screen.get_remaining_ball_count() == 3,
		"기본 웨이브에 공 세 개가 준비되지 않았습니다: %s / %s" % [
			board.get_validation_errors(),
			(screen.get_node("Overlay/Status") as Label).text,
		]
	)
	_expect(
		WavePlayScreen.DEFAULT_FLIPPER_DIRECTION_PRIORITY == [
			&"down", &"left", &"right", &"up",
		],
		"최초 플리퍼 선택 우선순위가 아래→왼쪽→오른쪽→위가 아닙니다."
	)
	_expect(
		screen.get_selected_flipper_direction() == &"down",
		"웨이브 최초 진입에서 기본 하단 플리퍼 조작 대상이 자동 선택되지 않았습니다."
	)
	_expect(
		not screen.get_selected_flipper_target().is_empty(),
		"웨이브 최초 진입에서 선택된 플리퍼 조작 대상이 없습니다."
	)
	var initial_flipper_label := screen.get_node("Overlay/RightPanel/Content/Flipper") as Label
	_expect(not "없음" in initial_flipper_label.text, "웨이브 최초 HUD에 선택 플리퍼 없음이 표시됐습니다.")

	for expected_remaining in [2, 1, 0]:
		router._unhandled_input(_key_event(KEY_SPACE))
		_expect(screen.get_shot_phase() == ShotPhases.AIMING, "Space로 공 선택을 확정하지 못했습니다.")
		_expect(screen.has_active_ball(), "조준 상태에 선택한 공이 준비되지 않았습니다.")
		var aim_guide := screen.get_node("PlayableBoard2D/AimGuide") as Line2D
		var strength_label := screen.get_node("Overlay/RightPanel/Content/Strength") as Label
		_expect(aim_guide.visible, "공 조준 상태에서 조준선이 표시되지 않았습니다.")
		_expect(aim_guide.points.size() == 2, "조준선 시작·끝 지점이 준비되지 않았습니다.")
		if expected_remaining == 2:
			screen._aim_strength = 0.0
			screen._refresh_hud()
			_expect(
				is_equal_approx(_get_board_line_length(aim_guide, board), 0.112),
				"최소 실제 속도가 조준선 길이에 반영되지 않았습니다."
			)
			_expect("40% · 최소" in strength_label.text, "최소 실제 속도 표시가 40%가 아닙니다.")
			screen._aim_strength = 0.5
			screen._refresh_hud()
			_expect(
				is_equal_approx(_get_board_line_length(aim_guide, board), 0.196),
				"중간 실제 속도가 조준선 길이에 반영되지 않았습니다."
			)
			_expect("70%" in strength_label.text, "중간 실제 속도 표시가 70%가 아닙니다.")
			screen._aim_strength = 1.0
			screen._refresh_hud()
			_expect(
				is_equal_approx(_get_board_line_length(aim_guide, board), 0.28),
				"최대 실제 속도가 조준선 최대 길이에 반영되지 않았습니다."
			)
			_expect("100% · 최대" in strength_label.text, "최대 실제 속도 표시가 100%가 아닙니다.")
			var original_maximum_speed := screen.launch_config.maximum_speed_board_per_second
			screen.launch_config.maximum_speed_board_per_second = 4.0
			screen._refresh_hud()
			_expect(
				is_equal_approx(_get_board_line_length(aim_guide, board), 0.21),
				"공 최대 속도 제한이 조준선 길이에 반영되지 않았습니다."
			)
			_expect("75% · 공 최대" in strength_label.text, "공 최대 속도 제한 표시가 75%가 아닙니다.")
			screen.launch_config.maximum_speed_board_per_second = original_maximum_speed
			screen._aim_strength = screen.launch_config.default_strength
			screen._refresh_hud()
		var aim_label := screen.get_node("Overlay/RightPanel/Content/Aim") as Label
		var controls_label := screen.get_node("Overlay/RightPanel/Content/Controls") as Label
		if expected_remaining == 2:
			screen.launch_config.aim_mode = "direction_keys"
			screen._refresh_hud()
			_expect("마우스" in aim_label.text, "조준 중 설정 변경이 현재 조준 방식 표시를 바꿨습니다.")
			_expect("마우스" in controls_label.text, "조준 중 설정 변경이 현재 조작 안내를 바꿨습니다.")
		elif expected_remaining == 1:
			_expect("방향키" in aim_label.text, "다음 공 조준에 변경한 방향키 방식이 적용되지 않았습니다.")
			var angle_before_hold: float = screen._aim_angle_degrees
			var strength_before_hold: float = screen._aim_strength
			router._unhandled_input(_key_event(KEY_RIGHT, true))
			router._unhandled_input(_key_event(KEY_RIGHT, true))
			router._unhandled_input(_key_event(KEY_UP, true))
			_expect(
				is_equal_approx(
					screen._aim_angle_degrees,
					angle_before_hold + screen.launch_config.keyboard_angle_step_degrees * 2.0
				),
				"오른쪽 방향키를 길게 눌렀을 때 조준 각도가 반복 조절되지 않았습니다."
			)
			_expect(
				is_equal_approx(
					screen._aim_strength,
					strength_before_hold + screen.launch_config.keyboard_strength_step
				),
				"위 방향키를 길게 눌렀을 때 발사 세기가 반복 조절되지 않았습니다."
			)
			router._unhandled_input(_key_event(KEY_SPACE, true))
			_expect(
				screen.get_shot_phase() == ShotPhases.AIMING,
				"Space 반복 입력이 방향키 조준 중 공을 발사했습니다."
			)
		router._unhandled_input(_key_event(KEY_SPACE))
		_expect(screen.get_shot_phase() == ShotPhases.IN_PLAY, "두 번째 Space로 공을 발사하지 못했습니다.")
		_expect(
			screen.get_selected_flipper_direction() == &"down"
			and not screen.get_selected_flipper_target().is_empty(),
			"공 발사 뒤 플리퍼 조작 대상 선택이 비었습니다."
		)
		if expected_remaining == 2:
			router._unhandled_input(_key_event(KEY_UP))
			var target := screen.get_selected_flipper_target()
			_expect(
				screen.get_selected_flipper_direction() == &"down",
				"배정되지 않은 위 방향키가 기존 하단 플리퍼 선택을 비우거나 바꿨습니다."
			)
			_expect(
				StringName(target.get("mode", &"")) == FlipperControlTargetConfig.MODE_PAIR,
				"자동 선택된 기본 좌우 플리퍼 쌍을 유지하지 못했습니다."
			)
			var runtime_flippers := board.get_node_or_null("RuntimeFlippers")
			_expect(runtime_flippers != null, "플레이 보드에 실제 2D 플리퍼가 조립되지 않았습니다.")
			if runtime_flippers != null:
				var left_flipper := _find_flipper(runtime_flippers, &"flipper_left")
				var right_flipper := _find_flipper(runtime_flippers, &"flipper_right")
				_expect(left_flipper != null and right_flipper != null, "기본 좌우 플리퍼 물리 노드를 찾지 못했습니다.")
				if left_flipper != null and right_flipper != null:
					router._unhandled_input(_key_event(KEY_SPACE))
					_expect(
						left_flipper.is_action_active() and right_flipper.is_action_active(),
						"Space 한 번에 좌우 플리퍼가 함께 작동하지 않았습니다."
					)
					for _frame in 20:
						await physics_frame
					_expect(
						not left_flipper.is_action_active() and not right_flipper.is_action_active(),
						"좌우 플리퍼가 설정 시간 뒤 자동 복귀하지 않았습니다."
					)
		var shot_id := screen.get_active_shot_id()
		board.ball_exit_detected.emit(shot_id, ShotEndReasons.DRAIN)
		board.ball_exit_detected.emit(shot_id, ShotEndReasons.DRAIN)
		await process_frame
		await process_frame
		_expect(
			screen.get_remaining_ball_count() == expected_remaining,
			"낙하 뒤 남은 공 수가 %d개가 아닙니다." % expected_remaining
		)
		_expect(not screen.has_active_ball(), "낙하 처리가 끝난 공이 물리 보드에 남았습니다.")
		_expect(screen.get_shot_phase() == ShotPhases.BALL_SELECTION, "중복 낙하 뒤 공 선택 상태로 돌아오지 못했습니다.")
		_expect(
			screen.get_selected_flipper_direction() == &"down"
			and not screen.get_selected_flipper_target().is_empty(),
			"공 낙하 뒤 플리퍼 조작 대상 선택이 비었습니다."
		)

	_expect(screen.is_wave_mockup_complete(), "마지막 공 낙하 뒤 발사 반복이 종료되지 않았습니다.")
	router._unhandled_input(_key_event(KEY_SPACE))
	_expect(not screen.has_active_ball(), "발사 종료 뒤 Space가 새 공을 만들었습니다.")
	screen.queue_free()
	_finish()


func _key_event(keycode: Key, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = echo
	return event


func _get_board_line_length(line: Line2D, board: PlayableBoard2D) -> float:
	if line.points.size() != 2:
		return 0.0
	return board.local_to_board(line.points[0]).distance_to(
		board.local_to_board(line.points[1])
	)


func _find_flipper(parent: Node, anchor_id: StringName) -> Flipper2D:
	for child in parent.get_children():
		if child is Flipper2D and child.anchor_id == anchor_id:
			return child
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("WAVE_PLAY_LOOP_SMOKE: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("WAVE_PLAY_LOOP_SMOKE: %s" % failure)
	quit(1)
