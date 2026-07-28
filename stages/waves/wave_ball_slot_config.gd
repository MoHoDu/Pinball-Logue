@tool
class_name WaveBallSlotConfig
extends Resource

@export_category("웨이브 공 슬롯")
@export var slot_id: StringName = &""
@export var ball_definition: BallDefinition


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if slot_id == &"":
		errors.append("공 슬롯 이름은 비어 있을 수 없습니다.")
	if ball_definition == null:
		errors.append("공 슬롯에 공 원형이 연결되어 있지 않습니다: %s" % slot_id)
	else:
		for definition_error in ball_definition.get_validation_errors():
			errors.append("공 슬롯 '%s': %s" % [slot_id, definition_error])
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func get_ball_id() -> StringName:
	if ball_definition == null:
		return &""
	return ball_definition.ball_id
