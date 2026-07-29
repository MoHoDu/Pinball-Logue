extends SceneTree

const AUTHORING_SCENE_PATH := "res://stages/boards/board_authoring_2d.tscn"
const DEFAULT_LAYOUT_PATH := "res://stages/boards/default_board_layout_config.tres"
const DEFAULT_COMPOSITION_PATH := "res://stages/waves/default_wave_board_composition.tres"
const CURRENT_COMPOSITION_PATH := "res://stages/waves/current_wave_board_composition.tres"
const PRESENTATION_CATALOG_PATH := "res://stages/boards/default_board_presentation_catalog_2d.tres"
const FLOAT_EPSILON := 0.001

const DEFINITION_PATHS := [
	"res://pinball/objects/normal_bumper_definition.tres",
	"res://pinball/objects/bounce_bumper_definition.tres",
	"res://pinball/objects/track_bumper_definition.tres",
	"res://pinball/objects/shot_bumper_definition.tres",
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
	var definitions := _load_definitions(failures)
	var definition_map := WaveBoardCompositionConfig.build_definition_map(definitions)
	_expect_definitions(definitions, definition_map, failures)
	_expect_composition(DEFAULT_COMPOSITION_PATH, definition_map, failures)
	_expect_composition(CURRENT_COMPOSITION_PATH, definition_map, failures)
	_expect_presentation_catalog(failures)
	_expect_authoring_scene(failures)
	_expect_point_and_assignment_separation(definitions, failures)
	_expect_flipper_boundary_attachment(failures)
	_expect_projection_round_trip(failures)
	_expect_invalid_assignment(definition_map, failures)
	_expect_logic_dimension_independence(failures)
	_finish(failures)


func _load_definitions(failures: PackedStringArray) -> Array[BoardPlaceableDefinition]:
	var definitions: Array[BoardPlaceableDefinition] = []
	for path in DEFINITION_PATHS:
		var definition := ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_IGNORE) as BoardPlaceableDefinition
		if definition == null:
			failures.append("오브젝트 원형을 불러오지 못했습니다: %s" % path)
			continue
		definitions.append(definition)
	return definitions


func _expect_definitions(
	definitions: Array[BoardPlaceableDefinition],
	definition_map: Dictionary,
	failures: PackedStringArray
) -> void:
	if definitions.size() != DEFINITION_PATHS.size():
		failures.append("기본 오브젝트 원형은 %d개여야 합니다." % DEFINITION_PATHS.size())
	if definition_map.size() != definitions.size():
		failures.append("오브젝트 원형 ID가 비었거나 중복됩니다.")
	for definition in definitions:
		failures.append_array(definition.get_validation_errors())
	var normal := definition_map.get(&"bumper_normal") as BumperDefinition
	var bounce := definition_map.get(&"bumper_bounce") as BumperDefinition
	var track := definition_map.get(&"bumper_track") as BumperDefinition
	var shot := definition_map.get(&"bumper_shot") as BumperDefinition
	if normal == null or normal.get_bumper_type_id() != BumperDefinition.BUMPER_TYPE_NORMAL:
		failures.append("일반 범퍼 원형의 범퍼 종류가 올바르지 않습니다.")
	if bounce == null or bounce.get_bumper_type_id() != BumperDefinition.BUMPER_TYPE_BOUNCE:
		failures.append("바운스 범퍼 원형의 범퍼 종류가 올바르지 않습니다.")
	if track == null or track.get_bumper_type_id() != BumperDefinition.BUMPER_TYPE_TRACK:
		failures.append("경로 범퍼 원형의 범퍼 종류가 올바르지 않습니다.")
	if shot == null or shot.get_bumper_type_id() != BumperDefinition.BUMPER_TYPE_SHOT:
		failures.append("발사 범퍼 원형의 범퍼 종류가 올바르지 않습니다.")


