@tool
extends EditorPlugin

enum EditMode {
	NONE,
	BOUNDARY,
	POINT,
}

enum MenuAction {
	DUPLICATE_LAYOUT = 1,
	EDIT_BOUNDARY,
	ADD_BUMPER,
	ADD_GENERAL_OBJECT,
	ADD_RELIC_SLOT,
	ADD_FLIPPER,
	DELETE_POINT,
	CHECK_ERRORS,
}

const HANDLE_RADIUS := 8.0
const HANDLE_HIT_RADIUS := 14.0
const MAX_FLIPPER_COUNT := 4
const FALLBACK_ANCHOR_SCRIPT_PATH := "res://stages/boards/board_anchor_config.gd"
const ASSIGNMENT_SCRIPT_PATH := "res://stages/waves/board_placement_assignment_config.gd"

var _edited_node: Node2D
var _edit_mode := EditMode.NONE
var _selected_anchor_index := -1
var _last_board_position := Vector2.ZERO
var _drag_kind := ""
var _drag_index := -1
var _drag_start_value: Variant
var _dock: VBoxContainer
var _toolbar: HBoxContainer
var _toolbar_menu: MenuButton
var _status_label: Label
var _definition_option: OptionButton
var _definition_detail_label: Label
var _save_dialog: FileDialog
var _message_dialog: AcceptDialog
var _undo_redo: EditorUndoRedoManager


func _enter_tree() -> void:
	_undo_redo = get_undo_redo()
	_build_dock()
	_build_toolbar()
	if _undo_redo != null and _undo_redo.has_signal("version_changed"):
		_undo_redo.connect("version_changed", _on_undo_redo_version_changed)
	_refresh_definition_options()
	_update_status()


func _exit_tree() -> void:
	if _undo_redo != null and _undo_redo.has_signal("version_changed"):
		var callback := Callable(self, "_on_undo_redo_version_changed")
		if _undo_redo.is_connected("version_changed", callback):
			_undo_redo.disconnect("version_changed", callback)
	if _toolbar != null:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
	if is_instance_valid(_save_dialog):
		_save_dialog.queue_free()
	if is_instance_valid(_message_dialog):
		_message_dialog.queue_free()
	_edited_node = null


func _handles(object: Object) -> bool:
	return object is Node2D and _has_property(object, &"layout_config")


func _edit(object: Object) -> void:
	_cancel_drag()
	_edited_node = object as Node2D if _handles(object) else null
	_selected_anchor_index = -1
	_refresh_definition_options()
	_update_status()
	update_overlays()


func _make_visible(visible: bool) -> void:
	if _toolbar != null:
		_toolbar.visible = visible
	if not visible:
		_cancel_drag()


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not _has_editable_layout():
		return
	var assembly_errors := _collect_errors()
	if not assembly_errors.is_empty():
		overlay.draw_rect(Rect2(16.0, 16.0, 390.0, 38.0), Color(0.25, 0.03, 0.04, 0.92), true)
		overlay.draw_string(
			ThemeDB.fallback_font,
			Vector2(28.0, 41.0),
			"보드 오류 %d개 — 제작 도구의 '오류 확인'을 눌러 해결하세요." % assembly_errors.size(),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			ThemeDB.fallback_font_size,
			Color("ffd7d7")
		)
	var transform := _get_canvas_transform()
	var boundary := _get_boundary_points()
	if boundary.size() >= 2:
		var screen_boundary := PackedVector2Array()
		for board_point in boundary:
			screen_boundary.append(transform * _project_board_position(board_point))
		screen_boundary.append(screen_boundary[0])
		var boundary_color := Color("61dafb")
		if not assembly_errors.is_empty():
			boundary_color = Color("ff6b6b")
		overlay.draw_polyline(screen_boundary, boundary_color, 2.0, true)
		if _edit_mode == EditMode.BOUNDARY:
			for point_index in boundary.size():
				var handle_position := transform * _project_board_position(boundary[point_index])
				overlay.draw_circle(handle_position, HANDLE_RADIUS, Color("f4d35e"))
				overlay.draw_circle(handle_position, HANDLE_RADIUS, Color("6b4f00"), false, 2.0, true)

	var anchors := _get_anchors()
	for anchor_index in anchors.size():
		var anchor: Object = anchors[anchor_index]
		if anchor == null or not _has_property(anchor, &"board_position"):
			continue
		var anchor_position := _get_resolved_anchor_position(anchor)
		var screen_position := transform * _project_board_position(anchor_position)
		var anchor_type := _get_anchor_type(anchor)
		var fill_color := _get_anchor_color(anchor_type)
		if _anchor_has_error(anchor, assembly_errors):
			fill_color = Color("ff3b4d")
		var radius := HANDLE_RADIUS + 2.0 if anchor_index == _selected_anchor_index else HANDLE_RADIUS
		overlay.draw_circle(screen_position, radius, fill_color)
		overlay.draw_circle(screen_position, radius, Color("102a30"), false, 2.0, true)
		if _edit_mode == EditMode.POINT or anchor_index == _selected_anchor_index:
			var label := _get_anchor_label(anchor, anchor_index)
			overlay.draw_string(
				ThemeDB.fallback_font,
				screen_position + Vector2(12.0, -10.0),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				ThemeDB.fallback_font_size,
				Color("f3f7f8")
			)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not _has_editable_layout() or _edit_mode == EditMode.NONE:
		return false
	if event is InputEventMouseMotion:
		_last_board_position = _screen_to_board_position(event.position)
		if _drag_kind != "":
			_update_drag(_last_board_position)
			return true
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_last_board_position = _screen_to_board_position(event.position)
		if event.pressed:
			if _edit_mode == EditMode.BOUNDARY:
				var boundary_index := _find_boundary_handle(event.position)
				if boundary_index >= 0:
					_begin_boundary_drag(boundary_index)
					return true
			elif _edit_mode == EditMode.POINT:
				var anchor_index := _find_anchor_handle(event.position)
				if anchor_index >= 0:
					_selected_anchor_index = anchor_index
					_begin_anchor_drag(anchor_index)
					_refresh_definition_options()
					_update_status()
					update_overlays()
					return true
		elif _drag_kind != "":
			_finish_drag()
			return true
	return false


