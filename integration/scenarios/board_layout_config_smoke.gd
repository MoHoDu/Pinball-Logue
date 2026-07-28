extends SceneTree

const LAYOUT_CONFIG_PATH := "res://stages/boards/default_board_layout_config.tres"
const VIEW_CONFIG_PATH := "res://stages/boards/default_board_view_config.tres"
const FLOAT_EPSILON := 0.001


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var layout := ResourceLoader.load(
		LAYOUT_CONFIG_PATH,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as BoardLayoutConfig
	var view := ResourceLoader.load(
		VIEW_CONFIG_PATH,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as BoardViewConfig

	if layout == null:
		failures.append("기본 BoardLayoutConfig를 불러오지 못했습니다.")
	if view == null:
		failures.append("기본 BoardViewConfig를 불러오지 못했습니다.")
	if not failures.is_empty():
		_finish(failures)
		return

	failures.append_array(layout.get_validation_errors())
	failures.append_array(view.get_validation_errors())
	_expect_default_layout(layout, failures)
	_expect_default_projection(layout, view, failures)
	_expect_copy_customization(layout, failures)
	_expect_invalid_layouts(layout, failures)
	_expect_view_boundaries(view, failures)
	_finish(failures)


func _expect_default_layout(layout: BoardLayoutConfig, failures: PackedStringArray) -> void:
	if layout.boundary_points.size() != 4:
		failures.append("기본 보드 경계 꼭짓점은 4개여야 합니다.")
	var closed_boundary := layout.get_closed_boundary_points()
	if closed_boundary.size() != 5 or closed_boundary[0] != closed_boundary[4]:
		failures.append("기본 보드 경계가 마지막 점에서 첫 점으로 폐합되지 않습니다.")
	_expect_anchor_count(layout, BoardAnchorConfig.TYPE_LAUNCH, 1, failures)
	_expect_anchor_count(layout, BoardAnchorConfig.TYPE_DRAIN, 1, failures)
	_expect_anchor_count(layout, BoardAnchorConfig.TYPE_BUMPER, 5, failures)
	_expect_anchor_count(layout, BoardAnchorConfig.TYPE_FLIPPER, 2, failures)
	_expect_anchor_count(layout, BoardAnchorConfig.TYPE_RELIC_SLOT, 3, failures)
	if layout.launch_anchor_id != &"launch_main" or layout.drain_anchor_id != &"drain_main":
		failures.append("기본 발사·드레인 참조 ID가 명세와 다릅니다.")
	if not layout.has_launch_to_drain_path():
		failures.append("기본 발사점에서 드레인까지 경계 안의 직선 경로가 없습니다.")


func _expect_default_projection(
	layout: BoardLayoutConfig,
	view: BoardViewConfig,
	failures: PackedStringArray
) -> void:
	if not is_equal_approx(view.view_angle_degrees, 58.0):
		failures.append("기본 보드 시점은 58도여야 합니다.")
	var projected_boundary := view.project_board_polygon(layout.boundary_points)
	var top_width := projected_boundary[1].x - projected_boundary[0].x
	var bottom_width := projected_boundary[2].x - projected_boundary[3].x
	var projected_height := projected_boundary[2].y - projected_boundary[1].y
	if absf(top_width - 413.806) > FLOAT_EPSILON:
		failures.append("기본 투영 상단 폭이 예상값과 다릅니다: %f" % top_width)
	if absf(bottom_width - 540.0) > FLOAT_EPSILON:
		failures.append("기본 투영 하단 폭이 예상값과 다릅니다: %f" % bottom_width)
	if absf(projected_height - 436.0) > FLOAT_EPSILON:
		failures.append("기본 투영 높이가 예상값과 다릅니다: %f" % projected_height)


func _expect_copy_customization(layout: BoardLayoutConfig, failures: PackedStringArray) -> void:
	var copied_layout := layout.duplicate(true) as BoardLayoutConfig
	var copied_bumper := copied_layout.get_anchor(&"bumper_top_left")
	var original_bumper := layout.get_anchor(&"bumper_top_left")
	copied_bumper.board_position = Vector2(-0.2, -0.2)
	var added_bumper := BoardAnchorConfig.new()
	added_bumper.anchor_id = &"bumper_custom"
	added_bumper.anchor_type = "bumper"
	added_bumper.board_position = Vector2(0.0, 0.04)
	copied_layout.anchors.append(added_bumper)

	if not copied_layout.get_validation_errors().is_empty():
		failures.append("복제 레이아웃의 유효한 위치·개수 변경이 거부됐습니다.")
	if copied_layout.get_anchors_by_type(BoardAnchorConfig.TYPE_BUMPER).size() != 6:
		failures.append("복제 레이아웃의 범퍼 추가가 개수에 반영되지 않았습니다.")
	if original_bumper.board_position != Vector2(-0.28, -0.28):
		failures.append("복제 레이아웃 변경이 기본 리소스의 앵커를 오염시켰습니다.")


func _expect_invalid_layouts(layout: BoardLayoutConfig, failures: PackedStringArray) -> void:
	var too_few_points := layout.duplicate(true) as BoardLayoutConfig
	too_few_points.boundary_points = PackedVector2Array([Vector2.ZERO, Vector2.ONE])
	_expect_error(too_few_points.get_validation_errors(), "3개 이상", failures)

	var self_intersecting := layout.duplicate(true) as BoardLayoutConfig
	self_intersecting.boundary_points = PackedVector2Array([
		Vector2(-0.5, -0.5), Vector2(0.5, 0.5),
		Vector2(0.5, -0.5), Vector2(-0.5, 0.5),
	])
	_expect_error(self_intersecting.get_validation_errors(), "자기 교차", failures)

	var outside_boundary := layout.duplicate(true) as BoardLayoutConfig
	outside_boundary.boundary_points[1] = Vector2(0.51, -0.5)
	_expect_error(outside_boundary.get_validation_errors(), "-0.5~0.5", failures)

	var duplicate_id := layout.duplicate(true) as BoardLayoutConfig
	duplicate_id.anchors[1].anchor_id = duplicate_id.anchors[0].anchor_id
	_expect_error(duplicate_id.get_validation_errors(), "중복", failures)

	var missing_reference := layout.duplicate(true) as BoardLayoutConfig
	missing_reference.launch_anchor_id = &"missing_launch"
	_expect_error(missing_reference.get_validation_errors(), "찾을 수 없습니다", failures)

	var wrong_type := layout.duplicate(true) as BoardLayoutConfig
	wrong_type.launch_anchor_id = &"drain_main"
	_expect_error(wrong_type.get_validation_errors(), "종류", failures)

	var outside_anchor := layout.duplicate(true) as BoardLayoutConfig
	outside_anchor.anchors[0].board_position = Vector2(0.75, 0.0)
	_expect_error(outside_anchor.get_validation_errors(), "경계 밖", failures)

	var null_anchor := layout.duplicate(true) as BoardLayoutConfig
	null_anchor.anchors.append(null)
	_expect_error(null_anchor.get_validation_errors(), "참조가 비어", failures)


func _expect_view_boundaries(view: BoardViewConfig, failures: PackedStringArray) -> void:
	var minimum_angle := view.duplicate(true) as BoardViewConfig
	minimum_angle.view_angle_degrees = 20.0
	if not minimum_angle.get_validation_errors().is_empty():
		failures.append("최소 허용 시점 20도가 거부됐습니다.")
	var maximum_angle := view.duplicate(true) as BoardViewConfig
	maximum_angle.view_angle_degrees = 85.0
	if not maximum_angle.get_validation_errors().is_empty():
		failures.append("최대 허용 시점 85도가 거부됐습니다.")
	var invalid_angle := view.duplicate(true) as BoardViewConfig
	invalid_angle.view_angle_degrees = 19.5
	_expect_error(invalid_angle.get_validation_errors(), "20~85", failures)
	var non_finite_angle := view.duplicate(true) as BoardViewConfig
	non_finite_angle.view_angle_degrees = NAN
	_expect_error(non_finite_angle.get_validation_errors(), "20~85", failures)
	var invalid_marker_size := view.duplicate(true) as BoardViewConfig
	invalid_marker_size.flipper_length = 0.0
	_expect_error(invalid_marker_size.get_validation_errors(), "플리퍼 길이", failures)


func _expect_anchor_count(
	layout: BoardLayoutConfig,
	anchor_type: StringName,
	expected_count: int,
	failures: PackedStringArray
) -> void:
	var actual_count := layout.get_anchors_by_type(anchor_type).size()
	if actual_count != expected_count:
		failures.append(
			"앵커 종류 '%s'의 기본 개수는 %d여야 하지만 %d입니다."
			% [anchor_type, expected_count, actual_count]
		)


func _expect_error(
	errors: PackedStringArray,
	expected_fragment: String,
	failures: PackedStringArray
) -> void:
	for error in errors:
		if expected_fragment in error:
			return
	failures.append("예상한 검증 오류를 찾지 못했습니다: %s / %s" % [expected_fragment, errors])


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("BOARD_LAYOUT_CONFIG_SMOKE: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("BOARD_LAYOUT_CONFIG_SMOKE: %s" % failure)
	quit(1)
