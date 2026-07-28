extends SceneTree

const BOARD_SCENE_PATH := "res://stages/boards/board_authoring_2d.tscn"
const WAVE_SCENE_PATH := "res://app/navigation/screens/wave_screen.tscn"
const BOSS_SCENE_PATH := "res://app/navigation/screens/boss_screen.tscn"
const FLOAT_EPSILON := 0.001


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var board := _instantiate_board(BOARD_SCENE_PATH, failures)
	if board == null:
		_finish(failures)
		return

	if not board.is_assembly_valid():
		failures.append("기본 2D 보드 조립이 유효하지 않습니다: %s" % board.get_assembly_errors())
	_expect_dictionary_size(
		board.get_projected_anchor_positions(BoardAnchorConfig.TYPE_BUMPER),
		5,
		"범퍼",
		failures
	)
	_expect_dictionary_size(
		board.get_projected_anchor_positions(BoardAnchorConfig.TYPE_FLIPPER),
		2,
		"플리퍼",
		failures
	)
	_expect_dictionary_size(
		board.get_projected_anchor_positions(BoardAnchorConfig.TYPE_RELIC_SLOT),
		3,
		"유물 슬롯",
		failures
	)
	_expect_flipper_direction_projection(board, failures)
	_expect_custom_layout(board, failures)
	_expect_custom_view(board, failures)
	_expect_invalid_assembly(board, failures)
	board.free()

	_expect_screen_contract(WAVE_SCENE_PATH, false, failures)
	_expect_screen_contract(BOSS_SCENE_PATH, true, failures)
	_finish(failures)


func _expect_flipper_direction_projection(
	board: BoardMockup2D,
	failures: PackedStringArray
) -> void:
	var flipper_anchor := board.layout_config.get_anchor(&"flipper_left")
	var resolved_position := board.layout_config.get_resolved_anchor_position(flipper_anchor)
	var resolved_direction := board.layout_config.get_resolved_flipper_direction(flipper_anchor)
	var projected_origin := board.view_config.project_board_point(resolved_position)
	var projected_target := board.view_config.project_board_point(
		resolved_position + resolved_direction * 0.01
	)
	var expected_direction := projected_origin.direction_to(projected_target)
	var actual_direction := board.get_projected_anchor_direction(flipper_anchor.anchor_id)
	var unprojected_direction := resolved_direction
	if not actual_direction.is_equal_approx(expected_direction):
		failures.append("플리퍼의 보드 평면 회전이 2D 투영 방향과 일치하지 않습니다.")
	if actual_direction.is_equal_approx(unprojected_direction):
		failures.append("플리퍼 방향이 58도 비등방 원근 투영을 거치지 않았습니다.")


func _expect_custom_layout(board: BoardMockup2D, failures: PackedStringArray) -> void:
	var original_layout := board.layout_config
	var original_composition := board.composition_config
	var copied_layout := original_layout.duplicate(true) as BoardLayoutConfig
	var moved_anchor := copied_layout.get_anchor(&"bumper_top_left")
	moved_anchor.board_position = Vector2(-0.2, -0.2)
	var added_anchor := BoardAnchorConfig.new()
	added_anchor.anchor_id = &"bumper_custom"
	added_anchor.anchor_type = "bumper"
	added_anchor.board_position = Vector2(0.0, 0.04)
	copied_layout.anchors.append(added_anchor)
	board.layout_config = copied_layout
	var copied_composition := original_composition.duplicate(true) as WaveBoardCompositionConfig
	copied_composition.layout_config = copied_layout
	board.composition_config = copied_composition

	var projected_bumpers := board.get_projected_anchor_positions(BoardAnchorConfig.TYPE_BUMPER)
	if projected_bumpers.size() != 6:
		failures.append("복제 레이아웃의 범퍼 추가가 2D 조립 결과에 반영되지 않았습니다.")
	var expected_position := board.view_config.project_board_point(moved_anchor.board_position)
	var actual_position: Vector2 = projected_bumpers.get(&"bumper_top_left", Vector2(INF, INF))
	if not actual_position.is_equal_approx(expected_position):
		failures.append("복제 레이아웃의 앵커 이동이 2D 투영 위치에 반영되지 않았습니다.")
	if original_layout.get_anchors_by_type(BoardAnchorConfig.TYPE_BUMPER).size() != 5:
		failures.append("복제 레이아웃 변경이 기본 레이아웃 개수를 오염시켰습니다.")
	board.layout_config = original_layout
	board.composition_config = original_composition


