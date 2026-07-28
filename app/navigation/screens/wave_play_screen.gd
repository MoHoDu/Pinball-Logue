class_name WavePlayScreen
extends Node2D

signal progression_requested(action_id: StringName)

@export var ball_loadout: WaveBallLoadoutConfig
@export var launch_config: LaunchConfig
@export_node_path("PlayableBoard2D") var playable_board_path := NodePath("PlayableBoard2D")
@export_node_path("WaveInputRouter") var input_router_path := NodePath("WaveInputRouter")
@export_node_path("Label") var phase_label_path := NodePath("Overlay/LeftPanel/Content/Phase")
@export_node_path("Label") var balls_label_path := NodePath("Overlay/LeftPanel/Content/Balls")
@export_node_path("Label") var aim_label_path := NodePath("Overlay/RightPanel/Content/Aim")
@export_node_path("Label") var strength_label_path := NodePath("Overlay/RightPanel/Content/Strength")
@export_node_path("Label") var flipper_label_path := NodePath("Overlay/RightPanel/Content/Flipper")
@export_node_path("Label") var controls_label_path := NodePath("Overlay/RightPanel/Content/Controls")
@export_node_path("Label") var status_label_path := NodePath("Overlay/Status")
@export_node_path("Line2D") var aim_guide_path := NodePath("PlayableBoard2D/AimGuide")

var _board: PlayableBoard2D
var _input_router: WaveInputRouter
var _phase_label: Label
var _balls_label: Label
var _aim_label: Label
var _strength_label: Label
var _flipper_label: Label
var _controls_label: Label
var _status_label: Label
var _aim_guide: Line2D

var _inventory := WaveBallInventory.new()
var _shot_controller := ShotController.new()
var _physics_adapter := BallPhysics2DAdapter.new()
var _launch_strategy := LaunchVelocityStrategy.new()
var _aim_angle_degrees := 0.0
var _aim_strength := 0.0
var _shot_sequence := 0
var _request_sequence := 0
var _current_shot_id: StringName = &""
var _selected_flipper_direction: StringName = &""
var _wave_complete := false


func _ready() -> void:
	_resolve_nodes()
	var setup_error := _setup_play_screen()
	if not setup_error.is_empty():
		_show_status("플레이 준비 실패: %s" % setup_error)
		set_process_unhandled_input(false)
		return
	_connect_inputs()
	_input_router.enter_ball_selection()
	_select_current_inventory_ball()
	_show_status("발사할 공을 고른 뒤 Space로 선택을 확정하세요.")
	_refresh_hud()


func _resolve_nodes() -> void:
	_board = get_node_or_null(playable_board_path) as PlayableBoard2D
	_input_router = get_node_or_null(input_router_path) as WaveInputRouter
	_phase_label = get_node_or_null(phase_label_path) as Label
	_balls_label = get_node_or_null(balls_label_path) as Label
	_aim_label = get_node_or_null(aim_label_path) as Label
	_strength_label = get_node_or_null(strength_label_path) as Label
	_flipper_label = get_node_or_null(flipper_label_path) as Label
	_controls_label = get_node_or_null(controls_label_path) as Label
	_status_label = get_node_or_null(status_label_path) as Label
	_aim_guide = get_node_or_null(aim_guide_path) as Line2D


func _setup_play_screen() -> String:
	if _board == null or _input_router == null:
		return "플레이 보드 또는 입력 라우터가 연결되지 않았습니다."
	if ball_loadout == null or launch_config == null:
		return "웨이브 공 목록 또는 발사 설정이 연결되지 않았습니다."
	var board_errors := _board.get_validation_errors()
	if not board_errors.is_empty():
		return board_errors[0]
	var loadout_error := _inventory.initialize(ball_loadout)
	if not loadout_error.is_empty():
		return loadout_error
	var launch_errors := launch_config.get_validation_errors()
	if not launch_errors.is_empty():
		return launch_errors[0]
	if not _input_router.configure_aim_mode(launch_config.get_aim_mode_id()):
		return "지원하지 않는 조준 방식입니다."
	return _physics_adapter.configure(
		_board,
		Callable(self, "_board_to_world_position"),
		Callable(self, "_world_to_board_position"),
		Callable(self, "_board_to_world_velocity"),
		Callable(self, "_world_to_board_velocity"),
		Callable(self, "_board_radius_to_local")
	)


