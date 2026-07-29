extends SceneTree

const DEFAULT_CONFIG_PATH := "res://pinball/scoring/default_score_config.tres"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var config := ResourceLoader.load(
		DEFAULT_CONFIG_PATH,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as ScoreConfig
	if config == null:
		failures.append("기본 스코어 설정을 불러오지 못했습니다.")
		_finish(failures)
		return
	_expect_default_config(config, failures)
	_expect_combo_boundaries_rounding_and_target(config, failures)
	_expect_multiplier_cap(config, failures)
	_expect_invalid_inputs(config, failures)
	_finish(failures)


func _expect_default_config(config: ScoreConfig, failures: PackedStringArray) -> void:
	_expect(config.get_validation_errors().is_empty(), "기본 스코어 설정이 유효하지 않습니다.", failures)
	_expect(is_equal_approx(config.combo_window_seconds, 2.0), "기본 콤보 시간이 2초가 아닙니다.", failures)
	_expect(is_equal_approx(config.multiplier_step, 0.5), "기본 타격당 배수 증가량이 0.5가 아닙니다.", failures)
	_expect(is_equal_approx(config.maximum_multiplier, 5.0), "기본 최대 배수가 5배가 아닙니다.", failures)


func _expect_combo_boundaries_rounding_and_target(
	config: ScoreConfig,
	failures: PackedStringArray
) -> void:
	var tracker := ScoreTracker.new()
	_expect(tracker.configure(config, 700).is_empty(), "유효한 스코어 추적 설정이 거부됐습니다.", failures)

	var first := tracker.register_bumper_hit(_make_hit(&"hit_1", 101), 0.0)
	_expect_award(first, 1, 1.0, 101, 101, false, "첫 타격", failures)

	var before_boundary := tracker.register_bumper_hit(_make_hit(&"hit_2", 101), 1.5)
	_expect_award(before_boundary, 2, 1.5, 152, 253, false, "콤보 시간 직전", failures)

	var duplicate := tracker.register_bumper_hit(_make_hit(&"hit_2", 101), 2.5)
	_expect(not duplicate.applied, "같은 타격 ID가 두 번 반영됐습니다.", failures)
	_expect(tracker.current_score == 253 and tracker.combo_count == 2, "중복 타격이 공개 스코어·콤보 상태를 바꿨습니다.", failures)

	var exact_boundary := tracker.register_bumper_hit(_make_hit(&"hit_3", 101), 3.5)
	_expect_award(exact_boundary, 3, 2.0, 202, 455, false, "콤보 시간 경계", failures)

	var after_boundary := tracker.register_bumper_hit(_make_hit(&"hit_4", 101), 5.5001)
	_expect_award(after_boundary, 1, 1.0, 101, 556, false, "콤보 시간 직후", failures)

	var reached := tracker.register_bumper_hit(_make_hit(&"hit_5", 100), 7.0)
	_expect_award(reached, 2, 1.5, 150, 706, true, "목표 최초 교차", failures)
	_expect(tracker.target_reached, "목표 스코어 도달 공개 상태가 켜지지 않았습니다.", failures)

	var after_reached := tracker.register_bumper_hit(_make_hit(&"hit_6", 100), 8.0)
	_expect_award(after_reached, 3, 2.0, 200, 906, false, "목표 도달 뒤 추가 점수", failures)
	_expect(not tracker.expire_combo_if_needed(10.0), "정확한 콤보 시간 경계에서 콤보가 먼저 종료됐습니다.", failures)
	_expect(tracker.expire_combo_if_needed(10.0001), "콤보 시간 직후 콤보가 종료되지 않았습니다.", failures)
	_expect(tracker.combo_count == 0 and is_equal_approx(tracker.current_multiplier, 1.0), "콤보 종료 뒤 HUD용 공개 상태가 초기화되지 않았습니다.", failures)


func _expect_multiplier_cap(config: ScoreConfig, failures: PackedStringArray) -> void:
	var capped_config := config.duplicate(true) as ScoreConfig
	capped_config.maximum_multiplier = 2.0
	var tracker := ScoreTracker.new()
	_expect(tracker.configure(capped_config, 10000).is_empty(), "최대 배수 복제 설정이 거부됐습니다.", failures)
	for hit_index in 4:
		var result := tracker.register_bumper_hit(
			_make_hit(StringName("cap_%d" % hit_index), 100),
			float(hit_index) * 0.25
		)
		_expect(result.applied, "최대 배수 검사 타격이 적용되지 않았습니다: %d" % hit_index, failures)
	_expect(is_equal_approx(tracker.current_multiplier, 2.0), "콤보 배수가 설정된 2배 상한과 다릅니다.", failures)
	_expect(tracker.current_score == 650, "최대 배수 누적 계산이 예상값 650과 다릅니다: %d" % tracker.current_score, failures)


func _expect_invalid_inputs(config: ScoreConfig, failures: PackedStringArray) -> void:
	var tracker := ScoreTracker.new()
	_expect(not tracker.configure(null, 100).is_empty(), "설정 없는 스코어 추적을 허용했습니다.", failures)
	_expect(not tracker.configure(config, 0).is_empty(), "0 목표 스코어를 허용했습니다.", failures)

	var invalid_window := config.duplicate(true) as ScoreConfig
	invalid_window.combo_window_seconds = 0.0
	_expect(not tracker.configure(invalid_window, 100).is_empty(), "0초 콤보 시간을 허용했습니다.", failures)
	_expect(not tracker.register_bumper_hit(_make_hit(&"after_invalid", 100), 0.0).applied, "잘못된 재설정 뒤 이전 유효 설정이 남았습니다.", failures)
	var invalid_step := config.duplicate(true) as ScoreConfig
	invalid_step.multiplier_step = -0.1
	_expect(not tracker.configure(invalid_step, 100).is_empty(), "음수 배수 증가량을 허용했습니다.", failures)
	var invalid_maximum := config.duplicate(true) as ScoreConfig
	invalid_maximum.maximum_multiplier = 0.9
	_expect(not tracker.configure(invalid_maximum, 100).is_empty(), "1 미만 최대 배수를 허용했습니다.", failures)

	_expect(tracker.configure(config, 1000).is_empty(), "유효 설정 복구에 실패했습니다.", failures)
	var zero_score_hit := _make_hit(&"zero_score", 0)
	var zero_result := tracker.register_bumper_hit(zero_score_hit, 0.0)
	_expect(not zero_result.applied, "기본 점수 0 타격을 스코어에 반영했습니다.", failures)
	_expect(tracker.current_score == 0 and tracker.combo_count == 0, "기본 점수 0 타격이 상태를 바꿨습니다.", failures)
	var invalid_time := tracker.register_bumper_hit(_make_hit(&"bad_time", 100), NAN)
	_expect(not invalid_time.applied, "비유한 타격 시각을 허용했습니다.", failures)


func _make_hit(hit_id: StringName, base_score: int) -> BumperHitResult:
	var hit := BumperHitResult.new()
	hit.is_applied = true
	hit.hit_id = hit_id
	hit.contact_id = StringName("contact_%s" % hit_id)
	hit.shot_id = &"shot_score_smoke"
	hit.ball_id = &"standard_ball"
	hit.point_id = &"bumper_score"
	hit.content_id = &"bumper_normal"
	hit.bumper_type = BumperDefinition.BUMPER_TYPE_NORMAL
	hit.effect_type = BumperHitResult.EFFECT_NORMAL_REFLECT
	hit.contact_time_fraction = 0.0
	hit.contact_board_position = Vector2.ZERO
	hit.contact_board_normal = Vector2.UP
	hit.incoming_board_velocity = Vector2(0.0, 1.0)
	hit.reflected_board_velocity = Vector2(0.0, -1.0)
	hit.collision_strength_board_per_second = 1.0
	hit.base_score_value = base_score
	hit.durability_before = 3
	hit.durability_after = 2
	hit.output_board_velocity = Vector2(0.0, -1.0)
	return hit


func _expect_award(
	result: ScoreAwardResult,
	expected_combo: int,
	expected_multiplier: float,
	expected_added: int,
	expected_total: int,
	expected_target_now: bool,
	label: String,
	failures: PackedStringArray
) -> void:
	if result == null:
		failures.append("%s 결과가 없습니다." % label)
		return
	_expect(result.applied, "%s 결과가 적용되지 않았습니다: %s" % [label, result.ignored_reason], failures)
	_expect(result.get_validation_errors().is_empty(), "%s 결과 검증이 실패했습니다: %s" % [label, result.get_validation_errors()], failures)
	_expect(result.combo_count == expected_combo, "%s 콤보 수가 다릅니다: %d" % [label, result.combo_count], failures)
	_expect(is_equal_approx(result.multiplier, expected_multiplier), "%s 배수가 다릅니다: %s" % [label, result.multiplier], failures)
	_expect(result.score_added == expected_added, "%s 증가량이 다릅니다: %d" % [label, result.score_added], failures)
	_expect(result.total_score == expected_total, "%s 누적 스코어가 다릅니다: %d" % [label, result.total_score], failures)
	_expect(result.target_reached_now == expected_target_now, "%s 목표 최초 도달 여부가 다릅니다." % label, failures)


func _expect(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("SCORE_COMBO_SMOKE: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("SCORE_COMBO_SMOKE: %s" % failure)
	quit(1)