func _expect_custom_view(board: BoardMockup2D, failures: PackedStringArray) -> void:
	var original_view := board.view_config
	var copied_view := original_view.duplicate(true) as BoardViewConfig
	copied_view.view_angle_degrees = 75.0
	board.view_config = copied_view
	var boundary := board.get_projected_boundary()
	var top_width := boundary[1].x - boundary[0].x
	var projected_height := boundary[2].y - boundary[1].y
	if absf(top_width - 466.0615) > FLOAT_EPSILON:
		failures.append("75도 복제 시점의 상단 폭이 예상값과 다릅니다: %f" % top_width)
	if absf(projected_height - 470.0) > FLOAT_EPSILON:
		failures.append("75도 복제 시점의 투영 높이가 예상값과 다릅니다: %f" % projected_height)
	board.view_config = original_view


func _expect_invalid_assembly(board: BoardMockup2D, failures: PackedStringArray) -> void:
	var original_layout := board.layout_config
	var original_composition := board.composition_config
	var invalid_layout := original_layout.duplicate(true) as BoardLayoutConfig
	invalid_layout.launch_anchor_id = &"missing_launch"
	board.layout_config = invalid_layout
	var invalid_composition := original_composition.duplicate(true) as WaveBoardCompositionConfig
	invalid_composition.layout_config = invalid_layout
	board.composition_config = invalid_composition
	if board.is_assembly_valid():
		failures.append("잘못된 앵커 참조가 있는 2D 보드 조립이 허용됐습니다.")
	board.layout_config = original_layout
	board.composition_config = original_composition


func _expect_screen_contract(
	scene_path: String,
	expected_show_boss: bool,
	failures: PackedStringArray
) -> void:
	var packed_scene := ResourceLoader.load(
		scene_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PackedScene
	if packed_scene == null:
		failures.append("화면 씬을 불러오지 못했습니다: %s" % scene_path)
		return
	var screen := packed_scene.instantiate()
	var board := screen.get_node_or_null("BoardMockup2D") as BoardMockup2D
	if board == null:
		failures.append("화면에 BoardMockup2D 조립체가 없습니다: %s" % scene_path)
	elif not board.is_assembly_valid():
		failures.append("화면의 BoardMockup2D 설정이 유효하지 않습니다: %s" % scene_path)
	elif board.show_boss != expected_show_boss:
		failures.append("화면의 보스 표현 상태가 예상과 다릅니다: %s" % scene_path)
	if screen != null:
		screen.free()


func _instantiate_board(scene_path: String, failures: PackedStringArray) -> BoardMockup2D:
	var packed_scene := ResourceLoader.load(
		scene_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PackedScene
	if packed_scene == null:
		failures.append("2D 보드 씬을 불러오지 못했습니다.")
		return null
	var board := packed_scene.instantiate() as BoardMockup2D
	if board == null:
		failures.append("2D 보드 씬을 BoardMockup2D로 인스턴스화하지 못했습니다.")
	return board


func _expect_dictionary_size(
	values: Dictionary,
	expected_size: int,
	label: String,
	failures: PackedStringArray
) -> void:
	if values.size() != expected_size:
		failures.append("기본 %s 조립 개수는 %d여야 하지만 %d입니다." % [label, expected_size, values.size()])


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("BOARD_MOCKUP_2D_ASSEMBLY_SMOKE: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("BOARD_MOCKUP_2D_ASSEMBLY_SMOKE: %s" % failure)
	quit(1)
