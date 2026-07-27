@tool
extends EditorScript

const SCREEN_SCENES: Array[Dictionary] = [
	{
		"id": &"main_lobby",
		"path": "res://app/navigation/screens/main_lobby_screen.tscn",
		"root_type": "Control",
	},
	{
		"id": &"stage_selection",
		"path": "res://app/navigation/screens/stage_selection_screen.tscn",
		"root_type": "Control",
	},
	{
		"id": &"wave",
		"path": "res://app/navigation/screens/wave_screen.tscn",
		"root_type": "Node3D",
	},
	{
		"id": &"reward",
		"path": "res://app/navigation/screens/reward_screen.tscn",
		"root_type": "Control",
	},
	{
		"id": &"boss",
		"path": "res://app/navigation/screens/boss_screen.tscn",
		"root_type": "Node3D",
	},
	{
		"id": &"results",
		"path": "res://app/navigation/screens/results_screen.tscn",
		"root_type": "Control",
	},
]

const NAVIGATION_CONFIG_PATH := "res://app/navigation/default_navigation_config.tres"
const APP_ROOT_PATH := "res://app/bootstrap/app_root.tscn"


func _run() -> void:
	var failures := PackedStringArray()
	var expected_ids: Dictionary = {}

	for screen_definition in SCREEN_SCENES:
		var screen_id: StringName = screen_definition["id"]
		var scene_path: String = screen_definition["path"]
		var root_type: String = screen_definition["root_type"]
		expected_ids[screen_id] = true

		var packed_scene := ResourceLoader.load(
			scene_path,
			"PackedScene",
			ResourceLoader.CACHE_MODE_IGNORE
		) as PackedScene
		if packed_scene == null:
			failures.append("화면 리소스를 불러오지 못했습니다: %s" % scene_path)
			continue

		var screen_instance := packed_scene.instantiate()
		if screen_instance == null:
			failures.append("화면을 인스턴스화하지 못했습니다: %s" % scene_path)
			continue
		if not screen_instance.is_class(root_type):
			failures.append(
				"화면 '%s'의 루트는 %s여야 하지만 %s입니다."
				% [screen_id, root_type, screen_instance.get_class()]
			)
		screen_instance.free()

	var navigation_config := ResourceLoader.load(
		NAVIGATION_CONFIG_PATH,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as NavigationConfig
	if navigation_config == null:
		failures.append("기본 NavigationConfig를 불러오지 못했습니다.")
	else:
		failures.append_array(navigation_config.get_validation_errors())
		_expect_route_coverage(navigation_config, expected_ids, failures)

	var app_root_scene := ResourceLoader.load(
		APP_ROOT_PATH,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PackedScene
	if app_root_scene == null:
		failures.append("AppRoot 씬을 불러오지 못했습니다.")
	else:
		var app_root_instance := app_root_scene.instantiate()
		if app_root_instance == null or not app_root_instance is AppRoot:
			failures.append("AppRoot 씬의 루트 스크립트가 올바르지 않습니다.")
		if app_root_instance != null:
			app_root_instance.free()

	if failures.is_empty():
		print("SCENE_FOUNDATION_EDITOR_CHECK: PASS")
		_quit_editor(0)
		return

	for failure in failures:
		push_error("SCENE_FOUNDATION_EDITOR_CHECK: %s" % failure)
	_quit_editor(1)


func _expect_route_coverage(
	navigation_config: NavigationConfig,
	expected_ids: Dictionary,
	failures: PackedStringArray
) -> void:
	var actual_ids: Dictionary = {}
	for route in navigation_config.routes:
		if route != null:
			actual_ids[route.screen_id] = true

	for expected_id in expected_ids:
		if not actual_ids.has(expected_id):
			failures.append("화면 '%s'의 경로가 없습니다." % expected_id)

	for actual_id in actual_ids:
		if not expected_ids.has(actual_id):
			failures.append("정의되지 않은 추가 화면 경로가 있습니다: %s" % actual_id)


func _quit_editor(exit_code: int) -> void:
	get_editor_interface().get_base_control().get_tree().quit(exit_code)
