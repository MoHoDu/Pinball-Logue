class_name FlipperPhysics2DAdapter
extends FlipperPhysicsAdapter

var _world_to_board_position := Callable()
var _board_to_world_velocity := Callable()
var _world_to_board_velocity := Callable()
var _flippers_by_anchor := {}
var _action_records := {}
var _completed_action_ids := {}


func configure(
	world_to_board_position: Callable,
	board_to_world_velocity: Callable,
	world_to_board_velocity: Callable
) -> String:
	if not world_to_board_position.is_valid():
		return "2D 위치를 보드 위치로 바꾸는 변환이 없습니다."
	if not board_to_world_velocity.is_valid():
		return "보드 속도를 2D 속도로 바꾸는 변환이 없습니다."
	if not world_to_board_velocity.is_valid():
		return "2D 속도를 보드 속도로 바꾸는 변환이 없습니다."
	_world_to_board_position = world_to_board_position
	_board_to_world_velocity = board_to_world_velocity
	_world_to_board_velocity = world_to_board_velocity
	return ""


func register_flipper(anchor_id: StringName, flipper: Flipper2D) -> String:
	if anchor_id == &"":
		return "등록할 플리퍼 배치 지점 식별자가 비어 있습니다."
	if flipper == null or not is_instance_valid(flipper):
		return "등록할 2D 플리퍼가 없습니다."
	if _flippers_by_anchor.has(anchor_id):
		return "같은 배치 지점에 플리퍼를 두 번 등록할 수 없습니다: %s" % anchor_id
	if flipper.anchor_id != anchor_id:
		return "플리퍼와 등록 요청의 배치 지점 식별자가 다릅니다: %s" % anchor_id
	_flippers_by_anchor[anchor_id] = flipper
	flipper.parry_contact.connect(_on_parry_contact)
	flipper.action_finished.connect(_on_flipper_action_finished)
	return ""


func activate(command: FlipperActionCommand) -> String:
	if command == null:
		return "플리퍼 작동 명령이 없습니다."
	var command_errors := command.get_validation_errors()
	if not command_errors.is_empty():
		return command_errors[0]
	if _action_records.has(command.action_id) or _completed_action_ids.has(command.action_id):
		return "같은 플리퍼 작동 식별자를 다시 사용할 수 없습니다: %s" % command.action_id
	for anchor_id in command.anchor_ids:
		var flipper := _flippers_by_anchor.get(StringName(anchor_id)) as Flipper2D
		if flipper == null or not is_instance_valid(flipper):
			return "작동 명령에 포함된 플리퍼가 등록되지 않았습니다: %s" % anchor_id
		if not flipper.can_activate():
			return "플리퍼가 이전 작동을 마치고 복귀할 때까지 기다려야 합니다: %s" % anchor_id

	var anchor_ids := command.anchor_ids.duplicate()
	_action_records[command.action_id] = {
		"anchor_ids": anchor_ids,
		"remaining_anchor_ids": anchor_ids.duplicate(),
		"shot_id": command.shot_id,
		"parried": false,
	}
	for anchor_id in anchor_ids:
		var flipper := _flippers_by_anchor[StringName(anchor_id)] as Flipper2D
		var activation_error := flipper.start_action(command.action_id)
		if not activation_error.is_empty():
			_reset_action(command.action_id, anchor_ids)
			return activation_error
	action_started.emit(command.action_id, anchor_ids)
	return ""


func physics_tick(delta: float) -> void:
	for anchor_id in get_registered_anchor_ids():
		var flipper := _flippers_by_anchor.get(anchor_id) as Flipper2D
		if flipper != null and is_instance_valid(flipper):
			flipper.physics_tick(delta)


func reset() -> void:
	for anchor_id in get_registered_anchor_ids():
		var flipper := _flippers_by_anchor.get(anchor_id) as Flipper2D
		if flipper != null and is_instance_valid(flipper):
			flipper.reset_to_idle()
	_action_records.clear()
	_completed_action_ids.clear()


