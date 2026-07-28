class_name Flipper2D
extends AnimatableBody2D

signal parry_contact(
	action_id: StringName,
	anchor_id: StringName,
	body: Ball2D,
	world_direction: Vector2,
	base_speed_board_per_second: float,
	multiplier: float
)
signal action_finished(action_id: StringName, anchor_id: StringName)

const ROLE_LEFT := &"left"
const ROLE_RIGHT := &"right"

enum MotionState {
	IDLE,
	ACTIVATING,
	HOLDING,
	RETURNING,
}

@export var fill_color := Color("ef704c")
@export var outline_color := Color("793c2b")

var anchor_id: StringName = &""
var role_id: StringName = ROLE_LEFT
var motion_profile: FlipperMotionProfile

var _motion_state := MotionState.IDLE
var _state_elapsed := 0.0
var _action_elapsed := 0.0
var _rest_rotation := 0.0
var _active_rotation := 0.0
var _swing_sign := -1.0
var _current_action_id: StringName = &""
var _contact_reported := false
var _length_pixels := 80.0
var _width_pixels := 18.0
var _presentation_instance: Node2D
var _draw_builtin_visual := true


func configure(
	requested_anchor_id: StringName,
	requested_role_id: StringName,
	profile: FlipperMotionProfile,
	resting_direction: Vector2,
	board_center_direction: Vector2,
	length_pixels: float,
	width_pixels: float
) -> String:
	if requested_anchor_id == &"":
		return "플리퍼 배치 지점 식별자가 비어 있습니다."
	if requested_role_id != ROLE_LEFT and requested_role_id != ROLE_RIGHT:
		return "플리퍼 역할은 왼쪽 또는 오른쪽이어야 합니다."
	if profile == null:
		return "플리퍼 작동 설정이 없습니다."
	var profile_errors := profile.get_validation_errors()
	if not profile_errors.is_empty():
		return profile_errors[0]
	if not _is_finite_vector(resting_direction) or resting_direction.is_zero_approx():
		return "플리퍼가 쉬는 방향은 유효한 방향이어야 합니다."
	if not _is_finite_vector(board_center_direction) or board_center_direction.is_zero_approx():
		return "플리퍼 배치 지점에서 보드 중심을 향하는 방향이 필요합니다."
	if not is_finite(length_pixels) or length_pixels <= 0.0:
		return "2D 플리퍼 길이는 유한한 양수여야 합니다."
	if not is_finite(width_pixels) or width_pixels <= 0.0:
		return "2D 플리퍼 너비는 유한한 양수여야 합니다."

	anchor_id = requested_anchor_id
	role_id = requested_role_id
	motion_profile = profile
	_length_pixels = length_pixels
	_width_pixels = width_pixels
	_rest_rotation = resting_direction.normalized().angle()
	var center_angle_delta := resting_direction.normalized().angle_to(
		board_center_direction.normalized()
	)
	_swing_sign = signf(center_angle_delta)
	if is_zero_approx(_swing_sign):
		_swing_sign = -1.0 if role_id == ROLE_LEFT else 1.0
	_active_rotation = _rest_rotation + deg_to_rad(
		motion_profile.activation_angle_degrees * _get_swing_sign()
	)
	_configure_collision_shapes()
	reset_to_idle()
	queue_redraw()
	return ""


func can_activate() -> bool:
	return motion_profile != null and _motion_state == MotionState.IDLE


func set_presentation_scene(presentation_scene: PackedScene) -> String:
	if presentation_scene == null or not presentation_scene.can_instantiate():
		return "플리퍼에 연결할 2D 디자인 장면이 올바르지 않습니다."
	if is_instance_valid(_presentation_instance):
		_presentation_instance.queue_free()
	var instance := presentation_scene.instantiate()
	if not instance is Node2D:
		instance.free()
		return "플리퍼 2D 디자인의 루트는 Node2D여야 합니다."
	_presentation_instance = instance
	_presentation_instance.name = "Presentation2D"
	add_child(_presentation_instance)
	if _presentation_instance is BoardObjectPreview2D:
		var source_length: float = float(_presentation_instance.preview_size) * 4.4
		var source_width: float = float(_presentation_instance.preview_size) * 0.75
		_presentation_instance.scale = Vector2(
			_length_pixels / source_length,
			_width_pixels / source_width
		)
	_draw_builtin_visual = false
	queue_redraw()
	return ""


func start_action(action_id: StringName) -> String:
	if action_id == &"":
		return "플리퍼 작동 식별자가 비어 있습니다."
	if not can_activate():
		return "플리퍼가 이전 작동을 마치고 복귀할 때까지 기다려야 합니다: %s" % anchor_id
	_current_action_id = action_id
	_motion_state = MotionState.ACTIVATING
	_state_elapsed = 0.0
	_action_elapsed = 0.0
	_contact_reported = false
	return ""


