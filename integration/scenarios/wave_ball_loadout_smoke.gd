extends SceneTree

const DEFAULT_LOADOUT_PATH := "res://stages/waves/default_mockup_ball_loadout.tres"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var loadout := ResourceLoader.load(
		DEFAULT_LOADOUT_PATH,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as WaveBallLoadoutConfig
	if loadout == null:
		failures.append("기본 목업 공 목록을 불러오지 못했습니다.")
		_finish(failures)
		return

	_expect_default_three_slots(loadout, failures)
	_expect_valid_slot_boundaries(loadout, failures)
	_expect_invalid_loadouts(loadout, failures)
	_expect_dimension_independence(failures)
	_finish(failures)


func _expect_default_three_slots(loadout: WaveBallLoadoutConfig, failures: PackedStringArray) -> void:
	var errors := loadout.get_validation_errors()
	if not errors.is_empty():
		failures.append("기본 목업 공 목록이 유효하지 않습니다: %s" % errors)
	if loadout.slots.size() != 3:
		failures.append("기본 목업 공 목록은 3개 슬롯이어야 합니다.")
	var expected_slot_ids: Array[StringName] = [&"ball_slot_1", &"ball_slot_2", &"ball_slot_3"]
	if loadout.get_slot_ids() != expected_slot_ids:
		failures.append("기본 공 슬롯 이름이 예상과 다릅니다: %s" % loadout.get_slot_ids())
	for selection_number in range(1, 4):
		var slot := loadout.get_slot_at(selection_number)
		if slot == null:
			failures.append("숫자키 %d에 해당하는 공 슬롯이 없습니다." % selection_number)
			continue
		if slot.slot_id != expected_slot_ids[selection_number - 1]:
			failures.append("숫자키 %d가 잘못된 공 슬롯을 가리킵니다." % selection_number)
		if slot.get_ball_id() != &"standard_ball":
			failures.append("공 슬롯 '%s'가 표준 공 원형을 참조하지 않습니다." % slot.slot_id)
	if loadout.get_slot_at(0) != null or loadout.get_slot_at(4) != null:
		failures.append("1~3 밖의 숫자 선택이 공 슬롯을 반환했습니다.")


func _expect_valid_slot_boundaries(loadout: WaveBallLoadoutConfig, failures: PackedStringArray) -> void:
	for slot_count in range(1, 4):
		var candidate := loadout.duplicate(true) as WaveBallLoadoutConfig
		candidate.slots.resize(slot_count)
		if not candidate.get_validation_errors().is_empty():
			failures.append("공 %d개 목록이 거부됐습니다: %s" % [slot_count, candidate.get_validation_errors()])


func _expect_invalid_loadouts(loadout: WaveBallLoadoutConfig, failures: PackedStringArray) -> void:
	var empty := loadout.duplicate(true) as WaveBallLoadoutConfig
	empty.slots.clear()
	_expect_error(empty.get_validation_errors(), "1~3개", failures)

	var too_many := loadout.duplicate(true) as WaveBallLoadoutConfig
	var fourth_slot := too_many.slots[0].duplicate(true) as WaveBallSlotConfig
	fourth_slot.slot_id = &"ball_slot_4"
	too_many.slots.append(fourth_slot)
	_expect_error(too_many.get_validation_errors(), "1~3개", failures)

	var duplicate_id := loadout.duplicate(true) as WaveBallLoadoutConfig
	duplicate_id.slots[1].slot_id = duplicate_id.slots[0].slot_id
	_expect_error(duplicate_id.get_validation_errors(), "중복", failures)

	var null_slot := loadout.duplicate(true) as WaveBallLoadoutConfig
	null_slot.slots[1] = null
	_expect_error(null_slot.get_validation_errors(), "비어", failures)

	var missing_definition := loadout.duplicate(true) as WaveBallLoadoutConfig
	missing_definition.slots[0].ball_definition = null
	_expect_error(missing_definition.get_validation_errors(), "공 원형", failures)


func _expect_dimension_independence(failures: PackedStringArray) -> void:
	for path in [
		"res://stages/waves/wave_ball_slot_config.gd",
		"res://stages/waves/wave_ball_loadout_config.gd",
	]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			failures.append("공 목록 계약 파일을 읽지 못했습니다: %s" % path)
			continue
		var source := file.get_as_text()
		for forbidden in ["Node2D", "Node3D", "RigidBody2D", "RigidBody3D", "PackedScene", ".tscn"]:
			if forbidden in source:
				failures.append("공 목록 계약에 차원별 표현 참조가 있습니다: %s / %s" % [path, forbidden])


func _expect_error(errors: PackedStringArray, fragment: String, failures: PackedStringArray) -> void:
	for error in errors:
		if fragment in error:
			return
	failures.append("예상한 검증 오류를 찾지 못했습니다: %s / %s" % [fragment, errors])


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("WAVE_BALL_LOADOUT_SMOKE: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("WAVE_BALL_LOADOUT_SMOKE: %s" % failure)
	quit(1)
