@tool
class_name BumperDefinition
extends BoardPlaceableDefinition

const BUMPER_TYPE_NORMAL := &"normal"
const BUMPER_TYPE_BOUNCE := &"bounce"
const BUMPER_TYPE_TRACK := &"track"
const BUMPER_TYPE_SHOT := &"shot"

@export_category("범퍼")
@export_enum("normal", "bounce", "track", "shot") var bumper_type := "normal"


func _init() -> void:
	object_type = String(OBJECT_TYPE_BUMPER)


static func get_supported_bumper_types() -> Array[StringName]:
	return [
		BUMPER_TYPE_NORMAL,
		BUMPER_TYPE_BOUNCE,
		BUMPER_TYPE_TRACK,
		BUMPER_TYPE_SHOT,
	]


func get_bumper_type_id() -> StringName:
	return StringName(bumper_type)


func get_validation_errors() -> PackedStringArray:
	var errors := super.get_validation_errors()
	if get_object_type_id() != OBJECT_TYPE_BUMPER:
		errors.append("범퍼 원형의 오브젝트 종류는 범퍼여야 합니다: %s" % display_name)
	if not get_supported_bumper_types().has(get_bumper_type_id()):
		errors.append("지원하지 않는 범퍼 종류입니다: %s" % bumper_type)
	return errors
