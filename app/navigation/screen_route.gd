class_name ScreenRoute
extends Resource

@export var screen_id: StringName
@export var scene: PackedScene


func get_validation_error() -> String:
	if screen_id == &"":
		return "화면 식별자가 비어 있습니다."
	if scene == null:
		return "화면 '%s'의 PackedScene이 없습니다." % screen_id
	return ""
