extends SceneTree

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
		"root_type": "Node2D",
	},
	{
		"id": &"reward",
		"path": "res://app/navigation/screens/reward_screen.tscn",
		"root_type": "Control",
	},
	{
		"id": &"boss",
		"path": "res://app/navigation/screens/boss_screen.tscn",
		"root_type": "Node2D",
	},
	{
		"id": &"results",
		"path": "res://app/navigation/screens/results_screen.tscn",
		"root_type": "Control",
	},
]

const NAVIGATION_CONFIG_PATH := "res://app/navigation/default_navigation_config.tres"
const PROGRESSION_CONFIG_PATH := "res://game_flow/default_progression_config.tres"
const BOARD_VIEW_CONFIG_PATH := "res://stages/boards/default_board_view_config.tres"
const BOARD_LAYOUT_CONFIG_PATH := "res://stages/boards/default_board_layout_config.tres"
const APP_ROOT_PATH := "res://app/bootstrap/app_root.tscn"


func _init() -> void:
	call_deferred("_run")


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

	_expect_progression_config(failures)
	_expect_board_configs(failures)

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


func _expect_progression_config(failures: PackedStringArray) -> void:
	var config := ResourceLoader.load(
		PROGRESSION_CONFIG_PATH,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as ProgressionConfig
	if config == null:
		failures.append("기본 ProgressionConfig를 불러오지 못했습니다.")
		return
	if not config.get_validation_error().is_empty():
		failures.append(config.get_validation_error())
	if config.stage_count != 3 or config.normal_wave_count != 3:
		failures.append("기본 진행 설정은 스테이지 3개와 일반 웨이브 3개여야 합니다.")


func _expect_board_configs(failures: PackedStringArray) -> void:
	var view_config := ResourceLoader.load(
		BOARD_VIEW_CONFIG_PATH,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as BoardViewConfig
	var layout_config := ResourceLoader.load(
		BOARD_LAYOUT_CONFIG_PATH,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as BoardLayoutConfig
	if view_config == null:
		failures.append("기본 BoardViewConfig를 불러오지 못했습니다.")
	if layout_config == null:
		failures.append("기본 BoardLayoutConfig를 불러오지 못했습니다.")
	if view_config == null or layout_config == null:
		return
	failures.append_array(view_config.get_validation_errors())
	failures.append_array(layout_config.get_validation_errors())
	if not is_equal_approx(view_config.view_angle_degrees, 58.0):
		failures.append("기본 보드 시점 각도는 58도여야 합니다.")

	var default_polygon := view_config.project_board_polygon(layout_config.boundary_points)
	var top_width := default_polygon[1].x - default_polygon[0].x
	var bottom_width := default_polygon[2].x - default_polygon[3].x
	if top_width >= bottom_width:
		failures.append("2D 목업 보드는 위쪽이 아래쪽보다 좁은 원근 사다리꼴이어야 합니다.")
	if layout_config.get_closed_boundary_points().size() != layout_config.boundary_points.size() + 1:
		failures.append("보드 경계가 마지막 꼭짓점에서 첫 꼭짓점으로 폐합되지 않습니다.")
	if not layout_config.has_launch_to_drain_path():
		failures.append("기본 발사점에서 드레인까지 데이터 경로가 없습니다.")

	var shallow_config := BoardViewConfig.new()
	shallow_config.view_angle_degrees = 30.0
	var steep_config := BoardViewConfig.new()
	steep_config.view_angle_degrees = 75.0
	if shallow_config.get_top_width_ratio() >= steep_config.get_top_width_ratio():
		failures.append("보드 시점 각도 변경이 위쪽 폭 원근에 반영되지 않습니다.")
	if shallow_config.get_vertical_scale() >= steep_config.get_vertical_scale():
		failures.append("보드 시점 각도 변경이 세로 압축에 반영되지 않습니다.")


func _quit_editor(exit_code: int) -> void:
	quit(exit_code)
