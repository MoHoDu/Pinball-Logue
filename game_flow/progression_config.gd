class_name ProgressionConfig
extends Resource

@export_range(1, 9, 1) var stage_count := 3
@export_range(1, 12, 1) var normal_wave_count := 3


func get_validation_error() -> String:
	if stage_count <= 0:
		return "스테이지 수는 1 이상이어야 합니다."
	if normal_wave_count <= 0:
		return "일반 웨이브 수는 1 이상이어야 합니다."
	return ""
