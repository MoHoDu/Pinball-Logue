extends SceneTree

const DEFAULT_LAYOUT_PATH := "res://stages/boards/default_board_layout_config.tres"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	_expect_default_bottom_pair(failures)
	_expect_single_cardinal_directions(failures)
	_expect_unique_three_and_four_way_assignments(failures)
	_expect_array_order_independence(failures)
	_expect_invalid_flipper_counts(failures)
	_expect_overlapping_flippers_rejected(failures)
	_expect_exactly_one_launch_anchor(failures)
	_finish(failures)


func _expect_default_bottom_pair(failures: PackedStringArray) -> void:
	var layout := ResourceLoader.load(
		DEFAULT_LAYOUT_PATH,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as BoardLayoutConfig
	if layout == null:
		failures.append("기본 보드 설계도를 불러오지 못했습니다.")
		return
	var assignments := layout.get_flipper_direction_assignments()
	_expect_assignment(assignments, &"flipper_left", BoardLayoutConfig.FLIPPER_DIRECTION_LEFT, failures)
	_expect_assignment(assignments, &"flipper_right", BoardLayoutConfig.FLIPPER_DIRECTION_RIGHT, failures)
	_expect_unique_directions(assignments, 2, failures)
	if layout.get_flipper_anchor_id_for_direction(BoardLayoutConfig.FLIPPER_DIRECTION_LEFT) != &"flipper_left":
		failures.append("왼쪽 방향키로 기본 왼쪽 플리퍼를 찾지 못했습니다.")
	if layout.get_flipper_anchor_id_for_direction(&"unknown") != &"":
		failures.append("지원하지 않는 방향키가 플리퍼를 반환했습니다.")


func _expect_single_cardinal_directions(failures: PackedStringArray) -> void:
	var cases: Array[Dictionary] = [
		{"position": Vector2.LEFT * 0.35, "direction": BoardLayoutConfig.FLIPPER_DIRECTION_LEFT},
		{"position": Vector2.RIGHT * 0.35, "direction": BoardLayoutConfig.FLIPPER_DIRECTION_RIGHT},
		{"position": Vector2.UP * 0.35, "direction": BoardLayoutConfig.FLIPPER_DIRECTION_UP},
		{"position": Vector2.DOWN * 0.35, "direction": BoardLayoutConfig.FLIPPER_DIRECTION_DOWN},
	]
	for case in cases:
		var layout := _make_layout([case["position"]])
		var assignments := layout.get_flipper_direction_assignments()
		_expect_assignment(assignments, &"flipper_1", case["direction"], failures)


func _expect_unique_three_and_four_way_assignments(failures: PackedStringArray) -> void:
	var three_way := _make_layout([
		Vector2(-0.35, 0.0),
		Vector2(0.35, 0.0),
		Vector2(0.0, 0.35),
	])
	var three_assignments := three_way.get_flipper_direction_assignments()
	_expect_assignment(three_assignments, &"flipper_1", BoardLayoutConfig.FLIPPER_DIRECTION_LEFT, failures)
	_expect_assignment(three_assignments, &"flipper_2", BoardLayoutConfig.FLIPPER_DIRECTION_RIGHT, failures)
	_expect_assignment(three_assignments, &"flipper_3", BoardLayoutConfig.FLIPPER_DIRECTION_DOWN, failures)
	_expect_unique_directions(three_assignments, 3, failures)

	var four_way := _make_layout([
		Vector2(-0.35, 0.0),
		Vector2(0.35, 0.0),
		Vector2(0.0, -0.35),
		Vector2(0.0, 0.35),
	])
	var four_assignments := four_way.get_flipper_direction_assignments()
	_expect_assignment(four_assignments, &"flipper_1", BoardLayoutConfig.FLIPPER_DIRECTION_LEFT, failures)
	_expect_assignment(four_assignments, &"flipper_2", BoardLayoutConfig.FLIPPER_DIRECTION_RIGHT, failures)
	_expect_assignment(four_assignments, &"flipper_3", BoardLayoutConfig.FLIPPER_DIRECTION_UP, failures)
	_expect_assignment(four_assignments, &"flipper_4", BoardLayoutConfig.FLIPPER_DIRECTION_DOWN, failures)
	_expect_unique_directions(four_assignments, 4, failures)
	if not four_way.get_validation_errors().is_empty():
		failures.append("유효한 플리퍼 4개 보드가 거부됐습니다: %s" % four_way.get_validation_errors())


func _expect_array_order_independence(failures: PackedStringArray) -> void:
	var layout := _make_layout([Vector2(-0.3, 0.3), Vector2(0.3, 0.3)])
	var expected := layout.get_flipper_direction_assignments()
	layout.anchors.reverse()
	var reordered := layout.get_flipper_direction_assignments()
	if reordered != expected:
		failures.append("플리퍼 배열 순서 변경이 방향키 배정을 바꿨습니다: %s → %s" % [expected, reordered])


func _expect_invalid_flipper_counts(failures: PackedStringArray) -> void:
	var no_flipper := _make_layout([])
	_expect_error(no_flipper.get_validation_errors(), "1~4개", failures)

	var five_flippers := _make_layout([
		Vector2(-0.4, 0.0),
		Vector2(-0.2, 0.3),
		Vector2(0.0, -0.3),
		Vector2(0.2, 0.3),
		Vector2(0.4, 0.0),
	])
	_expect_error(five_flippers.get_validation_errors(), "1~4개", failures)

	var centered_flipper := _make_layout([Vector2.ZERO])
	_expect_error(centered_flipper.get_validation_errors(), "고유 방향키", failures)


func _expect_overlapping_flippers_rejected(failures: PackedStringArray) -> void:
	var overlapping := _make_layout([Vector2(-0.25, 0.30), Vector2(-0.25, 0.30)])
	_expect_error(overlapping.get_validation_errors(), "같은 위치에 겹쳐", failures)
	if not overlapping.get_flipper_direction_assignments().is_empty():
		failures.append("같은 위치에 겹친 플리퍼에 방향키를 배정했습니다.")


func _expect_exactly_one_launch_anchor(failures: PackedStringArray) -> void:
	var valid := _make_layout([Vector2(-0.3, 0.3), Vector2(0.3, 0.3)])
	if not valid.get_validation_errors().is_empty():
		failures.append("발사 지점 1개 보드가 유효하지 않습니다: %s" % valid.get_validation_errors())

	var no_launch := valid.duplicate(true) as BoardLayoutConfig
	for anchor_index in range(no_launch.anchors.size() - 1, -1, -1):
		if no_launch.anchors[anchor_index].get_type_id() == BoardAnchorConfig.TYPE_LAUNCH:
			no_launch.anchors.remove_at(anchor_index)
	_expect_error(no_launch.get_validation_errors(), "정확히 1개", failures)

	var two_launches := valid.duplicate(true) as BoardLayoutConfig
	two_launches.anchors.append(_make_anchor(&"launch_secondary", BoardAnchorConfig.TYPE_LAUNCH, Vector2(-0.35, 0.2)))
	_expect_error(two_launches.get_validation_errors(), "정확히 1개", failures)


func _make_layout(flipper_positions: Array) -> BoardLayoutConfig:
	var layout := BoardLayoutConfig.new()
	layout.anchors.append(_make_anchor(&"launch_main", BoardAnchorConfig.TYPE_LAUNCH, Vector2(0.38, 0.24)))
	layout.anchors.append(_make_anchor(&"drain_main", BoardAnchorConfig.TYPE_DRAIN, Vector2(0.0, 0.46)))
	for flipper_index in flipper_positions.size():
		layout.anchors.append(_make_anchor(
			StringName("flipper_%d" % (flipper_index + 1)),
			BoardAnchorConfig.TYPE_FLIPPER,
			flipper_positions[flipper_index]
		))
	return layout


func _make_anchor(anchor_id: StringName, anchor_type: StringName, position: Vector2) -> BoardAnchorConfig:
	var anchor := BoardAnchorConfig.new()
	anchor.anchor_id = anchor_id
	anchor.anchor_type = String(anchor_type)
	anchor.board_position = position
	return anchor


func _expect_assignment(
	assignments: Dictionary,
	anchor_id: StringName,
	expected_direction: StringName,
	failures: PackedStringArray
) -> void:
	var actual_direction: StringName = assignments.get(anchor_id, &"")
	if actual_direction != expected_direction:
		failures.append(
			"플리퍼 '%s'는 '%s' 방향이어야 하지만 '%s'입니다."
			% [anchor_id, expected_direction, actual_direction]
		)


func _expect_unique_directions(assignments: Dictionary, expected_count: int, failures: PackedStringArray) -> void:
	if assignments.size() != expected_count:
		failures.append("플리퍼 방향키 배정 수는 %d개여야 합니다: %s" % [expected_count, assignments])
		return
	var unique_directions: Dictionary = {}
	for direction_id in assignments.values():
		unique_directions[direction_id] = true
	if unique_directions.size() != expected_count:
		failures.append("한 방향키가 둘 이상의 플리퍼에 중복 배정됐습니다: %s" % assignments)


func _expect_error(errors: PackedStringArray, fragment: String, failures: PackedStringArray) -> void:
	for error in errors:
		if fragment in error:
			return
	failures.append("예상한 검증 오류를 찾지 못했습니다: %s / %s" % [fragment, errors])


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("FLIPPER_DIRECTION_ASSIGNMENT_SMOKE: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("FLIPPER_DIRECTION_ASSIGNMENT_SMOKE: %s" % failure)
	quit(1)