func physics_tick(delta: float) -> void:
	if _motion_state == MotionState.IDLE or motion_profile == null:
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	_action_elapsed += delta
	var remaining_delta := delta
	while remaining_delta > 0.0 and _motion_state != MotionState.IDLE:
		remaining_delta = _advance_motion_state(remaining_delta)
	_detect_parry_contact()


func reset_to_idle() -> void:
	_motion_state = MotionState.IDLE
	_state_elapsed = 0.0
	_action_elapsed = 0.0
	_current_action_id = &""
	_contact_reported = false
	rotation = _rest_rotation


func is_action_active() -> bool:
	return _motion_state != MotionState.IDLE


func get_motion_state() -> MotionState:
	return _motion_state


func _advance_motion_state(delta: float) -> float:
	var duration := _get_state_duration()
	if duration <= 0.0:
		_complete_current_state()
		return delta
	var consumed := minf(delta, duration - _state_elapsed)
	_state_elapsed += consumed
	_apply_current_rotation(_state_elapsed / duration)
	if _state_elapsed >= duration - 0.000001:
		_complete_current_state()
	return delta - consumed


func _get_state_duration() -> float:
	match _motion_state:
		MotionState.ACTIVATING:
			return motion_profile.activation_seconds
		MotionState.HOLDING:
			return motion_profile.hold_seconds
		MotionState.RETURNING:
			return motion_profile.return_seconds
	return 0.0


func _apply_current_rotation(progress: float) -> void:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	match _motion_state:
		MotionState.ACTIVATING:
			rotation = lerp_angle(_rest_rotation, _active_rotation, clamped_progress)
		MotionState.HOLDING:
			rotation = _active_rotation
		MotionState.RETURNING:
			rotation = lerp_angle(_active_rotation, _rest_rotation, clamped_progress)


func _complete_current_state() -> void:
	_state_elapsed = 0.0
	match _motion_state:
		MotionState.ACTIVATING:
			rotation = _active_rotation
			_motion_state = MotionState.HOLDING
		MotionState.HOLDING:
			rotation = _active_rotation
			_motion_state = MotionState.RETURNING
		MotionState.RETURNING:
			var finished_action_id := _current_action_id
			rotation = _rest_rotation
			_motion_state = MotionState.IDLE
			_current_action_id = &""
			action_finished.emit(finished_action_id, anchor_id)


func _detect_parry_contact() -> void:
	if (
		_contact_reported
		or _current_action_id == &""
		or _action_elapsed > motion_profile.parry_window_seconds
	):
		return
	var sensor := get_node_or_null("ParrySensor") as Area2D
	if sensor == null:
		return
	for body in sensor.get_overlapping_bodies():
		if body is Ball2D:
			_contact_reported = true
			var tip_direction := Vector2.RIGHT.rotated(global_rotation)
			var parry_direction := tip_direction.orthogonal() * _get_swing_sign()
			parry_contact.emit(
				_current_action_id,
				anchor_id,
				body,
				parry_direction.normalized(),
				motion_profile.base_hit_impulse_board_per_second,
				motion_profile.parry_impulse_multiplier
			)
			return


func _configure_collision_shapes() -> void:
	var body_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var sensor_shape := get_node_or_null("ParrySensor/CollisionShape2D") as CollisionShape2D
	if body_shape != null:
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(_length_pixels, _width_pixels)
		body_shape.position = Vector2(_length_pixels * 0.5, 0.0)
		body_shape.shape = rectangle
	if sensor_shape != null:
		var sensor_rectangle := RectangleShape2D.new()
		sensor_rectangle.size = Vector2(_length_pixels, _width_pixels * 1.35)
		sensor_shape.position = Vector2(_length_pixels * 0.5, 0.0)
		sensor_shape.shape = sensor_rectangle


func _draw() -> void:
	if not _draw_builtin_visual:
		return
	var half_width := _width_pixels * 0.5
	draw_rect(
		Rect2(0.0, -half_width, _length_pixels, _width_pixels),
		outline_color
	)
	draw_circle(Vector2.ZERO, half_width, outline_color)
	draw_circle(Vector2(_length_pixels, 0.0), half_width, outline_color)
	var inset := maxf(2.0, _width_pixels * 0.12)
	draw_rect(
		Rect2(
			inset * 0.5,
			-half_width + inset,
			maxf(_length_pixels - inset, 1.0),
			maxf(_width_pixels - inset * 2.0, 1.0)
		),
		fill_color
	)
	draw_circle(Vector2.ZERO, maxf(half_width - inset, 1.0), fill_color)
	draw_circle(
		Vector2(_length_pixels, 0.0),
		maxf(half_width - inset, 1.0),
		fill_color
	)


func _get_swing_sign() -> float:
	return _swing_sign


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
