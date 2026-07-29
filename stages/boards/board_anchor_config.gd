@tool
class_name BoardAnchorConfig
extends Resource

const TYPE_LAUNCH := &"launch"
const TYPE_DRAIN := &"drain"
const TYPE_BUMPER := &"bumper"
const TYPE_FLIPPER := &"flipper"
const TYPE_RELIC_SLOT := &"relic_slot"
const TYPE_OBJECT := &"object"
const TYPE_TRACK_POINT := &"track_point"
const TYPE_SHOT_TARGET := &"shot_target"

@export var anchor_id: StringName = &""
@export_enum("launch", "drain", "bumper", "flipper", "relic_slot", "object", "track_point", "shot_target") var anchor_type := "bumper"
@export var board_position := Vector2.ZERO
@export_range(-180.0, 180.0, 0.5) var rotation_degrees := 0.0
@export_group("플리퍼 외곽선 배치")
@export var snap_to_boundary := false
@export_range(0, 1024, 1) var boundary_edge_index := 0
@export_range(0.0, 1.0, 0.001) var boundary_edge_offset := 0.5


static func get_supported_types() -> Array[StringName]:
	return [
		TYPE_LAUNCH,
		TYPE_DRAIN,
		TYPE_BUMPER,
		TYPE_FLIPPER,
		TYPE_RELIC_SLOT,
		TYPE_OBJECT,
		TYPE_TRACK_POINT,
		TYPE_SHOT_TARGET,
	]


func get_type_id() -> StringName:
	return StringName(anchor_type)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if anchor_id == &"":
		errors.append("배치 지점 이름은 비어 있을 수 없습니다.")
	if not get_supported_types().has(get_type_id()):
		errors.append("지원하지 않는 배치 지점 종류입니다: %s" % anchor_type)
	if not is_finite(board_position.x) or not is_finite(board_position.y):
		errors.append("배치 지점 위치는 유한한 값이어야 합니다: %s" % anchor_id)
	if not is_finite(rotation_degrees):
		errors.append("배치 지점 회전값은 유한한 값이어야 합니다: %s" % anchor_id)
	if snap_to_boundary and get_type_id() != TYPE_FLIPPER:
		errors.append("외곽선에 붙이는 배치 방식은 플리퍼 지점에만 사용할 수 있습니다: %s" % anchor_id)
	if not is_finite(boundary_edge_offset) or boundary_edge_offset < 0.0 or boundary_edge_offset > 1.0:
		errors.append("플리퍼의 외곽선 위치는 0~1 범위여야 합니다: %s" % anchor_id)
	return errors
