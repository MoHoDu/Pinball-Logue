@tool
extends RefCounted

const CONTENT_ROOT := "res://stages/boards/content"
const MAX_BOARD_ID_LENGTH := 64


static func get_board_id_error(board_id: String) -> String:
	var normalized := board_id.strip_edges()
	if normalized.is_empty():
		return "보드 ID를 입력해 주세요."
	if normalized != board_id:
		return "보드 ID의 앞뒤에는 공백을 사용할 수 없습니다."
	if normalized.length() > MAX_BOARD_ID_LENGTH:
		return "보드 ID는 %d자 이하여야 합니다." % MAX_BOARD_ID_LENGTH
	for character_index in normalized.length():
		var code := normalized.unicode_at(character_index)
		var is_lowercase_letter := code >= 97 and code <= 122
		var is_number := code >= 48 and code <= 57
		if not is_lowercase_letter and not is_number and code != 95:
			return "보드 ID에는 영문 소문자, 숫자와 밑줄(_)만 사용할 수 있습니다."
	return ""


static func get_board_paths(board_id: String) -> Dictionary:
	if not get_board_id_error(board_id).is_empty():
		return {}
	var board_directory := "%s/%s" % [CONTENT_ROOT, board_id]
	return {
		"board_id": board_id,
		"directory": board_directory,
		"layout": "%s/%s_layout.tres" % [board_directory, board_id],
		"composition": "%s/%s_wave_composition.tres" % [board_directory, board_id],
	}


static func get_path_collision_error(paths: Dictionary) -> String:
	if paths.is_empty():
		return "보드 저장 경로를 만들 수 없습니다. 보드 ID를 확인해 주세요."
	var directory := String(paths.get("directory", ""))
	var layout_path := String(paths.get("layout", ""))
	var composition_path := String(paths.get("composition", ""))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)):
		return "같은 보드 ID 폴더가 이미 있습니다: %s" % directory
	if FileAccess.file_exists(layout_path) or FileAccess.file_exists(composition_path):
		return "같은 이름의 보드 파일이 이미 있습니다. 다른 보드 ID를 사용해 주세요."
	return ""
