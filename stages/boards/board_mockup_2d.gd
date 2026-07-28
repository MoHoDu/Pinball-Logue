@tool
class_name BoardMockup2D
extends Node2D

@export var layout_config: BoardLayoutConfig
@export var view_config: BoardViewConfig
@export var composition_config: WaveBoardCompositionConfig
@export var object_definitions: Array[BoardPlaceableDefinition] = []
@export var presentation_catalog: BoardObjectPresentation2DCatalog
@export var show_boss := false

var _preview_signature := 0
var _preview_container: Node2D


func _ready() -> void:
	_ensure_preview_container()
	_rebuild_object_previews()
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		var current_signature := _get_preview_signature()
		if current_signature != _preview_signature:
			_rebuild_object_previews()
		queue_redraw()


func _draw() -> void:
	if not get_assembly_errors().is_empty():
		return

	var polygon := get_projected_boundary()
	draw_colored_polygon(polygon, view_config.board_color)
	var closed_outline := PackedVector2Array(polygon)
	closed_outline.append(polygon[0])
	draw_polyline(closed_outline, view_config.rail_color, view_config.rail_width, true)
	if composition_config == null:
		_draw_bumpers()
		_draw_flippers()
	_draw_relic_slots()
	_draw_empty_object_points()
	_draw_drain()
	if show_boss:
		_draw_boss()
	else:
		_draw_launch_marker()


func get_assembly_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if layout_config == null:
		errors.append("BoardMockup2D에 BoardLayoutConfig가 없습니다.")
	else:
		errors.append_array(layout_config.get_validation_errors())
	if view_config == null:
		errors.append("BoardMockup2D에 BoardViewConfig가 없습니다.")
	else:
		errors.append_array(view_config.get_validation_errors())
	if composition_config != null:
		errors.append_array(
			WaveBoardCompositionConfig.get_definition_catalog_validation_errors(
				object_definitions
			)
		)
		var definitions_by_id := _get_definitions_by_id()
		errors.append_array(composition_config.get_validation_errors(definitions_by_id))
		if composition_config.layout_config != layout_config:
			errors.append("웨이브 배치와 보드 목업이 같은 보드 템플릿을 사용해야 합니다.")
		if presentation_catalog == null:
			errors.append("현재 2D 디자인 연결표가 없습니다.")
		else:
			errors.append_array(presentation_catalog.get_validation_errors())
			for assignment in composition_config.assignments:
				if assignment != null and assignment.content_id != &"" and presentation_catalog.get_scene(assignment.content_id) == null:
					errors.append("오브젝트 원형에 연결된 2D 디자인이 없습니다: %s" % assignment.content_id)
	return errors


func is_assembly_valid() -> bool:
	return get_assembly_errors().is_empty()


func get_projected_boundary() -> PackedVector2Array:
	if layout_config == null or view_config == null:
		return PackedVector2Array()
	return view_config.project_board_polygon(layout_config.boundary_points)


func get_projected_anchor_position(anchor_id: StringName) -> Vector2:
	if layout_config == null or view_config == null:
		return Vector2(INF, INF)
	var anchor := layout_config.get_anchor(anchor_id)
	if anchor == null:
		return Vector2(INF, INF)
	return view_config.project_board_point(layout_config.get_resolved_anchor_position(anchor))


func get_projected_anchor_direction(anchor_id: StringName) -> Vector2:
	if layout_config == null or view_config == null:
		return Vector2(INF, INF)
	var anchor := layout_config.get_anchor(anchor_id)
	if anchor == null:
		return Vector2(INF, INF)
	var resolved_position := layout_config.get_resolved_anchor_position(anchor)
	if anchor.get_type_id() == BoardAnchorConfig.TYPE_FLIPPER and anchor.snap_to_boundary:
		var board_direction := layout_config.get_resolved_flipper_direction(anchor)
		var projected_origin := view_config.project_board_point(resolved_position)
		var projected_target := view_config.project_board_point(resolved_position + board_direction * 0.01)
		return projected_origin.direction_to(projected_target)
	return view_config.project_board_direction(resolved_position, anchor.rotation_degrees)