func _build_dock() -> void:
	_dock = VBoxContainer.new()
	_dock.name = "보드 제작 도구"
	var title := Label.new()
	title.text = "보드 제작 도구"
	title.add_theme_font_size_override("font_size", 18)
	_dock.add_child(title)
	var help := Label.new()
	help.text = "보드 씬을 선택한 뒤 복제본에서 작업하세요.\n노란 점은 외곽선, 색상 점은 배치 지점입니다."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock.add_child(help)
	_add_dock_button("복제해서 새 보드 만들기", _on_duplicate_requested)
	_add_dock_button("외곽선 편집", _on_boundary_mode_requested)
	_add_dock_button("범퍼 지점 추가", _on_add_bumper_requested)
	_add_dock_button("일반 오브젝트 지점 추가", _on_add_general_object_requested)
	_add_dock_button("유물 배치 지점 추가", _on_add_relic_slot_requested)
	_add_dock_button("플리퍼 추가", _on_add_flipper_requested)
	_add_dock_button("선택 지점 삭제", _on_delete_point_requested)
	var placement_separator := HSeparator.new()
	_dock.add_child(placement_separator)
	var placement_title := Label.new()
	placement_title.text = "선택 지점의 웨이브 배치"
	_dock.add_child(placement_title)
	_definition_option = OptionButton.new()
	_definition_option.tooltip_text = "선택 지점 역할과 맞는 오브젝트 원형만 표시합니다. 실제 프리팹은 2D 디자인 연결표가 결정합니다."
	_definition_option.item_selected.connect(_on_definition_selected)
	_dock.add_child(_definition_option)
	_add_dock_button("선택 지점에 원형 적용", _on_apply_definition_requested)
	_add_dock_button("배치 비우기", _on_clear_assignment_requested)
	_definition_detail_label = Label.new()
	_definition_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_definition_detail_label.custom_minimum_size = Vector2(260.0, 74.0)
	_dock.add_child(_definition_detail_label)
	_add_dock_button("오류 확인", _on_check_errors_requested)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(260.0, 88.0)
	_dock.add_child(_status_label)

	_save_dialog = FileDialog.new()
	_save_dialog.title = "복제한 보드 설계도 저장"
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_dialog.filters = PackedStringArray(["*.tres ; Godot Resource"])
	_save_dialog.file_selected.connect(_on_duplicate_file_selected)
	get_editor_interface().get_base_control().add_child(_save_dialog)

	_message_dialog = AcceptDialog.new()
	_message_dialog.title = "보드 제작 도구"
	get_editor_interface().get_base_control().add_child(_message_dialog)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _build_toolbar() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar_menu = MenuButton.new()
	_toolbar_menu.text = "보드 제작"
	var popup := _toolbar_menu.get_popup()
	popup.add_item("복제해서 새 보드 만들기", MenuAction.DUPLICATE_LAYOUT)
	popup.add_separator()
	popup.add_item("외곽선 편집", MenuAction.EDIT_BOUNDARY)
	popup.add_item("범퍼 지점 추가", MenuAction.ADD_BUMPER)
	popup.add_item("일반 오브젝트 지점 추가", MenuAction.ADD_GENERAL_OBJECT)
	popup.add_item("유물 배치 지점 추가", MenuAction.ADD_RELIC_SLOT)
	popup.add_item("플리퍼 추가", MenuAction.ADD_FLIPPER)
	popup.add_item("선택 지점 삭제", MenuAction.DELETE_POINT)
	popup.add_separator()
	popup.add_item("오류 확인", MenuAction.CHECK_ERRORS)
	popup.id_pressed.connect(_on_toolbar_action)
	_toolbar.add_child(_toolbar_menu)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)


