class_name BumperPhysics2DAdapter
extends RefCounted

signal hit_applied(result: BumperHitResult)

const BALL_GROUP: StringName = &"pinball_ball_2d"
const SWEEP_EPSILON := 0.000001
const SWEEP_SKIN_PIXELS := 0.5
const MAX_SWEEP_CONTACTS_PER_TICK := 4

var _parent: Node2D
var _world_to_board_position := Callable()
var _board_to_world_position := Callable()
var _world_to_board_velocity := Callable()
var _board_to_world_velocity := Callable()
var _board_radius_to_world := Callable()

var _runtimes_by_point_id: Dictionary = {}
var _states_by_point_id: Dictionary = {}
var _definitions_by_point_id: Dictionary = {}
var _placements_by_point_id: Dictionary = {}
var _controlled_balls: Dictionary = {}
var _hit_sequence := 0


func configure(
	parent: Node2D,
	world_to_board_position: Callable,
	board_to_world_position: Callable,
	world_to_board_velocity: Callable,
	board_to_world_velocity: Callable,
	board_radius_to_world: Callable
) -> String:
	if parent == null:
		return "2D 범퍼를 추가할 부모 노드가 없습니다."
	for transform_callable in [
		world_to_board_position,
		board_to_world_position,
		world_to_board_velocity,
		board_to_world_velocity,
		board_radius_to_world,
	]:
		if not transform_callable.is_valid():
			return "2D 범퍼에 필요한 보드 좌표 변환이 연결되지 않았습니다."
	_parent = parent
	_world_to_board_position = world_to_board_position
	_board_to_world_position = board_to_world_position
	_world_to_board_velocity = world_to_board_velocity
	_board_to_world_velocity = board_to_world_velocity
	_board_radius_to_world = board_radius_to_world
	return ""


func register_bumper(
	runtime: BumperRuntime2D,
	definition: BumperDefinition,
	placement: Dictionary
) -> String:
	if runtime == null or definition == null:
		return "등록할 2D 범퍼 또는 범퍼 원형이 없습니다."
	if runtime.point_id == &"":
		return "등록할 2D 범퍼의 배치 지점 식별자가 비어 있습니다."
	if _runtimes_by_point_id.has(runtime.point_id):
		return "같은 범퍼 배치 지점을 두 번 등록할 수 없습니다: %s" % runtime.point_id
	var state := BumperRuntimeState.new()
	var state_error := state.configure(runtime.point_id, definition)
	if not state_error.is_empty():
		return state_error
	_runtimes_by_point_id[runtime.point_id] = runtime
	_states_by_point_id[runtime.point_id] = state
	_definitions_by_point_id[runtime.point_id] = definition
	_placements_by_point_id[runtime.point_id] = placement.duplicate(true)
	runtime.set_ball_scope(_parent)
	runtime.contact_started.connect(_on_contact_started)
	runtime.contact_ended.connect(_on_contact_ended)
	return ""


func physics_tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_advance_controlled_balls(delta)
	_process_swept_contacts(delta)
	_advance_recovery(delta)


func reset_for_new_shot() -> void:
	_release_all_controlled_balls()
	_hit_sequence = 0
	for point_id in _states_by_point_id:
		var state := _states_by_point_id[point_id] as BumperRuntimeState
		var runtime := _runtimes_by_point_id[point_id] as BumperRuntime2D
		state.reset_for_new_shot()
		runtime.set_recovery_telegraph(false)
		runtime.set_collision_active(true)


func reset() -> void:
	_release_all_controlled_balls()
	for runtime in _runtimes_by_point_id.values():
		if is_instance_valid(runtime):
			runtime.queue_free()
	_runtimes_by_point_id.clear()
	_states_by_point_id.clear()
	_definitions_by_point_id.clear()
	_placements_by_point_id.clear()
	_hit_sequence = 0


func get_runtime(point_id: StringName) -> BumperRuntime2D:
	return _runtimes_by_point_id.get(point_id) as BumperRuntime2D


