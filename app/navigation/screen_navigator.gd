class_name ScreenNavigator
extends Node

signal transition_started(previous_screen_id: StringName, target_screen_id: StringName)
signal transition_completed(current_screen_id: StringName)
signal transition_rejected(target_screen_id: StringName, reason: String)
signal progression_action_requested(action_id: StringName)

@export var config: NavigationConfig
@export_node_path("Node") var screen_host_path: NodePath

var current_screen_id: StringName = &""
var current_screen: Node

var _initialized := false
var _transitioning := false
var _screen_host: Node


func initialize() -> bool:
	if _initialized:
		return true

	_screen_host = get_node_or_null(screen_host_path)
	if _screen_host == null:
		push_error("화면 호스트를 찾을 수 없습니다: %s" % screen_host_path)
		return false

	if config == null:
		push_error("NavigationConfig가 지정되지 않았습니다.")
		return false

	var validation_errors := config.get_validation_errors()
	if not validation_errors.is_empty():
		for validation_error in validation_errors:
			push_error(validation_error)
		return false

	_initialized = true
	return request_navigation(config.initial_screen_id)


func request_navigation(target_screen_id: StringName) -> bool:
	if not _initialized:
		return _reject(target_screen_id, "내비게이터가 초기화되지 않았습니다.")
	if _transitioning:
		return _reject(target_screen_id, "화면 전환이 이미 진행 중입니다.")
	if target_screen_id == current_screen_id:
		return _reject(target_screen_id, "이미 활성화된 화면입니다.")

	var target_scene := config.get_screen_scene(target_screen_id)
	if target_scene == null:
		return _reject(target_screen_id, "등록되지 않은 화면입니다.")

	_transitioning = true
	transition_started.emit(current_screen_id, target_screen_id)

	var next_screen := target_scene.instantiate()
	if next_screen == null:
		_transitioning = false
		return _reject(target_screen_id, "화면 인스턴스를 생성하지 못했습니다.")

	if current_screen != null:
		_screen_host.remove_child(current_screen)
		current_screen.queue_free()

	current_screen = next_screen
	current_screen_id = target_screen_id
	_screen_host.add_child(current_screen)
	_connect_screen_intents(current_screen)

	_transitioning = false
	transition_completed.emit(current_screen_id)
	return true


func get_active_screen_count() -> int:
	if _screen_host == null:
		return 0
	return _screen_host.get_child_count()


func _connect_screen_intents(screen: Node) -> void:
	if screen.has_signal(&"progression_requested"):
		screen.connect(
			&"progression_requested",
			Callable(self, "_on_progression_requested")
		)


func _on_progression_requested(action_id: StringName) -> void:
	progression_action_requested.emit(action_id)


func _reject(target_screen_id: StringName, reason: String) -> bool:
	transition_rejected.emit(target_screen_id, reason)
	return false