func _add_dock_button(label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	_dock.add_child(button)


func _on_toolbar_action(action_id: int) -> void:
	match action_id:
		MenuAction.DUPLICATE_LAYOUT: _on_duplicate_requested()
		MenuAction.EDIT_BOUNDARY: _on_boundary_mode_requested()
		MenuAction.ADD_BUMPER: _on_add_bumper_requested()
		MenuAction.ADD_GENERAL_OBJECT: _on_add_general_object_requested()
		MenuAction.ADD_RELIC_SLOT: _on_add_relic_slot_requested()
		MenuAction.ADD_FLIPPER: _on_add_flipper_requested()
		MenuAction.DELETE_POINT: _on_delete_point_requested()
		MenuAction.CHECK_ERRORS: _on_check_errors_requested()


func _on_duplicate_requested() -> void:
	if not _require_layout():
		return
	_save_dialog.current_dir = "res://stages/boards"
	_save_dialog.current_file = "new_board_layout_config.tres"
	_save_dialog.popup_centered_ratio(0.65)


func _on_duplicate_file_selected(path: String) -> void:
	var layout := _get_layout()
	if layout == null:
		_show_message("복제할 보드 설계도를 찾지 못했습니다.")
		return
	var save_path := path if path.ends_with(".tres") else path + ".tres"
	var duplicate_layout: Resource = layout.duplicate(true)
	var save_error := ResourceSaver.save(duplicate_layout, save_path)
	if save_error != OK:
		_show_message("보드 설계도 복제에 실패했습니다.\n저장 경로와 파일 권한을 확인하세요.\n오류 코드: %d" % save_error)
		return
	var original_composition := _get_composition_config()
	var duplicate_composition: Resource
	var composition_save_path := ""
	if original_composition != null:
		duplicate_composition = original_composition.duplicate(true)
		duplicate_composition.set("layout_config", duplicate_layout)
		composition_save_path = save_path.get_basename() + "_wave_composition.tres"
		var composition_save_error := ResourceSaver.save(
			duplicate_composition,
			composition_save_path
		)
		if composition_save_error != OK:
			_show_message(
				"보드 설계도는 저장했지만 웨이브 배치 복제에 실패했습니다.\n"
				+ "오류 코드: %d" % composition_save_error
			)
			return
	_undo_redo.create_action("보드 설계도와 웨이브 배치 함께 복제")
	_undo_redo.add_do_property(_edited_node, &"layout_config", duplicate_layout)
	_undo_redo.add_undo_property(_edited_node, &"layout_config", layout)
	if original_composition != null:
		_undo_redo.add_do_property(
			_edited_node,
			&"composition_config",
			duplicate_composition
		)
		_undo_redo.add_undo_property(
			_edited_node,
			&"composition_config",
			original_composition
		)
	_undo_redo.commit_action()
	var saved_paths := save_path
	if not composition_save_path.is_empty():
		saved_paths += "\n" + composition_save_path
	_show_message(
		"새 보드 설계도와 웨이브 배치를 함께 만들고 현재 씬에 연결했습니다.\n%s"
		% saved_paths
	)
	_update_status()
	update_overlays()


func _on_boundary_mode_requested() -> void:
	if not _require_layout():
		return
	_edit_mode = EditMode.BOUNDARY
	_selected_anchor_index = -1
	_update_status()
	update_overlays()


func _on_add_bumper_requested() -> void:
	_add_anchor("bumper", "bumper")


func _on_add_general_object_requested() -> void:
	_add_anchor("object", "object")


func _on_add_relic_slot_requested() -> void:
	_add_anchor("relic_slot", "relic")


func _on_add_flipper_requested() -> void:
	if _count_anchors_by_type("flipper") >= MAX_FLIPPER_COUNT:
		_show_message("한 웨이브에는 플리퍼를 최대 4개까지 배치할 수 있습니다.\n기존 플리퍼 지점을 삭제한 뒤 다시 시도하세요.")
		return
	_add_anchor("flipper", "flipper")


func _on_delete_point_requested() -> void:
	if not _require_layout():
		return
	var anchors := _get_anchors()
	if _selected_anchor_index < 0 or _selected_anchor_index >= anchors.size():
		_show_message("삭제할 배치 지점을 먼저 2D 화면에서 선택하세요.")
		return
	var selected_anchor: Object = anchors[_selected_anchor_index]
	var anchor_type := _get_anchor_type(selected_anchor)
	if anchor_type == "launch" or anchor_type == "drain":
		_show_message("발사 지점과 드레인 지점은 필수 지점이라 이 도구에서 삭제할 수 없습니다.")
		return
	if _has_property(selected_anchor, &"anchor_id") and _find_assignment_index(StringName(selected_anchor.get("anchor_id"))) >= 0:
		_show_message("선택한 지점에 오브젝트 원형이 배치되어 있습니다.\n먼저 '배치 비우기'를 누른 뒤 지점을 삭제하세요.")
		return
	var updated_anchors := anchors.duplicate()
	updated_anchors.remove_at(_selected_anchor_index)
	var layout := _get_layout()
	_undo_redo.create_action("보드 배치 지점 삭제")
	_undo_redo.add_do_property(layout, &"anchors", updated_anchors)
	_undo_redo.add_undo_property(layout, &"anchors", anchors)
	_undo_redo.add_do_method(layout, &"emit_changed")
	_undo_redo.add_undo_method(layout, &"emit_changed")
	_undo_redo.commit_action()
	_selected_anchor_index = -1
	_refresh_definition_options()
	_update_status()
	update_overlays()


func _on_definition_selected(_item_index: int) -> void:
	_update_definition_detail()


func _on_apply_definition_requested() -> void:
	if not _require_assignment_context():
		return
	if _definition_option.selected < 0 or _definition_option.is_item_disabled(_definition_option.selected):
		_show_message("선택한 배치 지점에 사용할 수 있는 오브젝트 원형을 먼저 선택하세요.")
		return
	var content_id := StringName(_definition_option.get_item_metadata(_definition_option.selected))
	if content_id == &"":
		_show_message("오브젝트 원형을 먼저 선택하세요.")
		return
	var point := _get_selected_anchor()
	var point_id := StringName(point.get("anchor_id"))
	var composition := _get_composition_config()
	var assignments := _get_assignments()
	var assignment := _create_assignment_resource()
	if assignment == null:
		_show_message("웨이브 배치 항목을 만들 수 없습니다.\nBoardPlacementAssignmentConfig 공개 계약을 확인하세요.")
		return
	assignment.set("point_id", point_id)
	assignment.set("content_id", content_id)
	var updated_assignments := assignments.duplicate()
	var replacement_index := _find_assignment_index(point_id)
	if replacement_index >= 0:
		updated_assignments[replacement_index] = assignment
	else:
		updated_assignments.append(assignment)
	_undo_redo.create_action("선택 지점에 오브젝트 원형 적용")
	_undo_redo.add_do_property(composition, &"assignments", updated_assignments)
	_undo_redo.add_undo_property(composition, &"assignments", assignments)
	_undo_redo.add_do_method(composition, &"emit_changed")
	_undo_redo.add_undo_method(composition, &"emit_changed")
	_undo_redo.commit_action()
	_refresh_definition_options()
	_update_status()
	update_overlays()


func _on_clear_assignment_requested() -> void:
	if not _require_assignment_context():
		return
	var point := _get_selected_anchor()
	var point_id := StringName(point.get("anchor_id"))
	var assignment_index := _find_assignment_index(point_id)
	if assignment_index < 0:
		_show_message("선택한 지점은 이미 비어 있습니다.")
		return
	if _get_anchor_type(point) == "flipper" and _count_assigned_flippers() <= 1:
		_show_message("웨이브에는 실제 배치된 플리퍼가 최소 1개 필요합니다.\n다른 플리퍼 지점에 원형을 먼저 적용한 뒤 비워 주세요.")
		return
	var composition := _get_composition_config()
	var assignments := _get_assignments()
	var updated_assignments := assignments.duplicate()
	updated_assignments.remove_at(assignment_index)
	_undo_redo.create_action("선택 지점의 웨이브 배치 비우기")
	_undo_redo.add_do_property(composition, &"assignments", updated_assignments)
	_undo_redo.add_undo_property(composition, &"assignments", assignments)
	_undo_redo.add_do_method(composition, &"emit_changed")
	_undo_redo.add_undo_method(composition, &"emit_changed")
	_undo_redo.commit_action()
	_refresh_definition_options()
	_update_status()
	update_overlays()


func _on_check_errors_requested() -> void:
	if not _require_layout():
		return
	var errors := _collect_errors()
	if errors.is_empty():
		_show_message("현재 보드 설계도에서 오류를 찾지 못했습니다.")
		return
	_show_message("다음 항목을 확인하세요.\n\n• " + "\n• ".join(errors))


func _add_anchor(anchor_type: String, id_prefix: String) -> void:
	if not _require_layout():
		return
	var anchors := _get_anchors()
	var anchor := _create_anchor_resource(anchors)
	if anchor == null:
		_show_message("배치 지점 원형을 만들 수 없습니다.\nBoardAnchorConfig 공개 계약을 확인하세요.")
		return
	if not _is_supported_anchor_type(anchor, anchor_type):
		var friendly_type := "일반 오브젝트" if anchor_type == "object" else anchor_type
		_show_message(
			"현재 보드 데이터 계약은 '%s' 지점을 아직 지원하지 않습니다.\n"
			+ "BoardAnchorConfig에 해당 지점 종류가 통합되면 이 버튼이 자동으로 활성화됩니다." % friendly_type
		)
		return
	if _has_property(anchor, &"anchor_id"):
		anchor.set("anchor_id", StringName(_make_unique_anchor_id(id_prefix)))
	if _has_property(anchor, &"anchor_type"):
		anchor.set("anchor_type", anchor_type)
	var board_position := _last_board_position
	if anchor_type == "flipper":
		board_position = _snap_flipper_anchor(anchor, board_position)
	if _has_property(anchor, &"board_position"):
		anchor.set("board_position", board_position)
	if anchor_type == "flipper" and _has_property(anchor, &"rotation_degrees"):
		anchor.set("rotation_degrees", 0.0)
	var updated_anchors := anchors.duplicate()
	updated_anchors.append(anchor)
	var layout := _get_layout()
	_undo_redo.create_action("%s 지점 추가" % _get_friendly_anchor_type(anchor_type))
	_undo_redo.add_do_property(layout, &"anchors", updated_anchors)
	_undo_redo.add_undo_property(layout, &"anchors", anchors)
	_undo_redo.add_do_method(layout, &"emit_changed")
	_undo_redo.add_undo_method(layout, &"emit_changed")
	_undo_redo.commit_action()
	_selected_anchor_index = updated_anchors.size() - 1
	_edit_mode = EditMode.POINT
	_refresh_definition_options()
	_update_status()
	update_overlays()


func _create_anchor_resource(anchors: Array) -> Resource:
	for existing_anchor in anchors:
		if existing_anchor != null and existing_anchor.get_script() != null:
			return existing_anchor.get_script().new()
	var anchor_script := load(FALLBACK_ANCHOR_SCRIPT_PATH)
	if anchor_script is Script:
		return anchor_script.new()
	return null


func _is_supported_anchor_type(anchor: Object, anchor_type: String) -> bool:
	if anchor.has_method("get_supported_types"):
		var supported: Variant = anchor.call("get_supported_types")
		for type_id in supported:
			if String(type_id) == anchor_type:
				return true
	return anchor_type in ["launch", "drain", "bumper", "flipper", "relic_slot", "object"]


func _begin_boundary_drag(point_index: int) -> void:
	_drag_kind = "boundary"
	_drag_index = point_index
	_drag_start_value = _get_boundary_points().duplicate()


func _begin_anchor_drag(anchor_index: int) -> void:
	var anchors := _get_anchors()
	if anchor_index < 0 or anchor_index >= anchors.size():
		return
	var anchor: Object = anchors[anchor_index]
	_drag_kind = "anchor"
	_drag_index = anchor_index
	_drag_start_value = _capture_anchor_transform(anchor)


func _update_drag(board_position: Vector2) -> void:
	var layout := _get_layout()
	if layout == null:
		_cancel_drag()
		return
	if _drag_kind == "boundary":
		var points := _get_boundary_points().duplicate()
		if _drag_index >= 0 and _drag_index < points.size():
			points[_drag_index] = board_position
			layout.set("boundary_points", points)
			layout.emit_changed()
	elif _drag_kind == "anchor":
		var anchors := _get_anchors()
		if _drag_index < 0 or _drag_index >= anchors.size():
			return
		var anchor: Object = anchors[_drag_index]
		var anchor_type := _get_anchor_type(anchor)
		if anchor_type == "flipper":
			board_position = _snap_flipper_anchor(anchor, board_position)
		elif layout.has_method("is_board_position_in_bounds") and not layout.call("is_board_position_in_bounds", board_position):
			return
		anchor.set("board_position", board_position)
		anchor.emit_changed()
	update_overlays()


func _finish_drag() -> void:
	if _drag_kind == "boundary":
		_finish_boundary_drag()
	elif _drag_kind == "anchor":
		_finish_anchor_drag()
	_clear_drag_state()
	_update_status()
	update_overlays()


func _finish_boundary_drag() -> void:
	var layout := _get_layout()
	if layout == null:
		return
	var final_points := _get_boundary_points().duplicate()
	var validation_errors := _get_layout_validation_errors()
	if not validation_errors.is_empty():
		layout.set("boundary_points", _drag_start_value)
		layout.emit_changed()
		_show_message(
			"외곽선 변경을 적용하지 않았습니다.\n문제를 해결한 뒤 다시 이동하세요.\n\n• "
			+ "\n• ".join(validation_errors)
		)
		return
	layout.set("boundary_points", _drag_start_value)
	layout.emit_changed()
	_undo_redo.create_action("보드 외곽선 정점 이동")
	_undo_redo.add_do_property(layout, &"boundary_points", final_points)
	_undo_redo.add_undo_property(layout, &"boundary_points", _drag_start_value)
	_undo_redo.add_do_method(layout, &"emit_changed")
	_undo_redo.add_undo_method(layout, &"emit_changed")
	_undo_redo.commit_action()


func _finish_anchor_drag() -> void:
	var anchors := _get_anchors()
	if _drag_index < 0 or _drag_index >= anchors.size():
		return
	var anchor: Object = anchors[_drag_index]
	var final_value := _capture_anchor_transform(anchor)
	_restore_anchor_transform(anchor, _drag_start_value)
	_undo_redo.create_action("보드 배치 지점 이동")
	for property_name in final_value:
		_undo_redo.add_do_property(anchor, property_name, final_value[property_name])
		_undo_redo.add_undo_property(anchor, property_name, _drag_start_value[property_name])
	_undo_redo.add_do_method(anchor, &"emit_changed")
	_undo_redo.add_undo_method(anchor, &"emit_changed")
	_undo_redo.commit_action()


func _cancel_drag() -> void:
	if _drag_kind == "boundary" and _get_layout() != null and _drag_start_value != null:
		_get_layout().set("boundary_points", _drag_start_value)
		_get_layout().emit_changed()
	elif _drag_kind == "anchor" and _drag_start_value != null:
		var anchors := _get_anchors()
		if _drag_index >= 0 and _drag_index < anchors.size():
			_restore_anchor_transform(anchors[_drag_index], _drag_start_value)
	_clear_drag_state()


func _clear_drag_state() -> void:
	_drag_kind = ""
	_drag_index = -1
	_drag_start_value = null


func _capture_anchor_transform(anchor: Object) -> Dictionary:
	var value := {}
	for property_name in [&"board_position", &"rotation_degrees", &"snap_to_boundary", &"boundary_edge_index", &"boundary_edge_offset"]:
		if _has_property(anchor, property_name):
			value[property_name] = anchor.get(property_name)
	return value


func _restore_anchor_transform(anchor: Object, value: Dictionary) -> void:
	for property_name in value:
		anchor.set(property_name, value[property_name])
	if anchor is Resource:
		anchor.emit_changed()


func _apply_flipper_attachment(anchor: Object, snap: Dictionary) -> void:
	if _has_property(anchor, &"snap_to_boundary"):
		anchor.set("snap_to_boundary", true)
	if _has_property(anchor, &"boundary_edge_index"):
		anchor.set("boundary_edge_index", snap.get("edge_index", -1))
	if _has_property(anchor, &"boundary_edge_offset"):
		anchor.set("boundary_edge_offset", snap.get("weight", 0.0))
	if _has_property(anchor, &"board_position"):
		anchor.set("board_position", snap.get("position", anchor.get("board_position")))


func _snap_flipper_anchor(anchor: Object, desired_position: Vector2) -> Vector2:
	var layout := _get_layout()
	if layout != null and layout.has_method("snap_flipper_anchor_to_boundary"):
		var snapped: bool = layout.call("snap_flipper_anchor_to_boundary", anchor, desired_position)
		if snapped:
			return _get_resolved_anchor_position(anchor)
	var snap := _get_nearest_boundary_snap(desired_position)
	_apply_flipper_attachment(anchor, snap)
	return snap.get("position", desired_position)


func _get_nearest_boundary_snap(board_position: Vector2) -> Dictionary:
	var points := _get_boundary_points()
	var best := {"position": board_position, "edge_index": -1, "weight": 0.0}
	var best_distance := INF
	for edge_index in points.size():
		var edge_start: Vector2 = points[edge_index]
		var edge_end: Vector2 = points[(edge_index + 1) % points.size()]
		var edge := edge_end - edge_start
		if edge.length_squared() <= 0.000001:
			continue
		var weight := clampf((board_position - edge_start).dot(edge) / edge.length_squared(), 0.0, 1.0)
		var candidate := edge_start + edge * weight
		var distance := board_position.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best = {"position": candidate, "edge_index": edge_index, "weight": weight}
	return best


func _find_boundary_handle(screen_position: Vector2) -> int:
	var transform := _get_canvas_transform()
	var points := _get_boundary_points()
	for point_index in points.size():
		var handle_position := transform * _project_board_position(points[point_index])
		if handle_position.distance_to(screen_position) <= HANDLE_HIT_RADIUS:
			return point_index
	return -1


func _find_anchor_handle(screen_position: Vector2) -> int:
	var transform := _get_canvas_transform()
	var anchors := _get_anchors()
	var best_index := -1
	var best_distance := HANDLE_HIT_RADIUS
	for anchor_index in anchors.size():
		var anchor: Object = anchors[anchor_index]
		if anchor == null or not _has_property(anchor, &"board_position"):
			continue
		var handle_position := transform * _project_board_position(_get_resolved_anchor_position(anchor))
		var distance := handle_position.distance_to(screen_position)
		if distance <= best_distance:
			best_distance = distance
			best_index = anchor_index
	return best_index


func _screen_to_board_position(screen_position: Vector2) -> Vector2:
	var inverse_transform := _get_canvas_transform().affine_inverse()
	var projected_position := inverse_transform * screen_position
	var view := _get_view_config()
	if view != null and view.has_method("unproject_board_point"):
		return _clamp_board_position(view.call("unproject_board_point", projected_position))
	if view != null and _has_property(view, &"board_size"):
		var board_size: Vector2 = view.get("board_size")
		var vertical_scale := 1.0
		var top_width_ratio := 1.0
		if view.has_method("get_vertical_scale"):
			vertical_scale = float(view.call("get_vertical_scale"))
		if view.has_method("get_top_width_ratio"):
			top_width_ratio = float(view.call("get_top_width_ratio"))
		var board_y := projected_position.y / maxf(board_size.y * vertical_scale, 0.0001)
		var vertical_weight := inverse_lerp(-0.5, 0.5, board_y)
		var horizontal_scale := lerpf(top_width_ratio, 1.0, vertical_weight)
		var board_x := projected_position.x / maxf(board_size.x * horizontal_scale, 0.0001)
		return _clamp_board_position(Vector2(board_x, board_y))
	return _clamp_board_position(projected_position / 500.0)


func _get_canvas_transform() -> Transform2D:
	if not is_instance_valid(_edited_node):
		return Transform2D.IDENTITY
	return _edited_node.get_viewport_transform() * _edited_node.get_global_transform()


func _project_board_position(board_position: Vector2) -> Vector2:
	var view := _get_view_config()
	if view != null and view.has_method("project_board_point"):
		return view.call("project_board_point", board_position)
	return board_position * 500.0


func _get_resolved_anchor_position(anchor: Object) -> Vector2:
	var layout := _get_layout()
	if layout != null and layout.has_method("get_resolved_anchor_position"):
		return layout.call("get_resolved_anchor_position", anchor)
	if anchor != null and _has_property(anchor, &"board_position"):
		return anchor.get("board_position")
	return Vector2(INF, INF)


func _clamp_board_position(board_position: Vector2) -> Vector2:
	return Vector2(clampf(board_position.x, -0.5, 0.5), clampf(board_position.y, -0.5, 0.5))


func _get_layout() -> Resource:
	if not is_instance_valid(_edited_node) or not _has_property(_edited_node, &"layout_config"):
		return null
	return _edited_node.get("layout_config") as Resource


func _get_view_config() -> Resource:
	if not is_instance_valid(_edited_node) or not _has_property(_edited_node, &"view_config"):
		return null
	return _edited_node.get("view_config") as Resource


func _get_composition_config() -> Resource:
	if not is_instance_valid(_edited_node) or not _has_property(_edited_node, &"composition_config"):
		return null
	return _edited_node.get("composition_config") as Resource


func _get_object_definitions() -> Array:
	if not is_instance_valid(_edited_node) or not _has_property(_edited_node, &"object_definitions"):
		return []
	return _edited_node.get("object_definitions")


func _get_assignments() -> Array:
	var composition := _get_composition_config()
	if composition == null or not _has_property(composition, &"assignments"):
		return []
	return composition.get("assignments")


func _get_selected_anchor() -> Object:
	var anchors := _get_anchors()
	if _selected_anchor_index < 0 or _selected_anchor_index >= anchors.size():
		return null
	return anchors[_selected_anchor_index]


func _find_assignment_index(point_id: StringName) -> int:
	var assignments := _get_assignments()
	for assignment_index in assignments.size():
		var assignment: Object = assignments[assignment_index]
		if assignment != null and _has_property(assignment, &"point_id"):
			if StringName(assignment.get("point_id")) == point_id:
				return assignment_index
	return -1


func _create_assignment_resource() -> Resource:
	var assignment_script := load(ASSIGNMENT_SCRIPT_PATH)
	if assignment_script is Script:
		return assignment_script.new()
	return null


func _require_assignment_context() -> bool:
	if not _require_layout():
		return false
	var point := _get_selected_anchor()
	if point == null:
		_show_message("원형을 적용할 배치 지점을 먼저 2D 화면에서 선택하세요.")
		return false
	var point_type := _get_anchor_type(point)
	if point_type == "launch" or point_type == "drain":
		_show_message("발사 지점과 드레인 지점에는 오브젝트 원형을 고정 배치할 수 없습니다.")
		return false
	if not _has_property(point, &"anchor_id") or String(point.get("anchor_id")) == "":
		_show_message("선택한 배치 지점의 이름이 비어 있습니다. 오류 확인에서 지점 이름을 먼저 해결하세요.")
		return false
	var composition := _get_composition_config()
	if composition == null or not _has_property(composition, &"assignments"):
		_show_message("현재 보드 씬에 웨이브 배치표가 연결되어 있지 않습니다.\ncomposition_config를 연결한 뒤 다시 시도하세요.")
		return false
	if _has_property(composition, &"layout_config") and composition.get("layout_config") != _get_layout():
		_show_message("웨이브 배치표가 현재 보드 설계도와 연결되어 있지 않습니다.\n웨이브 배치표의 '보드 설계도'를 현재 복제본으로 바꾼 뒤 다시 시도하세요.")
		return false
	return true


func _refresh_definition_options() -> void:
	if _definition_option == null:
		return
	_definition_option.clear()
	_definition_option.add_item("선택 가능한 오브젝트 원형 없음")
	_definition_option.set_item_disabled(0, true)
	_definition_option.set_item_metadata(0, StringName())
	var point := _get_selected_anchor()
	if point == null:
		_definition_option.disabled = true
		_update_definition_detail()
		return
	var point_type := _get_anchor_type(point)
	var current_content_id := _get_assigned_content_id(point)
	var selected_item := -1
	for definition in _get_object_definitions():
		if definition == null or not _has_property(definition, &"content_id"):
			continue
		if not _is_definition_compatible(point_type, definition):
			continue
		var content_id := StringName(definition.get("content_id"))
		if content_id == &"":
			continue
		var display_name := String(content_id)
		if _has_property(definition, &"display_name") and not String(definition.get("display_name")).strip_edges().is_empty():
			display_name = String(definition.get("display_name"))
		var item_index := _definition_option.item_count
		_definition_option.add_item("%s (%s)" % [display_name, content_id])
		_definition_option.set_item_metadata(item_index, content_id)
		if content_id == current_content_id:
			selected_item = item_index
	_definition_option.disabled = _definition_option.item_count <= 1
	if selected_item >= 0:
		_definition_option.select(selected_item)
	elif _definition_option.item_count > 1:
		_definition_option.select(1)
	else:
		_definition_option.select(0)
	_update_definition_detail()


func _get_assigned_content_id(point: Object) -> StringName:
	if point == null or not _has_property(point, &"anchor_id"):
		return &""
	var assignment_index := _find_assignment_index(StringName(point.get("anchor_id")))
	var assignments := _get_assignments()
	if assignment_index < 0 or assignment_index >= assignments.size():
		return &""
	var assignment: Object = assignments[assignment_index]
	if assignment == null or not _has_property(assignment, &"content_id"):
		return &""
	return StringName(assignment.get("content_id"))


func _is_definition_compatible(point_type: String, definition: Object) -> bool:
	var object_type := ""
	if definition.has_method("get_object_type_id"):
		object_type = String(definition.call("get_object_type_id"))
	elif _has_property(definition, &"object_type"):
		object_type = String(definition.get("object_type"))
	match point_type:
		"bumper": return object_type == "bumper"
		"flipper": return object_type == "flipper"
		"relic_slot": return object_type == "relic_preview"
		"object": return object_type == "wall" or object_type == "general"
		_: return false


func _update_definition_detail() -> void:
	if _definition_detail_label == null:
		return
	if _definition_option == null or _definition_option.selected < 0 or _definition_option.is_item_disabled(_definition_option.selected):
		_definition_detail_label.text = "배치 지점을 선택하면 역할에 맞는 오브젝트 원형이 표시됩니다."
		return
	var content_id := StringName(_definition_option.get_item_metadata(_definition_option.selected))
	var definition := _find_definition(content_id)
	if definition == null:
		_definition_detail_label.text = "선택한 오브젝트 원형 정보를 찾지 못했습니다."
		return
	var display_name := String(definition.get("display_name")) if _has_property(definition, &"display_name") else String(content_id)
	var object_type := String(definition.get("object_type")) if _has_property(definition, &"object_type") else "알 수 없음"
	var indestructible := bool(definition.get("indestructible")) if _has_property(definition, &"indestructible") else false
	var durability := int(definition.get("max_durability")) if _has_property(definition, &"max_durability") else 0
	var detail_lines := PackedStringArray([
		"표시 이름: %s" % display_name,
		"원형 ID: %s" % content_id,
		"오브젝트 종류: %s" % _get_friendly_object_type(object_type),
		"파괴되지 않음: %s" % ("예" if indestructible else "아니요"),
		"최대 내구도: %s" % ("적용 안 함" if indestructible else str(durability)),
	])
	if _has_property(definition, &"bumper_type"):
		detail_lines.append("범퍼 종류: %s" % String(definition.get("bumper_type")))
	_definition_detail_label.text = "\n".join(detail_lines)


func _find_definition(content_id: StringName) -> Object:
	for definition in _get_object_definitions():
		if definition != null and _has_property(definition, &"content_id"):
			if StringName(definition.get("content_id")) == content_id:
				return definition
	return null


func _get_friendly_object_type(object_type: String) -> String:
	match object_type:
		"bumper": return "범퍼"
		"wall": return "벽"
		"general": return "일반 오브젝트"
		"flipper": return "플리퍼"
		"relic_preview": return "유물 미리보기"
		_: return object_type


func _count_assigned_flippers() -> int:
	var count := 0
	var layout := _get_layout()
	if layout == null or not layout.has_method("get_anchor"):
		return count
	for assignment in _get_assignments():
		if assignment == null or not _has_property(assignment, &"point_id"):
			continue
		var point: Object = layout.call("get_anchor", StringName(assignment.get("point_id")))
		if point != null and _get_anchor_type(point) == "flipper":
			count += 1
	return count


func _get_boundary_points() -> PackedVector2Array:
	var layout := _get_layout()
	if layout == null or not _has_property(layout, &"boundary_points"):
		return PackedVector2Array()
	return layout.get("boundary_points")


func _get_anchors() -> Array:
	var layout := _get_layout()
	if layout == null or not _has_property(layout, &"anchors"):
		return []
	return layout.get("anchors")


func _has_editable_layout() -> bool:
	var layout := _get_layout()
	return layout != null and _has_property(layout, &"boundary_points") and _has_property(layout, &"anchors")


func _require_layout() -> bool:
	if _has_editable_layout():
		return true
	_show_message("2D 화면에서 BoardMockup2D 또는 BoardAuthoring2D 노드를 먼저 선택하세요.\n선택한 노드에는 보드 설계도가 연결되어 있어야 합니다.")
	return false


func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property_info in object.get_property_list():
		if StringName(property_info.get("name", "")) == property_name:
			return true
	return false


func _get_anchor_type(anchor: Object) -> String:
	if anchor == null or not _has_property(anchor, &"anchor_type"):
		return "unknown"
	return String(anchor.get("anchor_type"))


func _get_anchor_label(anchor: Object, anchor_index: int) -> String:
	if _has_property(anchor, &"anchor_id") and String(anchor.get("anchor_id")) != "":
		return String(anchor.get("anchor_id"))
	return "%s %d" % [_get_friendly_anchor_type(_get_anchor_type(anchor)), anchor_index + 1]


func _get_anchor_color(anchor_type: String) -> Color:
	match anchor_type:
		"bumper": return Color("f4d35e")
		"flipper": return Color("ff6b6b")
		"relic_slot": return Color("55d6be")
		"launch": return Color("dbe9f4")
		"drain": return Color("ef476f")
		"object": return Color("9b8afb")
		_: return Color("a8b2b8")


func _get_friendly_anchor_type(anchor_type: String) -> String:
	match anchor_type:
		"bumper": return "범퍼"
		"flipper": return "플리퍼"
		"relic_slot": return "유물 배치"
		"launch": return "발사"
		"drain": return "드레인"
		"object": return "일반 오브젝트"
		_: return "배치"


func _make_unique_anchor_id(prefix: String) -> String:
	var existing_ids := {}
	for anchor in _get_anchors():
		if anchor != null and _has_property(anchor, &"anchor_id"):
			existing_ids[String(anchor.get("anchor_id"))] = true
	var suffix := 1
	var candidate := "%s_%02d" % [prefix, suffix]
	while existing_ids.has(candidate):
		suffix += 1
		candidate = "%s_%02d" % [prefix, suffix]
	return candidate


func _count_anchors_by_type(anchor_type: String) -> int:
	var count := 0
	for anchor in _get_anchors():
		if _get_anchor_type(anchor) == anchor_type:
			count += 1
	return count


func _get_layout_validation_errors() -> PackedStringArray:
	var layout := _get_layout()
	if layout != null and layout.has_method("get_validation_errors"):
		return layout.call("get_validation_errors")
	return PackedStringArray()


func _collect_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if is_instance_valid(_edited_node) and _edited_node.has_method("get_assembly_errors"):
		errors.append_array(_edited_node.call("get_assembly_errors"))
	else:
		errors.append_array(_get_layout_validation_errors())
	return errors


func _anchor_has_error(anchor: Object, assembly_errors: PackedStringArray) -> bool:
	if anchor == null:
		return true
	if anchor.has_method("get_validation_errors"):
		var anchor_errors: PackedStringArray = anchor.call("get_validation_errors")
		if not anchor_errors.is_empty():
			return true
	if not _has_property(anchor, &"anchor_id"):
		return false
	var anchor_id := String(anchor.get("anchor_id"))
	if anchor_id.is_empty():
		return true
	for error in assembly_errors:
		if String(error).contains(anchor_id):
			return true
	return false


func _update_status() -> void:
	if _status_label == null:
		return
	if not _has_editable_layout():
		_status_label.text = "대기 중: 2D 화면에서 보드 노드를 선택하세요."
		return
	var mode_text := "보기"
	if _edit_mode == EditMode.BOUNDARY:
		mode_text = "외곽선 편집"
	elif _edit_mode == EditMode.POINT:
		mode_text = "배치 지점 편집"
	var selection_text := "선택 지점 없음"
	var anchors := _get_anchors()
	if _selected_anchor_index >= 0 and _selected_anchor_index < anchors.size():
		selection_text = "선택: %s" % _get_anchor_label(anchors[_selected_anchor_index], _selected_anchor_index)
	var errors := _collect_errors()
	var error_text := "오류 없음" if errors.is_empty() else "오류 %d개 — '오류 확인'을 누르세요." % errors.size()
	_status_label.text = "현재 모드: %s\n%s\n%s" % [mode_text, selection_text, error_text]


func _show_message(message: String) -> void:
	if _message_dialog == null:
		return
	_message_dialog.dialog_text = message
	_message_dialog.popup_centered_ratio(0.5)


func _on_undo_redo_version_changed() -> void:
	_refresh_definition_options()
	_update_status()
	update_overlays()