func _connect_inputs() -> void:
	_input_router.ball_slot_requested.connect(_on_ball_slot_requested)
	_input_router.ball_cycle_requested.connect(_on_ball_cycle_requested)
	_input_router.ball_selection_confirm_requested.connect(_on_ball_selection_confirm_requested)
	_input_router.keyboard_aim_requested.connect(_on_keyboard_aim_requested)
	_input_router.mouse_aim_requested.connect(_on_mouse_aim_requested)
	_input_router.launch_requested.connect(_on_launch_requested)
	_input_router.flipper_selection_requested.connect(_on_flipper_selection_requested)
	_input_router.flipper_action_requested.connect(_on_flipper_action_requested)
	_board.ball_exit_detected.connect(_on_ball_exit_detected)


func _on_ball_slot_requested(slot_number: int) -> void:
	var error := _inventory.select_number(slot_number)
	if not error.is_empty():
		_show_status(error)
		return
	_select_current_inventory_ball()
	_show_status("%d번 공을 선택했습니다. Space로 확정하세요." % slot_number)
	_refresh_hud()


func _on_ball_cycle_requested(direction: int) -> void:
	var error := _inventory.cycle_selection(direction)
	if not error.is_empty():
		_show_status(error)
		return
	_select_current_inventory_ball()
	_show_status("남은 공 사이에서 선택을 옮겼습니다.")
	_refresh_hud()


func _select_current_inventory_ball() -> void:
	var slot := _inventory.get_selected_slot()
	if slot == null:
		return
	var error := _shot_controller.select_ball(slot.slot_id, slot.get_ball_id())
	if not error.is_empty():
		_show_status(error)


func _on_ball_selection_confirm_requested() -> void:
	var slot := _inventory.get_selected_slot()
	if slot == null:
		_show_status("먼저 남아 있는 공을 선택해야 합니다.")
		return
	_select_current_inventory_ball()
	_shot_sequence += 1
	_current_shot_id = StringName("shot_%03d" % _shot_sequence)
	var prepare_error := _physics_adapter.prepare_ball(
		_current_shot_id,
		slot.slot_id,
		slot.ball_definition,
		_board.get_launch_board_position()
	)
	if not prepare_error.is_empty():
		_show_status(prepare_error)
		return
	var confirm_error := _shot_controller.confirm_selection()
	if not confirm_error.is_empty():
		_physics_adapter.remove_ball(_current_shot_id)
		_show_status(confirm_error)
		return
	_input_router.configure_aim_mode(launch_config.get_aim_mode_id())
	_input_router.enter_aiming()
	_aim_angle_degrees = launch_config.default_aim_angle_degrees
	_aim_strength = launch_config.default_strength
	_show_status("공을 조준한 뒤 Space로 발사하세요.")
	_refresh_hud()


func _on_keyboard_aim_requested(angle_steps: int, strength_steps: int) -> void:
	_aim_angle_degrees = launch_config.clamp_aim_angle_degrees(
		_aim_angle_degrees + float(angle_steps) * launch_config.keyboard_angle_step_degrees
	)
	_aim_strength = launch_config.clamp_strength(
		_aim_strength + float(strength_steps) * launch_config.keyboard_strength_step
	)
	_refresh_hud()


func _on_mouse_aim_requested(viewport_position: Vector2) -> void:
	var canvas_inverse := _board.get_global_transform_with_canvas().affine_inverse()
	var pointer_local := canvas_inverse * viewport_position
	var pointer_board := _board.local_to_board(pointer_local)
	var launch_board := _board.get_launch_board_position()
	if not _is_finite_vector(pointer_board) or pointer_board.distance_squared_to(launch_board) <= 0.000001:
		return
	var requested_direction := launch_board.direction_to(pointer_board)
	var forward := _board.get_launch_forward_direction()
	_aim_angle_degrees = launch_config.clamp_aim_angle_degrees(
		rad_to_deg(forward.angle_to(requested_direction))
	)
	_aim_strength = launch_config.clamp_strength(
		launch_board.distance_to(pointer_board) / launch_config.mouse_max_distance_board_ratio
	)
	_refresh_hud()


