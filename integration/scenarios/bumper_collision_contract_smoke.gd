extends SceneTree

const DEFINITION_PATHS := {
	BumperDefinition.BUMPER_TYPE_NORMAL: "res://pinball/objects/normal_bumper_definition.tres",
	BumperDefinition.BUMPER_TYPE_BOUNCE: "res://pinball/objects/bounce_bumper_definition.tres",
	BumperDefinition.BUMPER_TYPE_TRACK: "res://pinball/objects/track_bumper_definition.tres",
	BumperDefinition.BUMPER_TYPE_SHOT: "res://pinball/objects/shot_bumper_definition.tres",
}

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := _load_definitions()
	_expect(definitions.size() == 4, "범퍼 원형 네 종류를 모두 불러오지 못했습니다.")
	_expect_type_effects(definitions)
	_expect_contact_lock_and_rehit(definitions.get(BumperDefinition.BUMPER_TYPE_NORMAL))
	_expect_destroy_and_safe_recovery(definitions.get(BumperDefinition.BUMPER_TYPE_NORMAL))
	_expect_deterministic_order()
	_expect_deterministic_shot_error(definitions.get(BumperDefinition.BUMPER_TYPE_SHOT))
	_finish()


func _load_definitions() -> Dictionary:
	var definitions: Dictionary = {}
	for bumper_type in DEFINITION_PATHS:
		var definition := ResourceLoader.load(
			DEFINITION_PATHS[bumper_type],
			"Resource",
			ResourceLoader.CACHE_MODE_IGNORE
		) as BumperDefinition
		_expect(definition != null, "범퍼 원형을 불러오지 못했습니다: %s" % DEFINITION_PATHS[bumper_type])
		if definition == null:
			continue
		_expect(definition.get_validation_errors().is_empty(), "범퍼 원형 설정이 유효하지 않습니다: %s" % definition.get_validation_errors())
		_expect(definition.get_bumper_type_id() == bumper_type, "범퍼 원형의 종류가 파일 역할과 다릅니다: %s" % bumper_type)
		definitions[bumper_type] = definition
	return definitions


func _expect_type_effects(definitions: Dictionary) -> void:
	for bumper_type in definitions:
		var definition := definitions[bumper_type] as BumperDefinition
		var state := BumperRuntimeState.new()
		_expect(state.configure(&"bumper_test", definition).is_empty(), "범퍼 런타임 상태를 만들지 못했습니다: %s" % bumper_type)
		var request := _make_request(definition, &"contact_type")
		if bumper_type == BumperDefinition.BUMPER_TYPE_TRACK:
			request.track_path_board_positions = PackedVector2Array([
				Vector2(0.1, 0.0),
				Vector2(0.2, 0.1),
			])
		elif bumper_type == BumperDefinition.BUMPER_TYPE_SHOT:
			request.shot_target_board_position = Vector2(0.3, 0.0)
		var result := state.try_apply_hit(request)
		_expect(result.is_applied, "범퍼 종류별 타격이 적용되지 않았습니다: %s / %s" % [bumper_type, result.ignored_reason])
		_expect(result.is_valid(), "범퍼 종류별 타격 결과가 유효하지 않습니다: %s / %s" % [bumper_type, result.get_validation_errors()])
		_expect(result.bumper_type == bumper_type, "타격 결과의 범퍼 종류가 바뀌었습니다: %s" % bumper_type)
		_expect(result.output_board_velocity.length() <= request.ball_max_speed_board_per_second + 0.0001, "범퍼 반응이 공 최대 속도를 넘었습니다: %s" % bumper_type)
		match bumper_type:
			BumperDefinition.BUMPER_TYPE_NORMAL:
				_expect(result.effect_type == BumperHitResult.EFFECT_NORMAL_REFLECT, "일반 범퍼가 기본 반사 결과를 만들지 않았습니다.")
			BumperDefinition.BUMPER_TYPE_BOUNCE:
				_expect(result.effect_type == BumperHitResult.EFFECT_BOUNCE, "반동 범퍼 결과가 아닙니다.")
				_expect(result.output_board_velocity.length() > request.reflected_board_velocity.length(), "반동 범퍼가 기본 반사보다 빠르지 않습니다.")
			BumperDefinition.BUMPER_TYPE_TRACK:
				_expect(result.effect_type == BumperHitResult.EFFECT_TRACK, "경로 범퍼 결과가 아닙니다.")
				_expect(result.track_path_board_positions == request.track_path_board_positions, "경로 범퍼가 지정된 경로 전체를 전달하지 않았습니다.")
			BumperDefinition.BUMPER_TYPE_SHOT:
				_expect(result.effect_type == BumperHitResult.EFFECT_SHOT, "발사 범퍼 결과가 아닙니다.")
				_expect(result.output_board_velocity.normalized().dot(Vector2.RIGHT) > 0.999, "기본 0도 발사 범퍼가 목표를 정확히 향하지 않습니다.")


func _expect_contact_lock_and_rehit(source: BumperDefinition) -> void:
	if source == null:
		return
	var definition := source.duplicate(true) as BumperDefinition
	definition.max_durability = 3
	var state := BumperRuntimeState.new()
	_expect(state.configure(&"bumper_lock", definition).is_empty(), "접촉 잠금 시험 범퍼를 만들지 못했습니다.")
	var first := _make_request(definition, &"same_contact")
	first.point_id = &"bumper_lock"
	var first_result := state.try_apply_hit(first)
	var duplicate_result := state.try_apply_hit(first)
	_expect(first_result.is_applied, "첫 접촉 타격이 적용되지 않았습니다.")
	_expect(not duplicate_result.is_applied, "지속 접촉이 두 번째 타격을 만들었습니다.")
	_expect(state.current_durability == 2, "지속 접촉에서 내구도가 한 번보다 많이 감소했습니다.")
	_expect(state.end_contact(first.contact_id), "실제 분리로 접촉 잠금을 해제하지 못했습니다.")
	var second := _make_request(definition, &"same_contact")
	second.point_id = &"bumper_lock"
	second.hit_id = &"hit_after_separation"
	var second_result := state.try_apply_hit(second)
	_expect(second_result.is_applied, "분리 후 재접촉이 새 타격을 만들지 않았습니다.")
	_expect(state.current_durability == 1, "분리 후 두 번째 타격의 내구도 결과가 다릅니다.")


