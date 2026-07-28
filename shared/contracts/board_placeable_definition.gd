@tool
class_name BoardPlaceableDefinition
extends Resource

const OBJECT_TYPE_BUMPER := &"bumper"
const OBJECT_TYPE_WALL := &"wall"
const OBJECT_TYPE_GENERAL := &"general"
const OBJECT_TYPE_FLIPPER := &"flipper"
const OBJECT_TYPE_RELIC_PREVIEW := &"relic_preview"

@export_category("오브젝트 원형")
@export var content_id: StringName = &""
@export var display_name := ""
@export_enum("bumper", "wall", "general", "flipper", "relic_preview") var object_type := "general"

@export_category("내구도")
@export var indestructible := false
@export_range(0, 1000000, 1) var max_durability := 1


static func get_supported_object_types() -> Array[StringName]:
	return [
		OBJECT_TYPE_BUMPER,
		OBJECT_TYPE_WALL,
		OBJECT_TYPE_GENERAL,
		OBJECT_TYPE_FLIPPER,
		OBJECT_TYPE_RELIC_PREVIEW,
	]


func get_object_type_id() -> StringName:
	return StringName(object_type)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if content_id == &"":
		errors.append("오브젝트 원형 ID가 비어 있습니다. 다른 웨이브에서도 바뀌지 않을 고유 ID를 입력하세요.")
	if display_name.strip_edges().is_empty():
		errors.append("오브젝트 원형의 표시 이름이 비어 있습니다. 제작 화면에서 알아볼 수 있는 이름을 입력하세요.")
	if not get_supported_object_types().has(get_object_type_id()):
		errors.append("지원하지 않는 오브젝트 종류입니다: %s" % object_type)
	if max_durability < 0:
		errors.append("최대 내구도는 0보다 작을 수 없습니다: %s" % display_name)
	elif not indestructible and max_durability <= 0:
		errors.append("파괴 가능한 오브젝트의 최대 내구도는 1 이상이어야 합니다: %s" % display_name)
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()
