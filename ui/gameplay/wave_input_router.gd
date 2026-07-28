class_name WaveInputRouter
extends Node

signal ball_slot_requested(slot_number: int)
signal ball_cycle_requested(direction: int)
signal ball_selection_confirm_requested
signal keyboard_aim_requested(angle_steps: int, strength_steps: int)
signal mouse_aim_requested(viewport_position: Vector2)
signal launch_requested
signal flipper_selection_requested(direction_id: StringName)
signal flipper_action_requested

enum Phase {
	BALL_SELECTION,
	AIMING,
	BALL_IN_PLAY,
	RESOLVING,
	COMPLETE,
}

const AIM_MODE_DIRECTION_KEYS: StringName = &"direction_keys"
const AIM_MODE_MOUSE: StringName = &"mouse"

const ACTION_BALL_SLOT_1: StringName = &"play_ball_slot_1"
const ACTION_BALL_SLOT_2: StringName = &"play_ball_slot_2"
const ACTION_BALL_SLOT_3: StringName = &"play_ball_slot_3"
const ACTION_DIRECTION_LEFT: StringName = &"play_direction_left"
const ACTION_DIRECTION_RIGHT: StringName = &"play_direction_right"
const ACTION_DIRECTION_UP: StringName = &"play_direction_up"
const ACTION_DIRECTION_DOWN: StringName = &"play_direction_down"
const ACTION_CONTEXT: StringName = &"play_context_action"

var phase: Phase = Phase.BALL_SELECTION
var configured_aim_mode: StringName = AIM_MODE_MOUSE
var active_aim_mode: StringName = AIM_MODE_MOUSE


func _ready() -> void:
	ensure_default_input_actions()


func configure_aim_mode(aim_mode: StringName) -> bool:
	if aim_mode != AIM_MODE_DIRECTION_KEYS and aim_mode != AIM_MODE_MOUSE:
		return false
	configured_aim_mode = aim_mode
	return true


func enter_ball_selection() -> void:
	phase = Phase.BALL_SELECTION


func enter_aiming() -> void:
	active_aim_mode = configured_aim_mode
	phase = Phase.AIMING


func enter_ball_in_play() -> void:
	phase = Phase.BALL_IN_PLAY


func enter_resolving() -> void:
	phase = Phase.RESOLVING


func enter_complete() -> void:
	phase = Phase.COMPLETE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if phase == Phase.AIMING and active_aim_mode == AIM_MODE_MOUSE:
			mouse_aim_requested.emit(event.position)
			_mark_input_handled()
		return
	if not event is InputEventKey or not event.pressed:
		return
	if event.echo and not _is_repeatable_direction_key_aim_event(event):
		return
	match phase:
		Phase.BALL_SELECTION:
			_handle_ball_selection(event)
		Phase.AIMING:
			_handle_aiming(event)
		Phase.BALL_IN_PLAY:
			_handle_ball_in_play(event)


func _handle_ball_selection(event: InputEventKey) -> void:
	if event.is_action_pressed(ACTION_BALL_SLOT_1):
		ball_slot_requested.emit(1)
		_mark_input_handled()
		return
	if event.is_action_pressed(ACTION_BALL_SLOT_2):
		ball_slot_requested.emit(2)
		_mark_input_handled()
		return
	if event.is_action_pressed(ACTION_BALL_SLOT_3):
		ball_slot_requested.emit(3)
		_mark_input_handled()
		return
	if event.is_action_pressed(ACTION_DIRECTION_LEFT):
		ball_cycle_requested.emit(-1)
		_mark_input_handled()
		return
	if event.is_action_pressed(ACTION_DIRECTION_RIGHT):
		ball_cycle_requested.emit(1)
		_mark_input_handled()
		return
	if event.is_action_pressed(ACTION_DIRECTION_UP):
		ball_cycle_requested.emit(-1)
		_mark_input_handled()
		return
	if event.is_action_pressed(ACTION_DIRECTION_DOWN):
		ball_cycle_requested.emit(1)
		_mark_input_handled()
		return
	if event.is_action_pressed(ACTION_CONTEXT):
		ball_selection_confirm_requested.emit()
		_mark_input_handled()


func _handle_aiming(event: InputEventKey) -> void:
	if event.is_action_pressed(ACTION_CONTEXT):
		launch_requested.emit()
		_mark_input_handled()
		return
	if active_aim_mode != AIM_MODE_DIRECTION_KEYS:
		return
	var direction_id := _get_direction_id(event, true)
	match direction_id:
		&"left":
			keyboard_aim_requested.emit(-1, 0)
		&"right":
			keyboard_aim_requested.emit(1, 0)
		&"up":
			keyboard_aim_requested.emit(0, 1)
		&"down":
			keyboard_aim_requested.emit(0, -1)
		_:
			return
	_mark_input_handled()


func _handle_ball_in_play(event: InputEventKey) -> void:
	if event.is_action_pressed(ACTION_CONTEXT):
		flipper_action_requested.emit()
		_mark_input_handled()
		return
	var direction_id := _get_direction_id(event)
	if direction_id != &"":
		flipper_selection_requested.emit(direction_id)
		_mark_input_handled()


func _is_repeatable_direction_key_aim_event(event: InputEventKey) -> bool:
	return (
		phase == Phase.AIMING
		and active_aim_mode == AIM_MODE_DIRECTION_KEYS
		and _get_direction_id(event, true) != &""
	)


func _get_direction_id(event: InputEventKey, allow_echo := false) -> StringName:
	if event.is_action_pressed(ACTION_DIRECTION_LEFT, allow_echo):
		return &"left"
	if event.is_action_pressed(ACTION_DIRECTION_RIGHT, allow_echo):
		return &"right"
	if event.is_action_pressed(ACTION_DIRECTION_UP, allow_echo):
		return &"up"
	if event.is_action_pressed(ACTION_DIRECTION_DOWN, allow_echo):
		return &"down"
	return &""


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


static func ensure_default_input_actions() -> void:
	_ensure_key_action(ACTION_BALL_SLOT_1, KEY_1)
	_ensure_key_action(ACTION_BALL_SLOT_2, KEY_2)
	_ensure_key_action(ACTION_BALL_SLOT_3, KEY_3)
	_ensure_key_action(ACTION_DIRECTION_LEFT, KEY_LEFT)
	_ensure_key_action(ACTION_DIRECTION_RIGHT, KEY_RIGHT)
	_ensure_key_action(ACTION_DIRECTION_UP, KEY_UP)
	_ensure_key_action(ACTION_DIRECTION_DOWN, KEY_DOWN)
	_ensure_key_action(ACTION_CONTEXT, KEY_SPACE)


static func _ensure_key_action(action_id: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	for existing_event in InputMap.action_get_events(action_id):
		if existing_event is InputEventKey and existing_event.keycode == keycode:
			return
	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	InputMap.action_add_event(action_id, key_event)
