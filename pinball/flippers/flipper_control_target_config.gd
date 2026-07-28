@tool
class_name FlipperControlTargetConfig
extends Resource

const MODE_LEFT_ONLY := &"left_only"
const MODE_RIGHT_ONLY := &"right_only"
const MODE_PAIR := &"pair"
const MODE_INDEX_LEFT_ONLY := 0
const MODE_INDEX_RIGHT_ONLY := 1
const MODE_INDEX_PAIR := 2
const SUPPORTED_MODES: Array[StringName] = [
	MODE_LEFT_ONLY,
	MODE_RIGHT_ONLY,
	MODE_PAIR,
]

@export_enum("왼쪽만", "오른쪽만", "좌우 쌍") var mode := MODE_INDEX_PAIR
@export var left_point_id: StringName = &""
@export var right_point_id: StringName = &""


func get_mode_id() -> StringName:
	match mode:
		MODE_INDEX_LEFT_ONLY:
			return MODE_LEFT_ONLY
		MODE_INDEX_RIGHT_ONLY:
			return MODE_RIGHT_ONLY
		MODE_INDEX_PAIR:
			return MODE_PAIR
	return &""


func set_mode_id(mode_id: StringName) -> void:
	match mode_id:
		MODE_LEFT_ONLY:
			mode = MODE_INDEX_LEFT_ONLY
		MODE_RIGHT_ONLY:
			mode = MODE_INDEX_RIGHT_ONLY
		MODE_PAIR:
			mode = MODE_INDEX_PAIR


func get_point_ids() -> Array[StringName]:
	match get_mode_id():
		MODE_LEFT_ONLY:
			return [left_point_id] if left_point_id != &"" else []
		MODE_RIGHT_ONLY:
			return [right_point_id] if right_point_id != &"" else []
		MODE_PAIR:
			var point_ids: Array[StringName] = []
			if left_point_id != &"":
				point_ids.append(left_point_id)
			if right_point_id != &"":
				point_ids.append(right_point_id)
			return point_ids
		_:
			return []


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not SUPPORTED_MODES.has(get_mode_id()):
		errors.append("지원하지 않는 플리퍼 조작 대상 방식입니다: %s" % mode)
		return errors

	match get_mode_id():
		MODE_LEFT_ONLY:
			if left_point_id == &"":
				errors.append("왼쪽만 조작하려면 왼쪽 플리퍼 지점을 선택해야 합니다.")
			if right_point_id != &"":
				errors.append("왼쪽만 조작하는 대상에는 오른쪽 플리퍼 지점을 넣을 수 없습니다.")
		MODE_RIGHT_ONLY:
			if right_point_id == &"":
				errors.append("오른쪽만 조작하려면 오른쪽 플리퍼 지점을 선택해야 합니다.")
			if left_point_id != &"":
				errors.append("오른쪽만 조작하는 대상에는 왼쪽 플리퍼 지점을 넣을 수 없습니다.")
		MODE_PAIR:
			if left_point_id == &"" or right_point_id == &"":
				errors.append("좌우 쌍은 왼쪽과 오른쪽 플리퍼 지점을 모두 선택해야 합니다.")
			elif left_point_id == right_point_id:
				errors.append("좌우 쌍에는 서로 다른 플리퍼 지점 두 개가 필요합니다.")
	return errors
