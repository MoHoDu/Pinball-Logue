class_name NavigableScreen
extends Node

signal progression_requested(action_id: StringName)

@export var screen_id: StringName
@export var progression_action: StringName
@export_node_path("Button") var next_button_path: NodePath


func _ready() -> void:
	var next_button := get_node_or_null(next_button_path) as Button
	if next_button == null:
		push_warning("화면 '%s'의 검증 버튼을 찾을 수 없습니다." % screen_id)
		return
	next_button.pressed.connect(_on_next_button_pressed)


func _on_next_button_pressed() -> void:
	if progression_action == &"":
		return
	progression_requested.emit(progression_action)
