extends SceneTree

const DEFAULT_COMPOSITION_PATH := "res://stages/waves/default_wave_board_composition.tres"
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

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions: Array[BoardPlaceableDefinition] = []
	for path in DEFINITION_PATHS:
		var definition := ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_IGNORE) as BoardPlaceableDefinition
		_expect(definition != null, "오브젝트 원형을 불러오지 못했습니다: %s" % path)
		if definition != null:
			definitions.append(definition)
	var definition_map := WaveBoardCompositionConfig.build_definition_map(definitions)
	var original := ResourceLoader.load(DEFAULT_COMPOSITION_PATH, "Resource", ResourceLoader.CACHE_MODE_IGNORE) as WaveBoardCompositionConfig
	_expect(original != null, "기본 웨이브 배치를 불러오지 못했습니다.")
	if original == null:
		_finish()
		return
	var composition := original.duplicate(true) as WaveBoardCompositionConfig
	var layout := composition.layout_config.duplicate(true) as BoardLayoutConfig
	composition.layout_config = layout
	_add_anchor(layout, &"track_waypoint_01", BoardAnchorConfig.TYPE_TRACK_POINT, Vector2(-0.1, -0.05))
	_add_anchor(layout, &"track_waypoint_02", BoardAnchorConfig.TYPE_TRACK_POINT, Vector2(0.1, 0.05))
	_add_anchor(layout, &"shot_target_01", BoardAnchorConfig.TYPE_SHOT_TARGET, Vector2(0.25, -0.2))
	var track_assignment := composition.get_assignment(&"bumper_top_left")
	var shot_assignment := composition.get_assignment(&"bumper_top_right")
	track_assignment.content_id = &"bumper_track"
	track_assignment.track_point_ids = PackedStringArray(["track_waypoint_01", "track_waypoint_02"])
	shot_assignment.content_id = &"bumper_shot"
	shot_assignment.shot_target_point_id = &"shot_target_01"
	var errors := composition.get_validation_errors(definition_map)
	_expect(errors.is_empty(), "경로·발사 목표를 연결한 웨이브 배치가 거부됐습니다: %s" % errors)
	var placements := composition.get_resolved_placements(definition_map)
	var track_placement := _find_placement(placements, &"bumper_top_left")
	var shot_placement := _find_placement(placements, &"bumper_top_right")
	_expect(track_placement.get("track_path_board_positions", PackedVector2Array()).size() == 2, "경로 지점 순서를 보드 위치로 해석하지 못했습니다.")
	_expect(shot_placement.get("shot_target_board_position", Vector2.INF).is_equal_approx(Vector2(0.25, -0.2)), "발사 목표 지점을 보드 위치로 해석하지 못했습니다.")

	var missing_track := composition.duplicate(true) as WaveBoardCompositionConfig
	missing_track.get_assignment(&"bumper_top_left").track_point_ids = PackedStringArray()
	_expect_error(missing_track.get_validation_errors(definition_map), "경로 지점이 하나 이상", "경로 없는 경로 범퍼를 허용했습니다.")
	var wrong_target := composition.duplicate(true) as WaveBoardCompositionConfig
	wrong_target.get_assignment(&"bumper_top_right").shot_target_point_id = &"track_waypoint_01"
	_expect_error(wrong_target.get_validation_errors(definition_map), "발사 목표 지점만", "잘못된 역할의 발사 목표를 허용했습니다.")
	var unnecessary_path := composition.duplicate(true) as WaveBoardCompositionConfig
	unnecessary_path.get_assignment(&"bumper_top_left").content_id = &"bumper_normal"
	_expect_error(unnecessary_path.get_validation_errors(definition_map), "경로 범퍼가 아닌", "일반 범퍼에 불필요한 경로 연결을 허용했습니다.")
	_expect(original.layout_config.get_anchor(&"track_waypoint_01") == null, "복제본 시험이 기본 보드 설계도를 변경했습니다.")
	_finish()


func _add_anchor(layout: BoardLayoutConfig, id: StringName, type: StringName, position: Vector2) -> void:
	var anchor := BoardAnchorConfig.new()
	anchor.anchor_id = id
	anchor.anchor_type = String(type)
	anchor.board_position = position
	layout.anchors.append(anchor)


func _find_placement(placements: Array[Dictionary], point_id: StringName) -> Dictionary:
	for placement in placements:
		if placement.get("point_id", &"") == point_id:
			return placement
	return {}


func _expect_error(errors: PackedStringArray, fragment: String, message: String) -> void:
	for error in errors:
		if fragment in error:
			return
	_failures.append("%s: %s" % [message, errors])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BUMPER_BOARD_ASSIGNMENT_SMOKE: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("BUMPER_BOARD_ASSIGNMENT_SMOKE: %s" % failure)
	quit(1)