func is_action_active(action_id: StringName) -> bool:
	return _action_records.has(action_id)


func get_registered_anchor_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for anchor_id in _flippers_by_anchor.keys():
		result.append(String(anchor_id))
	result.sort()
	return result


func _on_parry_contact(
	action_id: StringName,
	anchor_id: StringName,
	body: Ball2D,
	world_direction: Vector2,
	base_speed_board_per_second: float,
	multiplier: float
) -> void:
	if not _action_records.has(action_id):
		return
	var record: Dictionary = _action_records[action_id]
	if bool(record.get("parried", false)):
		return
	var expected_shot_id := StringName(record.get("shot_id", &""))
	var actual_shot_id := StringName(body.get_meta(&"shot_id", &""))
	if expected_shot_id != &"" and actual_shot_id != expected_shot_id:
		return
	if not _has_valid_coordinate_converters():
		return

	var board_position_variant: Variant = _world_to_board_position.call(body.global_position)
	var board_velocity_variant: Variant = _world_to_board_velocity.call(
		body.global_position,
		body.linear_velocity
	)
	var board_direction_variant: Variant = _world_to_board_velocity.call(
		body.global_position,
		world_direction * 100.0
	)
	if (
		not board_position_variant is Vector2
		or not board_velocity_variant is Vector2
		or not board_direction_variant is Vector2
	):
		return
	var board_position: Vector2 = board_position_variant
	var board_velocity: Vector2 = board_velocity_variant
	var board_direction: Vector2 = board_direction_variant
	if (
		not _is_finite_vector(board_position)
		or not _is_finite_vector(board_velocity)
		or not _is_finite_vector(board_direction)
		or board_direction.is_zero_approx()
	):
		return

	var target_board_velocity := board_velocity + (
		board_direction.normalized()
		* base_speed_board_per_second
		* multiplier
	)
	if body.max_linear_speed_board_per_second > 0.0:
		target_board_velocity = target_board_velocity.limit_length(
			body.max_linear_speed_board_per_second
		)
	var target_world_velocity_variant: Variant = _board_to_world_velocity.call(
		board_position,
		target_board_velocity
	)
	if not target_world_velocity_variant is Vector2:
		return
	var target_world_velocity: Vector2 = target_world_velocity_variant
	if not _is_finite_vector(target_world_velocity):
		return
	var impulse := (target_world_velocity - body.linear_velocity) * body.mass
	body.apply_central_impulse(impulse)
	body.linear_velocity = target_world_velocity
	record["parried"] = true
	_action_records[action_id] = record
	parry_applied.emit(action_id, anchor_id, actual_shot_id)


func _on_flipper_action_finished(
	action_id: StringName,
	anchor_id: StringName
) -> void:
	if not _action_records.has(action_id):
		return
	var record: Dictionary = _action_records[action_id]
	var remaining_anchor_ids: PackedStringArray = record["remaining_anchor_ids"]
	var finished_anchor_index := remaining_anchor_ids.find(String(anchor_id))
	if finished_anchor_index < 0:
		return
	remaining_anchor_ids.remove_at(finished_anchor_index)
	record["remaining_anchor_ids"] = remaining_anchor_ids
	_action_records[action_id] = record
	if not remaining_anchor_ids.is_empty():
		return
	var anchor_ids: PackedStringArray = record["anchor_ids"]
	_action_records.erase(action_id)
	_completed_action_ids[action_id] = true
	action_finished.emit(action_id, anchor_ids)


func _reset_action(
	action_id: StringName,
	anchor_ids: PackedStringArray
) -> void:
	for anchor_id in anchor_ids:
		var flipper := _flippers_by_anchor.get(StringName(anchor_id)) as Flipper2D
		if flipper != null and is_instance_valid(flipper):
			flipper.reset_to_idle()
	_action_records.erase(action_id)


func _has_valid_coordinate_converters() -> bool:
	return (
		_world_to_board_position.is_valid()
		and _board_to_world_velocity.is_valid()
		and _world_to_board_velocity.is_valid()
	)


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
