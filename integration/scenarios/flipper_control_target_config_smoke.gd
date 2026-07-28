extends SceneTree

const DEFAULT_COMPOSITION_PATH := "res://stages/waves/default_wave_board_composition.tres"
const DEFINITION_PATHS := [
	"res://pinball/objects/normal_bumper_definition.tres",
	"res://pinball/objects/bounce_bumper_definition.tres",
	"res://pinball/objects/wall_definition.tres",
	"res://pinball/objects/general_object_definition.tres",
	"res://pinball/flippers/standard_flipper_definition.tres",
	"res://pinball/flippers/small_flipper_definition.tres",
	"res://relics/catalog/path_guide_relic_preview_definition.tres",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var definitions_by_id := _load_definition_map(failures)
	var composition := ResourceLoader.load(
		DEFAULT_COMPOSITION_PATH,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as WaveBoardCompositionConfig
	if composition == null:
		failures.append("기본 웨이브 배치를 불러오지 못했습니다.")
		_finish(failures)
		return
	_expect_explicit_pair(composition, definitions_by_id, failures)
	_expect_legacy_single_targets(composition, definitions_by_id, failures)
	_expect_four_flipper_mixed_targets(composition, definitions_by_id, failures)
	_expect_invalid_targets_rejected(composition, definitions_by_id, failures)
	_finish(failures)


func _load_definition_map(failures: PackedStringArray) -> Dictionary:
	var definitions: Array[BoardPlaceableDefinition] = []
	for path in DEFINITION_PATHS:
		var definition := ResourceLoader.load(path) as BoardPlaceableDefinition
		if definition == null:
			failures.append("플리퍼 원형을 불러오지 못했습니다: %s" % path)
		else:
			definitions.append(definition)
	return WaveBoardCompositionConfig.build_definition_map(definitions)


func _expect_explicit_pair(
	composition: WaveBoardCompositionConfig,
	definitions_by_id: Dictionary,
	failures: PackedStringArray
) -> void:
	var errors := composition.get_validation_errors(definitions_by_id)
	if not errors.is_empty():
		failures.append("좌우 쌍 기본 배치가 거부됐습니다: %s" % errors)
	var targets := composition.get_resolved_flipper_control_targets(definitions_by_id)
	if targets.size() != 1:
		failures.append("기본 플리퍼는 좌우 쌍 조작 대상 하나여야 합니다: %s" % targets)
		return
	var target := targets[0]
	if target["mode"] != FlipperControlTargetConfig.MODE_PAIR:
		failures.append("기본 플리퍼 조작 대상이 좌우 쌍이 아닙니다.")
	if target["point_ids"] != [&"flipper_left", &"flipper_right"]:
		failures.append("좌우 쌍이 기본 플리퍼 지점 두 개를 함께 참조하지 않습니다.")
	var selected := composition.get_flipper_control_target_for_direction(
		target["direction_id"],
		definitions_by_id
	)
	if selected.get("point_ids", []) != target["point_ids"]:
		failures.append("배정된 방향키로 좌우 쌍 전체를 찾지 못했습니다.")


func _expect_legacy_single_targets(
	composition: WaveBoardCompositionConfig,
	definitions_by_id: Dictionary,
	failures: PackedStringArray
) -> void:
	var legacy := composition.duplicate(true) as WaveBoardCompositionConfig
	legacy.flipper_control_targets.clear()
	var targets := legacy.get_resolved_flipper_control_targets(definitions_by_id)
	if targets.size() != 2:
		failures.append("기존 웨이브 배치의 플리퍼 두 개를 단일 대상으로 해석하지 못했습니다: %s" % [targets])
		return
	var used_modes: Dictionary = {}
	var used_directions: Dictionary = {}
	for target in targets:
		used_modes[target["mode"]] = true
		used_directions[target["direction_id"]] = true
		if (
			target["mode"] == FlipperControlTargetConfig.MODE_LEFT_ONLY
			and target["direction_id"] != BoardLayoutConfig.FLIPPER_DIRECTION_LEFT
		):
			failures.append("기존 왼쪽 플리퍼가 왼쪽 방향키에 배정되지 않았습니다.")
		if (
			target["mode"] == FlipperControlTargetConfig.MODE_RIGHT_ONLY
			and target["direction_id"] != BoardLayoutConfig.FLIPPER_DIRECTION_RIGHT
		):
			failures.append("기존 오른쪽 플리퍼가 오른쪽 방향키에 배정되지 않았습니다.")
	if not used_modes.has(FlipperControlTargetConfig.MODE_LEFT_ONLY):
		failures.append("기존 왼쪽 플리퍼를 왼쪽만 대상으로 해석하지 못했습니다.")
	if not used_modes.has(FlipperControlTargetConfig.MODE_RIGHT_ONLY):
		failures.append("기존 오른쪽 플리퍼를 오른쪽만 대상으로 해석하지 못했습니다.")
	if used_directions.size() != targets.size():
		failures.append("기존 단일 플리퍼 대상에 고유 방향키가 배정되지 않았습니다.")


func _expect_invalid_targets_rejected(
	composition: WaveBoardCompositionConfig,
	definitions_by_id: Dictionary,
	failures: PackedStringArray
) -> void:
	var duplicate := composition.duplicate(true) as WaveBoardCompositionConfig
	var extra := FlipperControlTargetConfig.new()
	extra.set_mode_id(FlipperControlTargetConfig.MODE_LEFT_ONLY)
	extra.left_point_id = &"flipper_left"
	duplicate.flipper_control_targets.append(extra)
	_expect_error(duplicate.get_validation_errors(definitions_by_id), "둘 이상의 조작 대상", failures)

	var missing_side := composition.duplicate(true) as WaveBoardCompositionConfig
	missing_side.flipper_control_targets[0].right_point_id = &""
	_expect_error(missing_side.get_validation_errors(definitions_by_id), "모두 선택", failures)

	var missing_assignment := composition.duplicate(true) as WaveBoardCompositionConfig
	missing_assignment.flipper_control_targets[0].set_mode_id(FlipperControlTargetConfig.MODE_LEFT_ONLY)
	missing_assignment.flipper_control_targets[0].right_point_id = &""
	_expect_error(missing_assignment.get_validation_errors(definitions_by_id), "정확히 하나", failures)

	var swapped_pair := composition.duplicate(true) as WaveBoardCompositionConfig
	swapped_pair.flipper_control_targets[0].left_point_id = &"flipper_right"
	swapped_pair.flipper_control_targets[0].right_point_id = &"flipper_left"
	_expect_error(swapped_pair.get_validation_errors(definitions_by_id), "화면상 왼쪽", failures)


func _expect_four_flipper_mixed_targets(
	composition: WaveBoardCompositionConfig,
	definitions_by_id: Dictionary,
	failures: PackedStringArray
) -> void:
	var mixed := composition.duplicate(true) as WaveBoardCompositionConfig
	var layout := mixed.layout_config.duplicate(true) as BoardLayoutConfig
	for anchor_index in range(layout.anchors.size() - 1, -1, -1):
		if layout.anchors[anchor_index].get_type_id() == BoardAnchorConfig.TYPE_FLIPPER:
			layout.anchors.remove_at(anchor_index)
	var points := {
		&"flipper_bottom_left": Vector2(-0.32, 0.30),
		&"flipper_bottom_right": Vector2(0.32, 0.30),
		&"flipper_top_left": Vector2(-0.12, -0.30),
		&"flipper_top_right": Vector2(0.12, -0.30),
	}
	for point_id in points:
		var point := BoardAnchorConfig.new()
		point.anchor_id = point_id
		point.anchor_type = String(BoardAnchorConfig.TYPE_FLIPPER)
		point.board_position = points[point_id]
		layout.anchors.append(point)
	mixed.layout_config = layout
	for assignment_index in range(mixed.assignments.size() - 1, -1, -1):
		var assignment := mixed.assignments[assignment_index]
		if String(assignment.point_id).begins_with("flipper_"):
			mixed.assignments.remove_at(assignment_index)
	for point_id in points:
		var assignment := BoardPlacementAssignmentConfig.new()
		assignment.point_id = point_id
		assignment.content_id = &"flipper_standard"
		mixed.assignments.append(assignment)
	mixed.flipper_control_targets.clear()
	var left_only := FlipperControlTargetConfig.new()
	left_only.set_mode_id(FlipperControlTargetConfig.MODE_LEFT_ONLY)
	left_only.left_point_id = &"flipper_bottom_left"
	var right_only := FlipperControlTargetConfig.new()
	right_only.set_mode_id(FlipperControlTargetConfig.MODE_RIGHT_ONLY)
	right_only.right_point_id = &"flipper_bottom_right"
	var top_pair := FlipperControlTargetConfig.new()
	top_pair.set_mode_id(FlipperControlTargetConfig.MODE_PAIR)
	top_pair.left_point_id = &"flipper_top_left"
	top_pair.right_point_id = &"flipper_top_right"
	mixed.flipper_control_targets.assign([left_only, right_only, top_pair])
	var errors := mixed.get_validation_errors(definitions_by_id)
	if not errors.is_empty():
		failures.append("플리퍼 4개의 단일·좌우 쌍 혼합 구성이 거부됐습니다: %s" % errors)
		return
	var resolved := mixed.get_resolved_flipper_control_targets(definitions_by_id)
	var directions: Dictionary = {}
	for target in resolved:
		directions[target["direction_id"]] = true
	if resolved.size() != 3 or directions.size() != 3:
		failures.append("플리퍼 4개 혼합 조작 대상 세 개에 고유 방향키가 배정되지 않았습니다: %s" % resolved)


func _expect_error(
	errors: PackedStringArray,
	expected_fragment: String,
	failures: PackedStringArray
) -> void:
	for error in errors:
		if expected_fragment in error:
			return
	failures.append("예상한 한국어 검증 오류가 없습니다: %s / %s" % [expected_fragment, errors])


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("FLIPPER_CONTROL_TARGET_CONFIG_SMOKE: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("FLIPPER_CONTROL_TARGET_CONFIG_SMOKE: %s" % failure)
	quit(1)