func _on_contact_started(
	point_id: StringName,
	body: Ball2D,
	contact_id: StringName,
	contact_time_fraction: float,
	contact_world_position: Vector2,
	world_normal: Vector2
) -> void:
	if not _states_by_point_id.has(point_id) or not is_instance_valid(body):
		return
	var board_position_variant: Variant = _world_to_board_position.call(contact_world_position)
	var board_velocity_variant: Variant = _world_to_board_velocity.call(
		body.global_position,
		body.linear_velocity
	)
	var board_normal_variant: Variant = _world_to_board_velocity.call(
		contact_world_position,
		world_normal
	)
	if not board_position_variant is Vector2 or not board_velocity_variant is Vector2 or not board_normal_variant is Vector2:
		return
	var board_position: Vector2 = board_position_variant
	var board_velocity: Vector2 = board_velocity_variant
	var board_normal: Vector2 = board_normal_variant
	if not _is_finite_vector(board_position) or not _is_finite_vector(board_velocity) or not _is_finite_vector(board_normal):
		return
	if board_normal.is_zero_approx():
		board_normal = Vector2.UP
	else:
		board_normal = board_normal.normalized()

	var state := _states_by_point_id[point_id] as BumperRuntimeState
	var definition := _definitions_by_point_id[point_id] as BumperDefinition
	var placement := _placements_by_point_id[point_id] as Dictionary
	_hit_sequence += 1
	var request := BumperHitRequest.new()
	request.shot_id = StringName(body.get_meta(&"shot_id", ""))
	request.ball_id = StringName(body.get_meta(&"ball_id", ""))
	request.point_id = point_id
	request.content_id = definition.content_id
	request.contact_id = contact_id
	request.contact_time_fraction = contact_time_fraction
	request.hit_id = StringName("hit_%06d" % _hit_sequence)
	request.contact_board_position = board_position
	request.contact_board_normal = board_normal
	request.incoming_board_velocity = board_velocity
	request.reflected_board_velocity = _get_reflected_board_velocity(
		board_velocity,
		board_normal
	)
	request.ball_max_speed_board_per_second = body.max_linear_speed_board_per_second
	request.track_path_board_positions = _to_packed_vector2_array(
		placement.get("track_path_board_positions", PackedVector2Array())
	)
	var shot_target: Variant = placement.get("shot_target_board_position", Vector2(INF, INF))
	if shot_target is Vector2:
		request.shot_target_board_position = shot_target

	var result := state.try_apply_hit(request)
	if result == null or not result.is_applied:
		return
	_apply_hit_result(body, result)
	var runtime := _runtimes_by_point_id[point_id] as BumperRuntime2D
	_sync_runtime_lifecycle(runtime, state)
	hit_applied.emit(result)


func _on_contact_ended(point_id: StringName, contact_id: StringName) -> void:
	var state := _states_by_point_id.get(point_id) as BumperRuntimeState
	if state != null:
		state.end_contact(contact_id)


func _apply_hit_result(body: Ball2D, result: BumperHitResult) -> void:
	match result.effect_type:
		BumperHitResult.EFFECT_TRACK:
			_start_track_control(body, result)
		_:
			_apply_board_velocity(body, result.output_board_velocity)


func _apply_board_velocity(body: Ball2D, board_velocity: Vector2) -> void:
	if not is_instance_valid(body) or not _is_finite_vector(board_velocity):
		return
	var board_position_variant: Variant = _world_to_board_position.call(body.global_position)
	if not board_position_variant is Vector2:
		return
	var world_velocity_variant: Variant = _board_to_world_velocity.call(
		board_position_variant,
		board_velocity.limit_length(body.max_linear_speed_board_per_second)
	)
	if world_velocity_variant is Vector2 and _is_finite_vector(world_velocity_variant):
		body.linear_velocity = world_velocity_variant
		body.sleeping = false


func _start_track_control(body: Ball2D, result: BumperHitResult) -> void:
	if not is_instance_valid(body) or result.track_path_board_positions.is_empty():
		_apply_board_velocity(body, result.output_board_velocity)
		return
	var exit_velocity := result.output_board_velocity
	var current_board_position := Vector2.ZERO
	var board_position_variant: Variant = _world_to_board_position.call(body.global_position)
	if board_position_variant is Vector2:
		current_board_position = board_position_variant
	var path := result.track_path_board_positions
	var exit_origin := current_board_position if path.size() == 1 else path[path.size() - 2]
	var exit_direction := exit_origin.direction_to(path[path.size() - 1])
	if not exit_direction.is_zero_approx():
		exit_velocity = exit_direction * minf(
			result.track_speed_board_per_second,
			body.max_linear_speed_board_per_second
		)
	body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	_controlled_balls[body.get_instance_id()] = {
		"body": body,
		"path": result.track_path_board_positions,
		"path_index": 0,
		"speed": result.track_speed_board_per_second,
		"exit_velocity": exit_velocity,
	}


func _advance_controlled_balls(delta: float) -> void:
	for body_id in _controlled_balls.keys():
		var control := _controlled_balls[body_id] as Dictionary
		var body := control.get("body") as Ball2D
		if not is_instance_valid(body):
			_controlled_balls.erase(body_id)
			continue
		var current_variant: Variant = _world_to_board_position.call(body.global_position)
		if not current_variant is Vector2:
			_release_controlled_ball(body_id, false)
			continue
		var current: Vector2 = current_variant
		var path: PackedVector2Array = control["path"]
		var path_index: int = control["path_index"]
		var remaining := maxf(float(control["speed"]) * delta, 0.0)
		while remaining > 0.0 and path_index < path.size():
			var target := path[path_index]
			var distance := current.distance_to(target)
			if distance <= remaining + SWEEP_EPSILON:
				current = target
				remaining -= distance
				path_index += 1
			else:
				current = current.move_toward(target, remaining)
				remaining = 0.0
		control["path_index"] = path_index
		var world_position_variant: Variant = _board_to_world_position.call(current)
		if world_position_variant is Vector2 and _is_finite_vector(world_position_variant):
			body.global_position = world_position_variant
		if path_index >= path.size():
			_release_controlled_ball(body_id, true)


