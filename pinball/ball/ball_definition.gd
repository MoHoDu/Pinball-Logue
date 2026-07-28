@tool
class_name BallDefinition
extends Resource

@export_category("공 원형")
@export var ball_id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var presentation_id: StringName = &""
@export var physics_profile: BallPhysicsProfile


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if ball_id == &"":
		errors.append("공 식별자는 비어 있을 수 없습니다.")
	if display_name.strip_edges().is_empty():
		errors.append("공 표시 이름은 비어 있을 수 없습니다.")
	if presentation_id == &"":
		errors.append("공 디자인 연결 키는 비어 있을 수 없습니다.")
	if physics_profile == null:
		errors.append("공 물리 설정이 연결되어 있지 않습니다.")
	else:
		errors.append_array(physics_profile.get_validation_errors())
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()
