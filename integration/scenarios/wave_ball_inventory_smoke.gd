extends SceneTree

const LOADOUT_PATH := "res://stages/waves/default_mockup_ball_loadout.tres"

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var loadout := load(LOADOUT_PATH) as WaveBallLoadoutConfig
	var inventory := WaveBallInventory.new()
	_expect(inventory.initialize(loadout).is_empty(), "기본 공 목록을 준비하지 못했습니다.")
	_expect(inventory.get_total_count() == 3, "기본 공 목록은 세 슬롯이어야 합니다.")
	_expect(inventory.selected_slot_id == &"ball_slot_1", "첫 공이 기본 선택되지 않았습니다.")
	_expect(inventory.select_number(3).is_empty(), "숫자 3으로 세 번째 공을 선택하지 못했습니다.")
	_expect(inventory.selected_slot_id == &"ball_slot_3", "세 번째 공 선택이 상태에 반영되지 않았습니다.")
	_expect(inventory.cycle_selection(1).is_empty(), "오른쪽 순환 선택을 처리하지 못했습니다.")
	_expect(inventory.selected_slot_id == &"ball_slot_1", "공 선택 순환이 처음 슬롯으로 돌아오지 않았습니다.")
	_expect(inventory.consume_selected().is_empty(), "선택 공을 소모하지 못했습니다.")
	_expect(inventory.get_remaining_count() == 2, "공 하나 낙하 뒤 남은 공이 두 개가 아닙니다.")
	_expect(not inventory.select_number(1).is_empty(), "이미 소모한 공을 다시 선택했습니다.")
	_expect(inventory.selected_slot_id == &"ball_slot_2", "소모 뒤 다음 남은 공이 자동 선택되지 않았습니다.")
	_expect(inventory.consume_selected().is_empty(), "두 번째 공을 소모하지 못했습니다.")
	_expect(inventory.consume_selected().is_empty(), "마지막 공을 소모하지 못했습니다.")
	_expect(inventory.get_remaining_count() == 0, "세 공 낙하 뒤 남은 공이 없어야 합니다.")
	_expect(inventory.selected_slot_id == &"", "마지막 공 소모 뒤 선택이 비워지지 않았습니다.")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("WAVE_BALL_INVENTORY_SMOKE: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("WAVE_BALL_INVENTORY_SMOKE: %s" % failure)
	quit(1)
