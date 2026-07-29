extends SceneTree

const PLUGIN_CFG_PATH := "res://addons/pinball_board_authoring/plugin.cfg"
const PLUGIN_SCRIPT_PATH := "res://addons/pinball_board_authoring/plugin.gd"
const CONTENT_PATH_POLICY_PATH := "res://addons/pinball_board_authoring/board_content_path_policy.gd"
const INSPECTOR_PLUGIN_PATH := "res://addons/pinball_board_authoring/korean_config_inspector_plugin.gd"
const PRESENTATION_REGISTRY_PATH := "res://addons/pinball_board_authoring/config_property_presentation_registry.gd"
const AUTHORING_SCENE_PATH := "res://stages/boards/board_authoring_2d.tscn"
const AUTHORING_SCRIPT_PATH := "res://stages/boards/board_authoring_2d.gd"

const REQUIRED_UI_TERMS := [
	"복제해서 새 보드 만들기",
	"외곽선 편집",
	"범퍼 지점 추가",
	"일반 오브젝트 지점 추가",
	"유물 배치 지점 추가",
	"플리퍼 추가",
	"배치 지점 선택·이동",
	"선택 플리퍼 안쪽 방향 맞춤",
	"보드 표시 15% 크게",
	"웨이브에서 이 보드 시험",
	"경로 지점 추가",
	"발사 목표 지점 추가",
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
	_expect_content_path_policy(failures)
	_expect_saved_board_reference_contract(failures)
	_expect_korean_inspector_contract(failures)
	_expect_korean_inspector_serialization_contract(failures)
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
		"duplicate_composition.set(\"layout_config\", saved_layout)",
		"duplicate_composition.set(\"view_config\", saved_view)",
		"linked_layout.resource_path != layout_path",
		"linked_view.resource_path != view_path",
		"BoardContentPathPolicy.get_board_paths",
		"get_path_collision_error",
		"실행 취소는 현재 씬의 연결만 되돌리며, 만든 파일은 삭제하지 않습니다.",
		"add_inspector_plugin",
		"remove_inspector_plugin",
	]:
		if required_fragment not in source:
			failures.append("보드 제작 플러그인의 필수 편집 계약이 없습니다: %s" % required_fragment)
	if "TYPE_BALL" in source or "ball_definition" in source or "공 원형" in source:
		failures.append("보드 제작 플러그인에 공 배치 계약이 포함되어 있습니다.")
	var authoring_source := _read_text(AUTHORING_SCRIPT_PATH)
	for required_fragment in ["get_tree().current_scene == self", "get_viewport_rect().size * 0.5"]:
		if required_fragment not in authoring_source:
			failures.append("보드 제작 씬의 단독 실행 중앙 배치 계약이 없습니다: %s" % required_fragment)