func get_projected_anchor_positions(anchor_type: StringName) -> Dictionary:
	var projected_positions: Dictionary = {}
	if layout_config == null or view_config == null:
		return projected_positions
	for anchor in layout_config.get_anchors_by_type(anchor_type):
		projected_positions[anchor.anchor_id] = view_config.project_board_point(
			layout_config.get_resolved_anchor_position(anchor)
		)
	return projected_positions


func get_composition_config() -> WaveBoardCompositionConfig:
	return composition_config


func apply_composition_config(config: WaveBoardCompositionConfig) -> void:
	composition_config = config
	_rebuild_object_previews()
	queue_redraw()


func get_definitions_by_id() -> Dictionary:
	return _get_definitions_by_id()


func get_object_definition(content_id: StringName) -> BoardPlaceableDefinition:
	return _get_definitions_by_id().get(content_id) as BoardPlaceableDefinition


func set_flipper_previews_visible(is_visible: bool) -> void:
	_ensure_preview_container()
	if layout_config == null:
		return
	for preview in _preview_container.get_children():
		var point_id := StringName(preview.get_meta("board_point_id", ""))
		var point := layout_config.get_anchor(point_id)
		if point != null and point.get_type_id() == BoardAnchorConfig.TYPE_FLIPPER:
			preview.visible = is_visible


func _draw_bumpers() -> void:
	for anchor in layout_config.get_anchors_by_type(BoardAnchorConfig.TYPE_BUMPER):
		var bumper_position := view_config.project_board_point(anchor.board_position)
		draw_circle(bumper_position, view_config.bumper_radius, view_config.rail_color)
		draw_circle(bumper_position, view_config.bumper_inner_radius, view_config.bumper_color)


func _draw_flippers() -> void:
	for anchor in layout_config.get_anchors_by_type(BoardAnchorConfig.TYPE_FLIPPER):
		var pivot_position := view_config.project_board_point(anchor.board_position)
		var direction := get_projected_anchor_direction(anchor.anchor_id)
		var normal := direction.orthogonal() * view_config.flipper_width * 0.5
		var tip_position := pivot_position + direction * view_config.flipper_length
		var flipper_points := PackedVector2Array([
			pivot_position - normal,
			tip_position - normal,
			tip_position + normal,
			pivot_position + normal,
		])
		draw_colored_polygon(flipper_points, view_config.accent_color)
		draw_circle(pivot_position, view_config.flipper_pivot_radius, view_config.bumper_color)


func _draw_relic_slots() -> void:
	for anchor in layout_config.get_anchors_by_type(BoardAnchorConfig.TYPE_RELIC_SLOT):
		var slot_position := view_config.project_board_point(anchor.board_position)
		draw_circle(slot_position, view_config.relic_slot_radius, Color(view_config.lane_color, 0.28))
		draw_arc(
			slot_position,
			view_config.relic_slot_radius,
			0.0,
			TAU,
			24,
			view_config.lane_color,
			3.0,
			true
		)


func _draw_empty_object_points() -> void:
	for anchor in layout_config.get_anchors_by_type(BoardAnchorConfig.TYPE_OBJECT):
		if composition_config != null and composition_config.get_assignment(anchor.anchor_id) != null:
			continue
		var point_position := view_config.project_board_point(anchor.board_position)
		draw_rect(
			Rect2(point_position - Vector2(10.0, 10.0), Vector2(20.0, 20.0)),
			Color(view_config.lane_color, 0.18),
			true
		)
		draw_rect(
			Rect2(point_position - Vector2(10.0, 10.0), Vector2(20.0, 20.0)),
			view_config.lane_color,
			false,
			2.0
		)


func _draw_drain() -> void:
	var drain_position := get_projected_anchor_position(layout_config.drain_anchor_id)
	var half_width := view_config.drain_width * 0.5
	draw_line(
		drain_position - Vector2(half_width, 0.0),
		drain_position + Vector2(half_width, 0.0),
		view_config.accent_color,
		6.0,
		true
	)