func _expect_composition(
	path: String,
	definition_map: Dictionary,
	failures: PackedStringArray
) -> void:
	var composition := ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_IGNORE) as WaveBoardCompositionConfig
	if composition == null:
		failures.append("웨이브 배치를 불러오지 못했습니다: %s" % path)
		return
	var errors := composition.get_validation_errors(definition_map)
	if not errors.is_empty():
		failures.append("웨이브 배치가 유효하지 않습니다: %s / %s" % [path, errors])
	if composition.assignments.is_empty():
		failures.append("웨이브 배치에 실제 오브젝트가 하나도 없습니다: %s" % path)
	if composition.get_resolved_placements(definition_map).size() != composition.assignments.size():
		failures.append("웨이브 배치가 모든 오브젝트를 해석하지 못했습니다: %s" % path)


func _expect_presentation_catalog(failures: PackedStringArray) -> void:
	var catalog := ResourceLoader.load(
		PRESENTATION_CATALOG_PATH,
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as BoardObjectPresentation2DCatalog
	if catalog == null:
		failures.append("현재 2D 디자인 연결표를 불러오지 못했습니다.")
		return
	failures.append_array(catalog.get_validation_errors())
	for path in DEFINITION_PATHS:
		var definition := ResourceLoader.load(path) as BoardPlaceableDefinition
		if definition != null and catalog.get_scene(definition.content_id) == null:
			failures.append("오브젝트 원형의 현재 2D 디자인이 없습니다: %s" % definition.content_id)


func _expect_authoring_scene(failures: PackedStringArray) -> void:
	var packed := ResourceLoader.load(AUTHORING_SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		failures.append("보드 제작 씬을 불러오지 못했습니다.")
		return
	var board := packed.instantiate() as BoardMockup2D
	if board == null:
		failures.append("보드 제작 씬의 루트가 BoardMockup2D가 아닙니다.")
		return
	var errors := board.get_assembly_errors()
	if not errors.is_empty():
		failures.append("보드 제작 씬이 유효하지 않습니다: %s" % errors)
	if board.object_definitions.size() != DEFINITION_PATHS.size():
		failures.append("보드 제작 씬에 기본 오브젝트 원형이 모두 연결되지 않았습니다.")
	board.free()


func _expect_point_and_assignment_separation(
	definitions: Array[BoardPlaceableDefinition],
	failures: PackedStringArray
) -> void:
	var layout := ResourceLoader.load(DEFAULT_LAYOUT_PATH, "Resource", ResourceLoader.CACHE_MODE_IGNORE) as BoardLayoutConfig
	var composition := ResourceLoader.load(DEFAULT_COMPOSITION_PATH, "Resource", ResourceLoader.CACHE_MODE_IGNORE) as WaveBoardCompositionConfig
	if layout == null or composition == null:
		return
	var layout_copy := layout.duplicate(true) as BoardLayoutConfig
	var empty_point := BoardAnchorConfig.new()
	empty_point.anchor_id = &"object_empty_test"
	empty_point.anchor_type = "object"
	empty_point.board_position = Vector2(0.1, 0.05)
	layout_copy.anchors.append(empty_point)
	if not layout_copy.get_validation_errors().is_empty():
		failures.append("실제 오브젝트가 없는 빈 배치 지점이 거부됐습니다.")
	var composition_copy := composition.duplicate(true) as WaveBoardCompositionConfig
	composition_copy.layout_config = layout_copy
	var definitions_by_id := WaveBoardCompositionConfig.build_definition_map(definitions)
	if not composition_copy.get_validation_errors(definitions_by_id).is_empty():
		failures.append("빈 배치 지점을 추가한 웨이브 배치가 거부됐습니다.")


func _expect_flipper_boundary_attachment(failures: PackedStringArray) -> void:
	var layout := ResourceLoader.load(DEFAULT_LAYOUT_PATH, "Resource", ResourceLoader.CACHE_MODE_IGNORE) as BoardLayoutConfig
	if layout == null:
		return
	var copy := layout.duplicate(true) as BoardLayoutConfig
	var flipper := copy.get_anchor(&"flipper_left")
	if not copy.snap_flipper_anchor_to_boundary(flipper, Vector2(-0.47, 0.1)):
		failures.append("플리퍼 지점을 외곽선에 붙이지 못했습니다.")
		return
	var resolved := copy.get_resolved_anchor_position(flipper)
	if not copy.is_board_position_in_bounds(resolved):
		failures.append("외곽선에 붙인 플리퍼가 보드 경계를 벗어났습니다.")
	if copy.get_resolved_flipper_direction(flipper) == Vector2.ZERO:
		failures.append("외곽선 플리퍼의 보드 안쪽 방향을 계산하지 못했습니다.")
	copy.boundary_points[3] = Vector2(-0.4, 0.5)
	var moved_boundary_position := copy.get_resolved_anchor_position(flipper)
	if not copy.is_board_position_in_bounds(moved_boundary_position):
		failures.append("외곽선을 수정한 뒤 플리퍼가 경계에서 떨어졌습니다.")


func _expect_projection_round_trip(failures: PackedStringArray) -> void:
	var view := ResourceLoader.load(
		"res://stages/boards/default_board_view_config.tres",
		"Resource",
		ResourceLoader.CACHE_MODE_IGNORE
	) as BoardViewConfig
	if view == null:
		return
	for board_position in [Vector2(-0.42, -0.33), Vector2.ZERO, Vector2(0.37, 0.41)]:
		var round_trip := view.unproject_board_point(view.project_board_point(board_position))
		if round_trip.distance_to(board_position) > FLOAT_EPSILON:
			failures.append("58° 제작 화면의 좌표 역변환 오차가 허용값을 넘었습니다: %s" % board_position)


func _expect_invalid_assignment(definition_map: Dictionary, failures: PackedStringArray) -> void:
	var composition := ResourceLoader.load(DEFAULT_COMPOSITION_PATH, "Resource", ResourceLoader.CACHE_MODE_IGNORE) as WaveBoardCompositionConfig
	if composition == null:
		return
	var invalid := composition.duplicate(true) as WaveBoardCompositionConfig
	invalid.assignments[0].content_id = &"flipper_standard"
	_expect_error(invalid.get_validation_errors(definition_map), "역할과 오브젝트 종류", failures)


func _expect_logic_dimension_independence(failures: PackedStringArray) -> void:
	var logic_paths := PackedStringArray([
		"res://shared/contracts/board_placeable_definition.gd",
		"res://pinball/objects/bumper_definition.gd",
		"res://pinball/objects/bumper_contact_lock.gd",
		"res://pinball/objects/bumper_hit_request.gd",
		"res://pinball/objects/bumper_hit_result.gd",
		"res://pinball/objects/bumper_runtime_state.gd",
		"res://pinball/objects/bumper_effect_resolver.gd",
		"res://pinball/flippers/flipper_definition.gd",
		"res://relics/catalog/relic_definition.gd",
		"res://stages/boards/board_anchor_config.gd",
		"res://stages/boards/board_layout_config.gd",
		"res://stages/waves/board_placement_assignment_config.gd",
		"res://stages/waves/wave_board_composition_config.gd",
	])
	for path in logic_paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			failures.append("차원 독립 계약 파일을 읽지 못했습니다: %s" % path)
			continue
		var source := file.get_as_text()
		for forbidden in ["Node2D", "Node3D", "PackedScene", ".tscn"]:
			if forbidden in source:
				failures.append("차원 독립 계약에 표현 참조가 있습니다: %s / %s" % [path, forbidden])


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
		print("BOARD_AUTHORING_CONTRACT_SMOKE: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("BOARD_AUTHORING_CONTRACT_SMOKE: %s" % failure)
	quit(1)