func _expect_destroy_and_safe_recovery(source: BumperDefinition) -> void:
	if source == null:
		return
	var definition := source.duplicate(true) as BumperDefinition
	definition.max_durability = 1
	definition.recovery_enabled = true
	definition.recovery_seconds = 0.1
	definition.recovery_warning_seconds = 0.05
	var state := BumperRuntimeState.new()
	_expect(state.configure(&"bumper_recovery", definition).is_empty(), "복구 시험 범퍼를 만들지 못했습니다.")
	var request := _make_request(definition, &"destroy_contact")
	request.point_id = &"bumper_recovery"
	var result := state.try_apply_hit(request)
	_expect(result.destroyed and not state.is_collision_active(), "내구도 0에서 범퍼가 즉시 비활성화되지 않았습니다.")
	state.advance_recovery(0.1, false)
	_expect(state.state == BumperRuntimeState.STATE_AWAITING_SAFE_RECOVERY, "복구 시간이 끝난 뒤 안전 확인 상태가 아닙니다.")
	state.advance_recovery(0.0, true)
	_expect(state.is_recovery_warning_active(), "안전 확인 뒤 복구 예고를 시작하지 않았습니다.")
	state.advance_recovery(0.03, false)
	_expect(state.state == BumperRuntimeState.STATE_AWAITING_SAFE_RECOVERY, "공이 접근하는데 복구 예고를 계속했습니다.")
	state.advance_recovery(0.0, true)
	state.advance_recovery(0.05, true)
	_expect(state.is_collision_active(), "안전한 예고 완료 뒤 범퍼가 복구되지 않았습니다.")
	_expect(state.current_durability == definition.max_durability, "복구된 범퍼의 내구도가 최대값이 아닙니다.")
	state.current_durability = 0
	state.reset_for_new_shot()
	_expect(state.is_collision_active() and state.current_durability == definition.max_durability, "새 발사 준비에서 범퍼 상태가 완전히 초기화되지 않았습니다.")


func _expect_deterministic_order() -> void:
	var first := BumperHitRequest.new()
	first.point_id = &"bumper_b"
	first.contact_time_fraction = 0.25
	var second := BumperHitRequest.new()
	second.point_id = &"bumper_a"
	second.contact_time_fraction = 0.25
	_expect(BumperHitRequest.sort_before(second, first), "동일 시각 후보가 배치 지점 ID 순으로 정렬되지 않습니다.")
	second.contact_time_fraction = 0.5
	_expect(BumperHitRequest.sort_before(first, second), "빠른 최초 접촉 시각이 우선되지 않습니다.")


func _expect_deterministic_shot_error(source: BumperDefinition) -> void:
	if source == null:
		return
	var definition := source.duplicate(true) as BumperDefinition
	definition.shot_direction_error_degrees = 12.0
	var expected_error := INF
	var expected_velocity := Vector2(INF, INF)
	for iteration in range(10):
		var state := BumperRuntimeState.new()
		_expect(state.configure(&"bumper_shot_repeat", definition).is_empty(), "결정성 시험 발사 범퍼를 만들지 못했습니다.")
		var request := _make_request(definition, &"same_shot_contact")
		request.point_id = &"bumper_shot_repeat"
		request.hit_id = &"hit_nonzero_direction_error"
		request.shot_target_board_position = Vector2(0.3, 0.2)
		var result := state.try_apply_hit(request)
		_expect(result.is_applied, "방향 오차 결정성 시험 타격이 적용되지 않았습니다: %d" % iteration)
		_expect(absf(result.shot_direction_error_degrees) <= 12.0, "발사 범퍼 방향 오차가 설정 범위를 넘었습니다.")
		if iteration == 0:
			expected_error = result.shot_direction_error_degrees
			expected_velocity = result.output_board_velocity
			_expect(not is_zero_approx(expected_error), "0도가 아닌 방향 오차 설정이 실제 오차 표본을 만들지 못했습니다.")
		else:
			_expect(is_equal_approx(result.shot_direction_error_degrees, expected_error), "같은 타격 ID의 방향 오차가 반복 실행에서 달라졌습니다.")
			_expect(result.output_board_velocity.is_equal_approx(expected_velocity), "같은 타격 ID의 발사 속도가 반복 실행에서 달라졌습니다.")


func _make_request(definition: BumperDefinition, contact_id: StringName) -> BumperHitRequest:
	var request := BumperHitRequest.new()
	request.hit_id = StringName("hit_%s" % contact_id)
	request.contact_id = contact_id
	request.shot_id = &"shot_001"
	request.ball_id = &"standard_ball"
	request.point_id = &"bumper_test"
	request.content_id = definition.content_id
	request.contact_time_fraction = 0.25
	request.contact_board_position = Vector2.ZERO
	request.contact_board_normal = Vector2.LEFT
	request.incoming_board_velocity = Vector2(2.0, 0.0)
	request.reflected_board_velocity = Vector2(-2.0, 0.0)
	request.ball_max_speed_board_per_second = 3.0
	return request


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BUMPER_COLLISION_CONTRACT_SMOKE: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("BUMPER_COLLISION_CONTRACT_SMOKE: %s" % failure)
	quit(1)
