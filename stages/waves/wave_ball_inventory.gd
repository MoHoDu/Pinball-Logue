class_name WaveBallInventory
extends RefCounted

var selected_slot_id: StringName = &""

var _loadout: WaveBallLoadoutConfig
var _consumed_slot_ids: Dictionary = {}


func initialize(loadout: WaveBallLoadoutConfig) -> String:
	if loadout == null:
		return "웨이브 공 목록이 없습니다."
	var errors := loadout.get_validation_errors()
	if not errors.is_empty():
		return errors[0]
	_loadout = loadout
	_consumed_slot_ids.clear()
	selected_slot_id = loadout.slots[0].slot_id
	return ""


func select_number(selection_number: int) -> String:
	if _loadout == null:
		return "웨이브 공 목록이 준비되지 않았습니다."
	var slot := _loadout.get_slot_at(selection_number)
	if slot == null:
		return "%d번 공 슬롯은 존재하지 않습니다." % selection_number
	return select_slot(slot.slot_id)


func select_slot(slot_id: StringName) -> String:
	if _loadout == null:
		return "웨이브 공 목록이 준비되지 않았습니다."
	if _loadout.get_slot(slot_id) == null:
		return "선택한 공 슬롯을 찾을 수 없습니다: %s" % slot_id
	if is_consumed(slot_id):
		return "이미 낙하해 소모한 공입니다: %s" % slot_id
	selected_slot_id = slot_id
	return ""


func cycle_selection(direction: int) -> String:
	var remaining := get_remaining_slots()
	if remaining.is_empty():
		return "남아 있는 공이 없습니다."
	var current_index := -1
	for slot_index in remaining.size():
		if remaining[slot_index].slot_id == selected_slot_id:
			current_index = slot_index
			break
	var step := -1 if direction < 0 else 1
	if current_index < 0:
		current_index = 0
	else:
		current_index = posmod(current_index + step, remaining.size())
	selected_slot_id = remaining[current_index].slot_id
	return ""


func consume_selected() -> String:
	if selected_slot_id == &"":
		return "소모할 공을 먼저 선택해야 합니다."
	return consume_slot(selected_slot_id)


func consume_slot(slot_id: StringName) -> String:
	if _loadout == null or _loadout.get_slot(slot_id) == null:
		return "소모할 공 슬롯을 찾을 수 없습니다: %s" % slot_id
	if is_consumed(slot_id):
		return "이미 소모한 공 슬롯입니다: %s" % slot_id
	_consumed_slot_ids[slot_id] = true
	if selected_slot_id == slot_id:
		var remaining := get_remaining_slots()
		selected_slot_id = &"" if remaining.is_empty() else remaining[0].slot_id
	return ""


func is_consumed(slot_id: StringName) -> bool:
	return _consumed_slot_ids.has(slot_id)


func get_selected_slot() -> WaveBallSlotConfig:
	if _loadout == null or selected_slot_id == &"":
		return null
	return _loadout.get_slot(selected_slot_id)


func get_remaining_slots() -> Array[WaveBallSlotConfig]:
	var remaining: Array[WaveBallSlotConfig] = []
	if _loadout == null:
		return remaining
	for slot in _loadout.slots:
		if slot != null and not is_consumed(slot.slot_id):
			remaining.append(slot)
	return remaining


func get_total_count() -> int:
	return 0 if _loadout == null else _loadout.slots.size()


func get_remaining_count() -> int:
	return get_remaining_slots().size()
