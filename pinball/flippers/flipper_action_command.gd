class_name FlipperActionCommand
extends RefCounted

const MIN_ANCHOR_COUNT := 1
const MAX_ANCHOR_COUNT := 2

var action_id: StringName = &""
var shot_id: StringName = &""
var control_direction_id: StringName = &""
var anchor_ids := PackedStringArray()


static func create(
	requested_action_id: StringName,
	requested_shot_id: StringName,
	requested_control_direction_id: StringName,
	requested_anchor_ids: PackedStringArray
) -> FlipperActionCommand:
	var command := FlipperActionCommand.new()
	command.action_id = requested_action_id
	command.shot_id = requested_shot_id
	command.control_direction_id = requested_control_direction_id
	command.anchor_ids = requested_anchor_ids.duplicate()
	return command


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if action_id == &"":
		errors.append("플리퍼 작동 식별자가 비어 있습니다.")
	if shot_id == &"":
		errors.append("플리퍼 작동과 연결할 발사 식별자가 비어 있습니다.")
	if control_direction_id == &"":
		errors.append("플리퍼를 선택한 방향키가 비어 있습니다.")
	if anchor_ids.size() < MIN_ANCHOR_COUNT or anchor_ids.size() > MAX_ANCHOR_COUNT:
		errors.append("플리퍼 조작 대상은 왼쪽, 오른쪽 또는 좌우 쌍이어야 합니다.")
	var unique_anchor_ids := {}
	for anchor_id in anchor_ids:
		if StringName(anchor_id) == &"":
			errors.append("플리퍼 배치 지점 식별자는 비어 있을 수 없습니다.")
		elif unique_anchor_ids.has(anchor_id):
			errors.append("같은 플리퍼 배치 지점을 한 작동에 두 번 넣을 수 없습니다: %s" % anchor_id)
		else:
			unique_anchor_ids[anchor_id] = true
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func is_pair() -> bool:
	return anchor_ids.size() == MAX_ANCHOR_COUNT
