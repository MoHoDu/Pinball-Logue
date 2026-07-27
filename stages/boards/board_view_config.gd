class_name BoardViewConfig
extends Resource

@export_range(20.0, 85.0, 0.5) var view_angle_degrees := 58.0
@export var board_size := Vector2(540.0, 500.0)
@export_range(1.0, 40.0, 1.0) var rail_width := 18.0
@export var board_color := Color("284c45")
@export var rail_color := Color("8f552f")
@export var lane_color := Color("4f8d7d")
@export var bumper_color := Color("e3c65f")
@export var accent_color := Color("d94b3d")


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if view_angle_degrees < 20.0 or view_angle_degrees > 85.0:
		errors.append("보드 시점 각도는 20~85° 범위여야 합니다.")
	if board_size.x <= 0.0 or board_size.y <= 0.0:
		errors.append("보드 크기는 양수여야 합니다.")
	if rail_width <= 0.0:
		errors.append("레일 두께는 양수여야 합니다.")
	return errors


func get_top_width_ratio() -> float:
	var normalized_angle := inverse_lerp(20.0, 85.0, clampf(view_angle_degrees, 20.0, 85.0))
	return lerpf(0.55, 0.92, normalized_angle)


func get_vertical_scale() -> float:
	var normalized_angle := inverse_lerp(20.0, 85.0, clampf(view_angle_degrees, 20.0, 85.0))
	return lerpf(0.72, 0.98, normalized_angle)


func get_board_polygon() -> PackedVector2Array:
	var half_bottom_width := board_size.x * 0.5
	var half_top_width := half_bottom_width * get_top_width_ratio()
	var half_height := board_size.y * get_vertical_scale() * 0.5
	return PackedVector2Array([
		Vector2(-half_top_width, -half_height),
		Vector2(half_top_width, -half_height),
		Vector2(half_bottom_width, half_height),
		Vector2(-half_bottom_width, half_height),
	])