func _expect_content_path_policy(failures: PackedStringArray) -> void:
	var policy := ResourceLoader.load(
		CONTENT_PATH_POLICY_PATH,
		"Script",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	if policy == null:
		failures.append("보드 콘텐츠 저장 경로 규칙을 불러오지 못했습니다.")
		return
	for invalid_id in ["", "ForestGate", "forest gate", "forest-gate", "한글보드"]:
		if String(policy.call("get_board_id_error", invalid_id)).is_empty():
			failures.append("잘못된 보드 ID를 저장 경로 규칙이 거부하지 않았습니다: %s" % invalid_id)
	var board_id := "forest_gate"
	if not String(policy.call("get_board_id_error", board_id)).is_empty():
		failures.append("유효한 보드 ID를 저장 경로 규칙이 거부했습니다: %s" % board_id)
		return
	var paths: Dictionary = policy.call("get_board_paths", board_id)
	var expected_paths := {
		"directory": "res://stages/boards/content/forest_gate",
		"layout": "res://stages/boards/content/forest_gate/forest_gate_layout.tres",
		"view": "res://stages/boards/content/forest_gate/forest_gate_view.tres",
		"composition": "res://stages/boards/content/forest_gate/forest_gate_wave_composition.tres",
	}
	for path_kind in expected_paths:
		if String(paths.get(path_kind, "")) != String(expected_paths[path_kind]):
			failures.append("보드 콘텐츠 %s 경로가 표준 규칙과 다릅니다." % path_kind)


func _expect_saved_board_reference_contract(failures: PackedStringArray) -> void:
	var timestamp := Time.get_ticks_usec()
	var directory := "/private/tmp/pinball_logue_board_reference_%d" % timestamp
	var layout_path := "%s/test_layout.tres" % directory
	var view_path := "%s/test_view.tres" % directory
	var composition_path := "%s/test_wave_composition.tres" % directory
	var created_paths: Array[String] = [layout_path, view_path, composition_path]
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		failures.append("보드 참조 저장 검사용 임시 폴더를 만들지 못했습니다.")
		return
	var source_layout := load("res://stages/boards/default_board_layout_config.tres") as Resource
	var source_view := load("res://stages/boards/default_board_view_config.tres") as Resource
	var source_composition := load("res://stages/waves/default_wave_board_composition.tres") as Resource
	if source_layout == null or source_view == null or source_composition == null:
		failures.append("보드 참조 저장 검사용 기본 설정을 불러오지 못했습니다.")
		_cleanup_board_reference_temp(directory, created_paths)
		return
	if ResourceSaver.save(source_layout.duplicate(true), layout_path) != OK:
		failures.append("보드 참조 저장 검사용 설계도를 저장하지 못했습니다.")
		_cleanup_board_reference_temp(directory, created_paths)
		return
	if ResourceSaver.save(source_view.duplicate(true), view_path) != OK:
		failures.append("보드 참조 저장 검사용 보기 설정을 저장하지 못했습니다.")
		_cleanup_board_reference_temp(directory, created_paths)
		return
	var saved_layout := ResourceLoader.load(
		layout_path,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	if saved_layout == null:
		failures.append("저장한 검사용 보드 설계도를 다시 불러오지 못했습니다.")
		_cleanup_board_reference_temp(directory, created_paths)
		return
	var saved_view := ResourceLoader.load(
		view_path,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	if saved_view == null:
		failures.append("저장한 검사용 보드 보기 설정을 다시 불러오지 못했습니다.")
		_cleanup_board_reference_temp(directory, created_paths)
		return
	var saved_composition := source_composition.duplicate(true) as Resource
	saved_composition.set("layout_config", saved_layout)
	saved_composition.set("view_config", saved_view)
	if ResourceSaver.save(saved_composition, composition_path) != OK:
		failures.append("보드 참조 저장 검사용 웨이브 배치표를 저장하지 못했습니다.")
		_cleanup_board_reference_temp(directory, created_paths)
		return
	var reloaded_composition := ResourceLoader.load(
		composition_path,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	var linked_layout := (
		reloaded_composition.get("layout_config") as Resource
		if reloaded_composition != null
		else null
	)
	var linked_view := (
		reloaded_composition.get("view_config") as Resource
		if reloaded_composition != null
		else null
	)
	if linked_layout == null or linked_layout.resource_path != layout_path:
		failures.append("재열기한 웨이브 배치표가 별도 보드 설계도 파일을 참조하지 않습니다.")
	if linked_view == null or linked_view.resource_path != view_path:
		failures.append("재열기한 웨이브 배치표가 별도 보드 보기 설정 파일을 참조하지 않습니다.")
	_cleanup_board_reference_temp(directory, created_paths)


func _cleanup_board_reference_temp(directory: String, file_paths: Array[String]) -> void:
	for file_path in file_paths:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)


func _expect_korean_inspector_contract(failures: PackedStringArray) -> void:
	for script_path in [INSPECTOR_PLUGIN_PATH, PRESENTATION_REGISTRY_PATH]:
		if ResourceLoader.load(script_path, "Script", ResourceLoader.CACHE_MODE_IGNORE) == null:
			failures.append("한국어 인스펙터 스크립트를 불러오지 못했습니다: %s" % script_path)
	var inspector_source := _read_text(INSPECTOR_PLUGIN_PATH)
	for required_fragment in [
		"EditorInspector.instantiate_property_editor",
		"_default_editor_creation_depth > 0",
		"_default_editor_creation_depth += 1",
		"_default_editor_creation_depth -= 1",
		"add_property_editor(name, editor, false, label)",
		"editor.tooltip_text",
	]:
		if required_fragment not in inspector_source:
			failures.append("Godot 기본 편집 동작을 유지하는 한국어 인스펙터 계약이 없습니다: %s" % required_fragment)
	var registry := ResourceLoader.load(
		PRESENTATION_REGISTRY_PATH,
		"Script",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	if registry == null:
		return
	for expected_mapping in [
		[&"ProgressionConfig", &"stage_count", "스테이지 수"],
		[&"BoardViewConfig", &"view_angle_degrees", "보드 시점 각도"],
		[&"BoardPlaceableDefinition", &"max_durability", "최대 내구도"],
		[&"BallDefinition", &"ball_id", "공 식별자"],
		[&"BallPhysicsProfile", &"radius_board_ratio", "공 반지름"],
		[&"LaunchConfig", &"aim_mode", "조준 방식"],
	]:
		var presentation: Dictionary = registry.call(
			"get_presentation_for_class",
			expected_mapping[0],
			expected_mapping[1]
		)
		if String(presentation.get("label", "")) != expected_mapping[2]:
			failures.append("한국어 인스펙터 표시 정보가 없습니다: %s.%s" % [expected_mapping[0], expected_mapping[1]])
	for actual_mapping in [
		["res://game_flow/default_progression_config.tres", &"stage_count", "스테이지 수"],
		["res://stages/boards/default_board_view_config.tres", &"view_angle_degrees", "보드 시점 각도"],
		["res://pinball/objects/normal_bumper_definition.tres", &"max_durability", "최대 내구도"],
		["res://pinball/ball/standard_ball_physics_profile.tres", &"radius_board_ratio", "공 반지름"],
		["res://pinball/launcher/default_launch_config.tres", &"aim_mode", "조준 방식"],
	]:
		var object := ResourceLoader.load(actual_mapping[0], "Resource", ResourceLoader.CACHE_MODE_IGNORE)
		if object == null:
			failures.append("한국어 인스펙터 대상 설정을 불러오지 못했습니다: %s" % actual_mapping[0])
			continue
		var presentation: Dictionary = registry.call("get_presentation", object, actual_mapping[1])
		if String(presentation.get("label", "")) != actual_mapping[2]:
			failures.append("실제 설정에서 한국어 인스펙터 표시를 찾지 못했습니다: %s" % actual_mapping[0])


func _expect_korean_inspector_serialization_contract(failures: PackedStringArray) -> void:
	var cases := [
		["res://game_flow/default_progression_config.tres", &"stage_count", 4, "스테이지 수"],
		["res://stages/boards/default_board_view_config.tres", &"view_angle_degrees", 60.0, "보드 시점 각도"],
		["res://pinball/objects/normal_bumper_definition.tres", &"max_durability", 4, "최대 내구도"],
		["res://pinball/ball/standard_ball_physics_profile.tres", &"radius_board_ratio", 0.03, "공 반지름"],
		["res://pinball/launcher/default_launch_config.tres", &"aim_mode", "direction_keys", "조준 방식"],
	]
	for case_index in cases.size():
		var test_case: Array = cases[case_index]
		var source := ResourceLoader.load(
			test_case[0],
			"Resource",
			ResourceLoader.CACHE_MODE_IGNORE
		) as Resource
		if source == null:
			failures.append("인스펙터 저장 검사용 설정을 불러오지 못했습니다: %s" % test_case[0])
			continue
		var copy := source.duplicate(true) as Resource
		copy.set(test_case[1], test_case[2])
		var temp_path := "/private/tmp/pinball_logue_inspector_%d_%d.tres" % [
			Time.get_ticks_usec(),
			case_index,
		]
		if ResourceSaver.save(copy, temp_path) != OK:
			failures.append("인스펙터 저장 검사용 복제본을 저장하지 못했습니다: %s" % test_case[0])
			continue
		var reloaded := ResourceLoader.load(
			temp_path,
			"Resource",
			ResourceLoader.CACHE_MODE_IGNORE
		) as Resource
		if reloaded == null or not _values_match(reloaded.get(test_case[1]), test_case[2]):
			failures.append("인스펙터 저장 검사용 값이 재열기 뒤 유지되지 않았습니다: %s" % test_case[0])
		var saved_text := _read_absolute_text(temp_path)
		if "%s =" % String(test_case[1]) not in saved_text:
			failures.append("설정 복제본에 영문 저장 키가 없습니다: %s" % test_case[1])
		if String(test_case[3]) in saved_text:
			failures.append("한국어 인스펙터 표시 이름이 설정 파일에 저장됐습니다: %s" % test_case[3])
		DirAccess.remove_absolute(temp_path)


func _values_match(actual: Variant, expected: Variant) -> bool:
	if actual is float or expected is float:
		return is_equal_approx(float(actual), float(expected))
	return actual == expected


func _read_absolute_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


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
	if board.position != Vector2.ZERO or not board.transform.is_equal_approx(Transform2D.IDENTITY):
		failures.append("보드 제작 씬의 루트 변형은 인스턴스 호환을 위해 항등값이어야 합니다.")
	for definition in board.object_definitions:
		if definition != null and "ball" in String(definition.content_id).to_lower():
			failures.append("보드 제작 씬의 오브젝트 원형 목록에 공이 포함되어 있습니다.")
	board.free()


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("BOARD_AUTHORING_EDITOR_CHECK: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("BOARD_AUTHORING_EDITOR_CHECK: %s" % failure)
	quit(1)