func _on_launch_requested() -> void:
	var slot := _inventory.get_selected_slot()
	if slot == null or _current_shot_id == &"":
		_show_status("발사할 공이 준비되지 않았습니다.")
		return
	_request_sequence += 1
	var command := LaunchCommand.new()
	command.request_id = StringName("launch_request_%03d" % _request_sequence)
	command.shot_id = _current_shot_id
	command.slot_id = slot.slot_id
	command.ball_id = slot.get_ball_id()
	command.launch_anchor_id = _board.get_launch_anchor_id()
	command.board_direction = _get_aim_board_direction()
	command.normalized_strength = _aim_strength
	var solution := _launch_strategy.calculate(
		command,
		launch_config,
		slot.ball_definition.physics_profile,
		_board.get_launch_forward_direction()
	)
	if not solution.is_valid():
		_show_status(solution.validation_errors[0])
		return
	var physics_error := _physics_adapter.apply_launch(solution)
	if not physics_error.is_empty():
		_show_status(physics_error)
		return
	var shot_error := _shot_controller.start_shot(command, solution)
	if not shot_error.is_empty():
		_show_status(shot_error)
		return
	_input_router.enter_ball_in_play()
	_selected_flipper_direction = &""
	_show_status("공이 진행 중입니다. 방향키로 플리퍼를 고르고 Space로 작동 요청하세요.")
	_refresh_hud()


func _on_flipper_selection_requested(direction_id: StringName) -> void:
	var anchor_id := _board.get_layout_config().get_flipper_anchor_id_for_direction(direction_id)
	if anchor_id == &"":
		_show_status("이 방향에 배정된 플리퍼가 없습니다: %s" % _get_direction_label(direction_id))
		return
	_selected_flipper_direction = direction_id
	_show_status("%s 플리퍼를 선택했습니다." % _get_direction_label(direction_id))
	_refresh_hud()


func _on_flipper_action_requested() -> void:
	if _selected_flipper_direction == &"":
		_show_status("방향키로 플리퍼를 먼저 선택하세요.")
		return
	_show_status("선택한 플리퍼 작동 요청을 확인했습니다. 실제 움직임은 5단계에서 연결됩니다.")


func _on_ball_exit_detected(shot_id: StringName, end_reason: StringName) -> void:
	if (
		_shot_controller.current_phase != ShotPhases.IN_PLAY
		or shot_id != _shot_controller.get_active_shot_id()
	):
		return
	var snapshot := _physics_adapter.get_snapshot(shot_id)
	var result := _shot_controller.finish_shot(shot_id, end_reason, snapshot)
	if result == null:
		return
	_input_router.enter_resolving()
	var consume_error := _inventory.consume_slot(result.slot_id)
	var remove_error := _physics_adapter.remove_ball(shot_id)
	if not consume_error.is_empty():
		_show_status(consume_error)
	elif not remove_error.is_empty():
		_show_status(remove_error)
	else:
		_show_status("공이 낙하했습니다. 다음 발사를 준비합니다.")
	_refresh_hud()
	call_deferred("_finish_resolution", shot_id)


func _finish_resolution(shot_id: StringName) -> void:
	var return_error := _shot_controller.return_to_ball_selection()
	if not return_error.is_empty():
		_show_status(return_error)
		return
	_current_shot_id = &""
	if _inventory.get_remaining_count() <= 0:
		_wave_complete = true
		_input_router.enter_complete()
		_show_status("가져온 공을 모두 사용했습니다. 스코어 성공·실패 판정은 7단계에서 연결됩니다.")
	else:
		_input_router.enter_ball_selection()
		_select_current_inventory_ball()
		_show_status("다음 공을 선택한 뒤 Space로 확정하세요.")
	_board.clear_finished_shot(shot_id)
	_refresh_hud()


func _refresh_hud() -> void:
	if _phase_label != null:
		_phase_label.text = "현재 단계: %s" % _get_phase_label()
	if _balls_label != null:
		_balls_label.text = _get_ball_list_text()
	if _aim_label != null:
		_aim_label.text = "조준 방식: %s\n방향: %+.1f°" % [
			_get_aim_mode_label(),
			_aim_angle_degrees,
		]
	if _strength_label != null:
		_strength_label.text = "발사 세기: %d%%" % roundi(_aim_strength * 100.0)
	if _flipper_label != null:
		_flipper_label.text = "선택 플리퍼: %s" % (
			"없음" if _selected_flipper_direction == &"" else _get_direction_label(_selected_flipper_direction)
		)
	if _controls_label != null:
		_controls_label.text = _get_controls_text()
	if _aim_guide != null:
		_aim_guide.visible = _shot_controller.current_phase == ShotPhases.AIMING
		if _aim_guide.visible:
			var launch_board := _board.get_launch_board_position()
			var guide_length := (
				launch_config.aim_guide_length_board_ratio * _aim_strength
			)
			var target_board := (
				launch_board
					+ _get_aim_board_direction() * guide_length
			)
			_aim_guide.points = PackedVector2Array([
				_board.board_to_local(launch_board),
				_board.board_to_local(target_board),
			])


