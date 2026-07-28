extends SceneTree

const PLUGIN_CFG_PATH := "res://addons/pinball_board_authoring/plugin.cfg"
const PLUGIN_SCRIPT_PATH := "res://addons/pinball_board_authoring/plugin.gd"
const AUTHORING_SCENE_PATH := "res://stages/boards/board_authoring_2d.tscn"

const REQUIRED_UI_TERMS := [
	"복제해서 새 보드 만들기",
	"외곽선 편집",
	"범퍼 지점 추가",
	"일반 오브젝트 지점 추가",
	"유물 배치 지점 추가",
	"플리퍼 추가",
	"선택 지점에 원형 적용",
	"배치 비우기",
	"오류 확인",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	_expect_plugin_configuration(failures)
	_expect_editor_contract(failures)
	_expect_authoring_scene_contract(failures)
	_finish(failures)


func _expect_plugin_configuration(failures: PackedStringArray) -> void:
	var config := ConfigFile.new()
	if config.load(PLUGIN_CFG_PATH) != OK:
		failures.append("보드 제작 플러그인 설정을 불러오지 못했습니다.")
		return
	if config.get_value("plugin", "script", "") != "plugin.gd":
		failures.append("플러그인 스크립트 경로는 애드온 폴더 기준 상대 경로여야 합니다.")
	var enabled_plugins: PackedStringArray = ProjectSettings.get_setting(
		"editor_plugins/enabled",
		PackedStringArray()
	)
	if not enabled_plugins.has(PLUGIN_CFG_PATH):
		failures.append("project.godot에서 보드 제작 플러그인이 활성화되지 않았습니다.")
	if ResourceLoader.load(PLUGIN_SCRIPT_PATH, "Script", ResourceLoader.CACHE_MODE_IGNORE) == null:
		failures.append("보드 제작 플러그인 스크립트를 파싱하지 못했습니다.")


func _expect_editor_contract(failures: PackedStringArray) -> void:
	var file := FileAccess.open(PLUGIN_SCRIPT_PATH, FileAccess.READ)
	if file == null:
		failures.append("보드 제작 플러그인 소스를 읽지 못했습니다.")
		return
	var source := file.get_as_text()
	for term in REQUIRED_UI_TERMS:
		if term not in source:
			failures.append("보드 제작 도구에 필수 한국어 조작이 없습니다: %s" % term)
	for required_fragment in [
		"EditorUndoRedoManager",
		"snap_flipper_anchor_to_boundary",
		"get_resolved_anchor_position",
		"get_viewport_transform() * _edited_node.get_global_transform()",
		"composition_config",
		"object_definitions",
		"duplicate_composition.set(\"layout_config\", duplicate_layout)",
	]:
		if required_fragment not in source:
			failures.append("보드 제작 플러그인의 필수 편집 계약이 없습니다: %s" % required_fragment)
	if "TYPE_BALL" in source or "ball_definition" in source or "공 원형" in source:
		failures.append("보드 제작 플러그인에 공 배치 계약이 포함되어 있습니다.")


func _expect_authoring_scene_contract(failures: PackedStringArray) -> void:
	var packed := ResourceLoader.load(
		AUTHORING_SCENE_PATH,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PackedScene
	if packed == null:
		failures.append("보드 제작 씬을 불러오지 못했습니다.")
		return
	var board := packed.instantiate() as BoardMockup2D
	if board == null:
		failures.append("보드 제작 씬의 루트가 BoardMockup2D가 아닙니다.")
		return
	if not board.is_assembly_valid():
		failures.append("보드 제작 씬 조립이 유효하지 않습니다: %s" % board.get_assembly_errors())
	for definition in board.object_definitions:
		if definition != null and "ball" in String(definition.content_id).to_lower():
			failures.append("보드 제작 씬의 오브젝트 원형 목록에 공이 포함되어 있습니다.")
	board.free()


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("BOARD_AUTHORING_EDITOR_CHECK: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("BOARD_AUTHORING_EDITOR_CHECK: %s" % failure)
	quit(1)
