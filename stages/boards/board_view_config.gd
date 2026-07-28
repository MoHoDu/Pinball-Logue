@tool
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
@export_range(4.0, 80.0, 1.0) var bumper_radius := 28.0
@export_range(2.0, 70.0, 1.0) var bumper_inner_radius := 22.0
@export_range(20.0, 220.0, 1.0) var flipper_length := 132.0
@export_range(4.0, 60.0, 1.0) var flipper_width := 22.0
@export_range(2.0, 30.0, 1.0) var flipper_pivot_radius := 13.0
@export_range(2.0, 40.0, 1.0) var launch_marker_radius := 18.0
@export_range(4.0, 80.0, 1.0) var relic_slot_radius := 24.0
@export_range(10.0, 240.0, 1.0) var drain_width := 100.0


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(view_angle_degrees) or view_angle_degrees < 20.0 or view_angle_degrees > 85.0:
		errors.append("보드 시점 각도는 20~85° 범위여야 합니다.")
	if not _is_positive_finite(board_size.x) or not _is_positive_finite(board_size.y):
		errors.append("보드 크기는 양수여야 합니다.")
	if not _is_positive_finite(rail_width):
		errors.append("레일 두께는 양수여야 합니다.")
	if not _is_positive_finite(bumper_radius):
		errors.append("범퍼 바깥 반지름은 양수여야 합니다.")
	if not _is_positive_finite(bumper_inner_radius):
		errors.append("범퍼 안쪽 반지름은 양수여야 합니다.")
	if _is_positive_finite(bumper_inner_radius) and _is_positive_finite(bumper_radius) and bumper_inner_radius >= bumper_radius:
		errors.append("범퍼 안쪽 반지름은 바깥 반지름보다 작아야 합니다.")
	if not _is_positive_finite(flipper_length):
		errors.append("플리퍼 길이는 양수여야 합니다.")
	if not _is_positive_finite(flipper_width):
		errors.append("플리퍼 너비는 양수여야 합니다.")
	if not _is_positive_finite(flipper_pivot_radius):
		errors.append("플리퍼 피벗 반지름은 양수여야 합니다.")
	if not _is_positive_finite(launch_marker_radius):
		errors.append("발사 지점 표식 반지름은 양수여야 합니다.")
	if not _is_positive_finite(relic_slot_radius):
		errors.append("유물 슬롯 반지름은 양수여야 합니다.")
	if not _is_positive_finite(drain_width):
		errors.append("드레인 너비는 양수여야 합니다.")
	return errors


func get_top_width_ratio() -> float:
	var normalized_angle := inverse_lerp(20.0, 85.0, clampf(view_angle_degrees, 20.0, 85.0))
	return lerpf(0.55, 0.92, normalized_angle)


func get_vertical_scale() -> float:
	var normalized_angle := inverse_lerp(20.0, 85.0, clampf(view_angle_degrees, 20.0, 85.0))
	return lerpf(0.72, 0.98, normalized_angle)


func project_board_point(board_position: Vector2) -> Vector2:
	var vertical_weight := inverse_lerp(-0.5, 0.5, clampf(board_position.y, -0.5, 0.5))
	var horizontal_scale := lerpf(get_top_width_ratio(), 1.0, vertical_weight)
	return Vector2(
		board_position.x * board_size.x * horizontal_scale,
		board_position.y * board_size.y * get_vertical_scale()
	)


func unproject_board_point(projected_position: Vector2) -> Vector2:
	if not _is_positive_finite(board_size.x) or not _is_positive_finite(board_size.y):
		return Vector2(INF, INF)
	var vertical_scale := get_vertical_scale()
	if not _is_positive_finite(vertical_scale):
		return Vector2(INF, INF)
	var board_y := projected_position.y / (board_size.y * vertical_scale)
	var vertical_weight := inverse_lerp(-0.5, 0.5, clampf(board_y, -0.5, 0.5))
	var horizontal_scale := lerpf(get_top_width_ratio(), 1.0, vertical_weight)
	if not _is_positive_finite(horizontal_scale):
		return Vector2(INF, INF)
	return Vector2(
		projected_position.x / (board_size.x * horizontal_scale),
		board_y
	)


func project_board_direction(board_position: Vector2, rotation_degrees: float) -> Vector2:
	var board_direction := Vector2.RIGHT.rotated(deg_to_rad(rotation_degrees))
	var projected_origin := project_board_point(board_position)
	var projected_direction_point := project_board_point(
		board_position + board_direction * 0.01
	)
	return projected_origin.direction_to(projected_direction_point)


func project_board_polygon(boundary_points: PackedVector2Array) -> PackedVector2Array:
	var projected_points := PackedVector2Array()
	for boundary_point in boundary_points:
		projected_points.append(project_board_point(boundary_point))
	return projected_points


func _is_positive_finite(value: float) -> bool:
	return is_finite(value) and value > 0.0