func _get_ball_list_text() -> String:
	var lines := PackedStringArray(["웨이브 공"])
	if ball_loadout == null:
		return "\n".join(lines)
	for slot_index in ball_loadout.slots.size():
		var slot := ball_loadout.slots[slot_index]
		if slot == null or slot.ball_definition == null:
			continue
		var state := "남음"
		if _inventory.is_consumed(slot.slot_id):
			state = "소모"
		elif _inventory.selected_slot_id == slot.slot_id:
			state = "선택"
		lines.append("%d. %s · %s" % [slot_index + 1, slot.ball_definition.display_name, state])
	return "\n".join(lines)


func _get_phase_label() -> String:
	if _wave_complete:
		return "발사 종료"
	match _shot_controller.current_phase:
		ShotPhases.BALL_SELECTION:
			return "공 선택"
		ShotPhases.AIMING:
			return "공 조준"
		ShotPhases.IN_PLAY:
			return "발사 진행"
		ShotPhases.RESOLVING:
			return "낙하 처리"
	return "발사 종료"


func _get_controls_text() -> String:
	if _wave_complete:
		return "가져온 공 사용 완료"
	match _shot_controller.current_phase:
		ShotPhases.BALL_SELECTION:
			return "1·2·3: 공 선택\n방향키: 남은 공 이동\nSpace: 선택 확정"
		ShotPhases.AIMING:
			if _get_display_aim_mode() == LaunchAimModes.MOUSE:
				return "마우스: 방향·세기 조준\nSpace: 공 발사"
			return "← →: 방향\n↑ ↓: 세기\nSpace: 공 발사"
		ShotPhases.IN_PLAY:
			return "방향키: 플리퍼 선택\nSpace: 플리퍼 작동"
		ShotPhases.RESOLVING:
			return "낙하 결과 처리 중\n입력 잠금"
	return "가져온 공 사용 완료"


func _get_aim_mode_label() -> String:
	if _get_display_aim_mode() == LaunchAimModes.DIRECTION_KEYS:
		return "방향키"
	return "마우스"


func _get_display_aim_mode() -> StringName:
	if _input_router != null and _shot_controller.current_phase == ShotPhases.AIMING:
		return _input_router.active_aim_mode
	if launch_config != null:
		return launch_config.get_aim_mode_id()
	return LaunchAimModes.MOUSE


func _get_aim_board_direction() -> Vector2:
	return _board.get_launch_forward_direction().rotated(deg_to_rad(_aim_angle_degrees)).normalized()


func _get_direction_label(direction_id: StringName) -> String:
	match direction_id:
		&"left":
			return "왼쪽"
		&"right":
			return "오른쪽"
		&"up":
			return "위쪽"
		&"down":
			return "아래쪽"
	return "미지정"


func _board_radius_to_local(_board_position: Vector2, radius_board_ratio: float) -> float:
	return _board.get_board_width_pixels() * radius_board_ratio


func _board_to_world_position(board_position: Vector2) -> Vector2:
	return _board.to_global(_board.board_to_local(board_position))


func _world_to_board_position(world_position: Vector2) -> Vector2:
	return _board.local_to_board(_board.to_local(world_position))


func _board_to_world_velocity(board_position: Vector2, board_velocity: Vector2) -> Vector2:
	var local_velocity := _board.board_velocity_to_local(board_position, board_velocity)
	return _board.global_transform.basis_xform(local_velocity)


func _world_to_board_velocity(world_position: Vector2, world_velocity: Vector2) -> Vector2:
	var local_position := _board.to_local(world_position)
	var local_velocity := _board.global_transform.affine_inverse().basis_xform(world_velocity)
	return _board.local_velocity_to_board(local_position, local_velocity)


func _show_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func get_shot_phase() -> StringName:
	return _shot_controller.current_phase


func get_remaining_ball_count() -> int:
	return _inventory.get_remaining_count()


func get_selected_slot_id() -> StringName:
	return _inventory.selected_slot_id


func get_active_shot_id() -> StringName:
	return _shot_controller.get_active_shot_id()


func has_active_ball() -> bool:
	return _physics_adapter.has_active_ball()


func is_wave_mockup_complete() -> bool:
	return _wave_complete


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
