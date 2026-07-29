class_name BumperRuntimeState
extends RefCounted

const STATE_ACTIVE := &"active"
const STATE_DESTROYED_WAIT := &"destroyed_wait"
const STATE_AWAITING_SAFE_RECOVERY := &"awaiting_safe_recovery"
const STATE_RECOVERY_WARNING := &"recovery_warning"

var point_id: StringName = &""
var definition: BumperDefinition
var current_durability := 0
var state: StringName = STATE_ACTIVE
var recovery_elapsed_seconds := 0.0
var recovery_warning_elapsed_seconds := 0.0

var _contact_lock := BumperContactLock.new()


func configure(requested_point_id: StringName, requested_definition: BumperDefinition) -> String:
	if requested_point_id == &"":
		return "범퍼 상태의 배치 지점 식별자가 비어 있습니다."
	if requested_definition == null:
		return "범퍼 상태에 연결할 원형이 없습니다: %s" % requested_point_id
	var definition_errors := requested_definition.get_validation_errors()
	if not definition_errors.is_empty():
		return definition_errors[0]
	point_id = requested_point_id
	definition = requested_definition
	reset_for_new_shot()
	return ""


func try_apply_hit(request: BumperHitRequest) -> BumperHitResult:
	if definition == null:
		return BumperHitResult.ignored("범퍼 상태가 아직 설정되지 않았습니다.")
	if state != STATE_ACTIVE:
		return BumperHitResult.ignored("현재 범퍼는 타격 가능한 상태가 아닙니다: %s" % state)
	if request == null:
		return BumperHitResult.ignored("범퍼 타격 요청이 없습니다.")
	var request_errors := request.get_validation_errors()
	if not request_errors.is_empty():
		return BumperHitResult.ignored(request_errors[0])
	if request.point_id != point_id:
		return BumperHitResult.ignored("타격 요청의 배치 지점이 현재 범퍼와 다릅니다.")
	if request.content_id != definition.content_id:
		return BumperHitResult.ignored("타격 요청의 범퍼 원형이 현재 범퍼와 다릅니다.")
	if not _contact_lock.try_begin(request.contact_id):
		return BumperHitResult.ignored("지속 중인 같은 접촉은 다시 타격할 수 없습니다.")

	var result := _create_result(request)
	var effect_error := BumperEffectResolver.resolve(definition, request, result)
	if not effect_error.is_empty():
		_contact_lock.end(request.contact_id)
		return BumperHitResult.ignored(effect_error)

	if not definition.indestructible:
		current_durability = maxi(
			0,
			current_durability - definition.durability_damage_per_hit
		)
	result.durability_after = current_durability
	result.destroyed = not definition.indestructible and current_durability == 0
	result.is_applied = true
	if result.destroyed:
		state = STATE_DESTROYED_WAIT
		recovery_elapsed_seconds = 0.0
		recovery_warning_elapsed_seconds = 0.0
		_contact_lock.clear()
	return result


func end_contact(contact_id: StringName) -> bool:
	return _contact_lock.end(contact_id)


func has_contact(contact_id: StringName) -> bool:
	return _contact_lock.is_active(contact_id)


func advance_recovery(delta: float, is_safe_clear: bool) -> bool:
	if definition == null or state == STATE_ACTIVE or not definition.recovery_enabled:
		return false
	if not is_finite(delta) or delta < 0.0:
		return false
	match state:
		STATE_DESTROYED_WAIT:
			recovery_elapsed_seconds += delta
			if recovery_elapsed_seconds >= definition.recovery_seconds:
				state = STATE_AWAITING_SAFE_RECOVERY
		STATE_AWAITING_SAFE_RECOVERY:
			if is_safe_clear:
				state = STATE_RECOVERY_WARNING
				recovery_warning_elapsed_seconds = 0.0
		STATE_RECOVERY_WARNING:
			if not is_safe_clear:
				state = STATE_AWAITING_SAFE_RECOVERY
				recovery_warning_elapsed_seconds = 0.0
			else:
				recovery_warning_elapsed_seconds += delta
				if recovery_warning_elapsed_seconds >= definition.recovery_warning_seconds:
					_restore_active()
					return true
	return false


func reset_for_new_shot() -> void:
	state = STATE_ACTIVE
	current_durability = definition.max_durability if definition != null else 0
	recovery_elapsed_seconds = 0.0
	recovery_warning_elapsed_seconds = 0.0
	_contact_lock.clear()


func is_collision_active() -> bool:
	return state == STATE_ACTIVE


func is_recovery_warning_active() -> bool:
	return state == STATE_RECOVERY_WARNING


func _restore_active() -> void:
	state = STATE_ACTIVE
	current_durability = definition.max_durability
	recovery_elapsed_seconds = 0.0
	recovery_warning_elapsed_seconds = 0.0
	_contact_lock.clear()


func _create_result(request: BumperHitRequest) -> BumperHitResult:
	var result := BumperHitResult.new()
	result.hit_id = request.hit_id
	result.contact_id = request.contact_id
	result.shot_id = request.shot_id
	result.ball_id = request.ball_id
	result.point_id = request.point_id
	result.content_id = request.content_id
	result.bumper_type = definition.get_bumper_type_id()
	result.contact_time_fraction = request.contact_time_fraction
	result.contact_board_position = request.contact_board_position
	result.contact_board_normal = request.contact_board_normal.normalized()
	result.incoming_board_velocity = request.incoming_board_velocity
	result.reflected_board_velocity = request.reflected_board_velocity
	result.collision_strength_board_per_second = request.incoming_board_velocity.length()
	result.base_score_value = definition.base_score_value
	result.durability_before = current_durability
	result.durability_after = current_durability
	return result
