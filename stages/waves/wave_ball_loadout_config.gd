@tool
class_name WaveBallLoadoutConfig
extends Resource

const MIN_SLOT_COUNT := 1
const MAX_SLOT_COUNT := 3

@export_category("웨이브 공 목록")
@export var slots: Array[WaveBallSlotConfig] = []


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if slots.size() < MIN_SLOT_COUNT or slots.size() > MAX_SLOT_COUNT:
		errors.append("웨이브에 가져갈 공은 1~3개여야 합니다. 현재 %d개입니다." % slots.size())

	var known_slot_ids: Dictionary = {}
	for slot_index in slots.size():
		var slot := slots[slot_index]
		if slot == null:
			errors.append("공 목록의 %d번 슬롯이 비어 있습니다." % (slot_index + 1))
			continue
		errors.append_array(slot.get_validation_errors())
		if slot.slot_id == &"":
			continue
		if known_slot_ids.has(slot.slot_id):
			errors.append("공 슬롯 이름이 중복됩니다: %s" % slot.slot_id)
		else:
			known_slot_ids[slot.slot_id] = true
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func get_slot(slot_id: StringName) -> WaveBallSlotConfig:
	for slot in slots:
		if slot != null and slot.slot_id == slot_id:
			return slot
	return null


func get_slot_at(selection_number: int) -> WaveBallSlotConfig:
	var slot_index := selection_number - 1
	if slot_index < 0 or slot_index >= slots.size():
		return null
	return slots[slot_index]


func get_slot_ids() -> Array[StringName]:
	var slot_ids: Array[StringName] = []
	for slot in slots:
		if slot != null:
			slot_ids.append(slot.slot_id)
	return slot_ids