func _draw_launch_marker() -> void:
	var launch_position := get_projected_anchor_position(layout_config.launch_anchor_id)
	draw_circle(
		launch_position,
		view_config.launch_marker_radius,
		Color(view_config.lane_color, 0.24)
	)
	draw_arc(
		launch_position,
		view_config.launch_marker_radius,
		0.0,
		TAU,
		24,
		view_config.lane_color,
		3.0,
		true
	)
	draw_line(
		launch_position - Vector2(view_config.launch_marker_radius * 0.55, 0.0),
		launch_position + Vector2(view_config.launch_marker_radius * 0.55, 0.0),
		view_config.lane_color,
		2.0,
		true
	)
	draw_line(
		launch_position - Vector2(0.0, view_config.launch_marker_radius * 0.55),
		launch_position + Vector2(0.0, view_config.launch_marker_radius * 0.55),
		view_config.lane_color,
		2.0,
		true
	)


func _draw_boss() -> void:
	var boss_preview_position := view_config.project_board_point(Vector2(0.0, -0.16))
	draw_circle(boss_preview_position, 52.0, view_config.accent_color)
	draw_circle(boss_preview_position, 36.0, Color("7c241f"))


func _get_definitions_by_id() -> Dictionary:
	return WaveBoardCompositionConfig.build_definition_map(object_definitions)


func _ensure_preview_container() -> void:
	if is_instance_valid(_preview_container):
		return
	_preview_container = Node2D.new()
	_preview_container.name = "EditorObjectPreviews"
	_preview_container.set_meta("editor_generated_preview", true)
	add_child(_preview_container)


func _clear_object_previews() -> void:
	_ensure_preview_container()
	for preview in _preview_container.get_children():
		_preview_container.remove_child(preview)
		preview.queue_free()


func _rebuild_object_previews() -> void:
	_clear_object_previews()
	_preview_signature = _get_preview_signature()
	if composition_config == null or presentation_catalog == null:
		return
	var definitions_by_id := _get_definitions_by_id()
	if not composition_config.get_validation_errors(definitions_by_id).is_empty():
		return
	if not presentation_catalog.get_validation_errors().is_empty():
		return
	for placement in composition_config.get_resolved_placements(definitions_by_id):
		var content_id: StringName = placement["content_id"]
		var preview_scene := presentation_catalog.get_scene(content_id)
		if preview_scene == null:
			continue
		var preview_instance := preview_scene.instantiate()
		if not preview_instance is Node2D:
			preview_instance.free()
			continue
		var point := placement["point"] as BoardAnchorConfig
		var board_position: Vector2 = placement["board_position"]
		preview_instance.position = view_config.project_board_point(board_position)
		if point.get_type_id() == BoardAnchorConfig.TYPE_FLIPPER:
			preview_instance.rotation = get_projected_anchor_direction(point.anchor_id).angle()
		else:
			preview_instance.rotation = view_config.project_board_direction(
				board_position,
				point.rotation_degrees
			).angle()
		preview_instance.set_meta("board_point_id", point.anchor_id)
		_preview_container.add_child(preview_instance)


func _get_preview_signature() -> int:
	var signature_parts: Array = [layout_config, view_config, composition_config, presentation_catalog]
	if layout_config != null:
		signature_parts.append(layout_config.boundary_points)
		for anchor in layout_config.anchors:
			if anchor == null:
				signature_parts.append("null")
				continue
			signature_parts.append([
				anchor.anchor_id,
				anchor.anchor_type,
				anchor.board_position,
				anchor.rotation_degrees,
				anchor.snap_to_boundary,
				anchor.boundary_edge_index,
				anchor.boundary_edge_offset,
			])
	if composition_config != null:
		for assignment in composition_config.assignments:
			if assignment != null:
				signature_parts.append([assignment.point_id, assignment.content_id])
	return hash(signature_parts)