func _release_controlled_ball(body_id: int, apply_exit_velocity: bool) -> void:
	if not _controlled_balls.has(body_id):
		return
	var control := _controlled_balls[body_id] as Dictionary
	_controlled_balls.erase(body_id)
	var body := control.get("body") as Ball2D
	if not is_instance_valid(body):
		return
	body.freeze = false
	body.sleeping = false
	if apply_exit_velocity:
		_apply_board_velocity(body, control.get("exit_velocity", Vector2.ZERO))


func _release_all_controlled_balls() -> void:
	for body_id in _controlled_balls.keys():
		_release_controlled_ball(body_id, false)


func _advance_recovery(delta: float) -> void:
	for point_id in _states_by_point_id:
		var state := _states_by_point_id[point_id] as BumperRuntimeState
		var runtime := _runtimes_by_point_id[point_id] as BumperRuntime2D
		var is_safe_clear := runtime.is_safe_clear_for_balls(delta)
		state.advance_recovery(delta, is_safe_clear)
		_sync_runtime_lifecycle(runtime, state)


func _sync_runtime_lifecycle(runtime: BumperRuntime2D, state: BumperRuntimeState) -> void:
	runtime.set_recovery_telegraph(state.is_recovery_warning_active())
	runtime.set_collision_active(state.is_collision_active())


func _process_swept_contacts(delta: float) -> void:
	if _parent == null or not is_instance_valid(_parent):
		return
	var tree := _parent.get_tree()
	if tree == null:
		return
	for candidate in tree.get_nodes_in_group(BALL_GROUP):
		if not candidate is Ball2D or not _parent.is_ancestor_of(candidate):
			continue
		var body := candidate as Ball2D
		if body.freeze or _controlled_balls.has(body.get_instance_id()):
			continue
		var start := body.global_position
		var motion := body.linear_velocity * delta
		if motion.length_squared() <= SWEEP_EPSILON:
			continue
		var ball_radius := _get_ball_radius_pixels(body)
		var contacts_processed := 0
		while contacts_processed < MAX_SWEEP_CONTACTS_PER_TICK:
			var candidate_contact := _find_first_sweep_contact(start, motion, ball_radius)
			if candidate_contact.is_empty():
				break
			var runtime := candidate_contact["runtime"] as BumperRuntime2D
			var fraction: float = candidate_contact["fraction"]
			var normal: Vector2 = candidate_contact["normal"]
			var center_at_contact := start + motion * fraction + normal * SWEEP_SKIN_PIXELS
			body.global_position = center_at_contact
			var began := runtime.begin_swept_contact(
				body,
				fraction,
				runtime.global_position + normal * runtime.collision_radius_pixels
			)
			if not began:
				break
			contacts_processed += 1
			break


func _find_first_sweep_contact(
	start: Vector2,
	motion: Vector2,
	ball_radius: float
) -> Dictionary:
	var best: Dictionary = {}
	for point_id in _runtimes_by_point_id:
		var runtime := _runtimes_by_point_id[point_id] as BumperRuntime2D
		if not runtime.is_collision_active():
			continue
		var combined_radius := runtime.collision_radius_pixels + ball_radius
		var fraction := _segment_circle_first_fraction(
			start,
			motion,
			runtime.global_position,
			combined_radius
		)
		if fraction < 0.0:
			continue
		if (
			best.is_empty()
			or fraction < float(best["fraction"]) - SWEEP_EPSILON
			or (
				is_equal_approx(fraction, float(best["fraction"]))
				and String(point_id) < String(best["point_id"])
			)
		):
			var center_at_contact := start + motion * fraction
			var normal := runtime.global_position.direction_to(center_at_contact)
			if normal.is_zero_approx():
				normal = Vector2.UP
			best = {
				"point_id": point_id,
				"runtime": runtime,
				"fraction": fraction,
				"normal": normal,
			}
	return best


func _segment_circle_first_fraction(
	start: Vector2,
	motion: Vector2,
	center: Vector2,
	radius: float
) -> float:
	var relative := start - center
	var c := relative.length_squared() - radius * radius
	if c <= 0.0:
		return 0.0
	var a := motion.length_squared()
	if a <= SWEEP_EPSILON:
		return -1.0
	var b := 2.0 * relative.dot(motion)
	if b >= 0.0:
		return -1.0
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var fraction := (-b - sqrt(discriminant)) / (2.0 * a)
	return fraction if fraction >= 0.0 and fraction <= 1.0 else -1.0


func _get_ball_radius_pixels(body: Ball2D) -> float:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is CircleShape2D:
		return (shape_node.shape as CircleShape2D).radius
	return 0.0


func _to_packed_vector2_array(value: Variant) -> PackedVector2Array:
	if value is PackedVector2Array:
		return value
	var result := PackedVector2Array()
	if value is Array:
		for item in value:
			if item is Vector2:
				result.append(item)
	return result


func _get_reflected_board_velocity(
	board_velocity: Vector2,
	board_normal: Vector2
) -> Vector2:
	if board_velocity.dot(board_normal) >= 0.0:
		return board_velocity
	return board_velocity.bounce(board_normal)


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
