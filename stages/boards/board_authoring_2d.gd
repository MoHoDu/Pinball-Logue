@tool
extends BoardMockup2D


func _ready() -> void:
	# 씬 파일의 루트 변형은 항등값으로 유지한다. 제작 씬을 단독 실행할 때만
	# 현재 창 중앙에 배치해 다른 씬의 인스턴스 변형을 덮어쓰지 않는다.
	if not Engine.is_editor_hint() and get_tree().current_scene == self:
		position = get_viewport_rect().size * 0.5
	super._ready()
