class_name AppRoot
extends Node

@export_node_path("ScreenNavigator") var navigator_path: NodePath

var _initialized := false


func _ready() -> void:
	if _initialized:
		return

	var navigator := get_navigator()
	if navigator == null:
		push_error("앱 내비게이터를 찾을 수 없습니다: %s" % navigator_path)
		return

	_initialized = navigator.initialize()
	if not _initialized:
		push_error("앱 초기화에 실패했습니다.")


func get_navigator() -> ScreenNavigator:
	return get_node_or_null(navigator_path) as ScreenNavigator
