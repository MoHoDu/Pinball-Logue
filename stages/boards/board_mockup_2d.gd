@tool
class_name BoardMockup2D
extends Node2D

@export var config: BoardViewConfig
@export var show_boss := false


func _ready() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if config == null or not config.get_validation_errors().is_empty():
		return

	var polygon := config.get_board_polygon()
	draw_colored_polygon(polygon, config.board_color)
	var closed_outline := PackedVector2Array(polygon)
	closed_outline.append(polygon[0])
	draw_polyline(closed_outline, config.rail_color, config.rail_width, true)
	_draw_lanes()
	_draw_bumpers()
	_draw_flippers()
	if show_boss:
		_draw_boss()
	else:
		_draw_ball()


func _draw_lanes() -> void:
	var half_height := config.board_size.y * config.get_vertical_scale() * 0.5
	for lane_index in 3:
		var x := float(lane_index - 1) * 92.0
		draw_line(
			Vector2(x * config.get_top_width_ratio(), -half_height + 34.0),
			Vector2(x * 1.35, half_height - 105.0),
			config.lane_color,
			8.0,
			true
		)


func _draw_bumpers() -> void:
	var bumper_positions := [
		Vector2(-125.0, -118.0),
		Vector2(0.0, -148.0),
		Vector2(125.0, -118.0),
		Vector2(-155.0, 12.0),
		Vector2(155.0, 12.0),
	]
	for bumper_position in bumper_positions:
		draw_circle(bumper_position, 28.0, config.rail_color)
		draw_circle(bumper_position, 22.0, config.bumper_color)


func _draw_flippers() -> void:
	var left_points := PackedVector2Array([
		Vector2(-175.0, 155.0),
		Vector2(-45.0, 184.0),
		Vector2(-52.0, 205.0),
		Vector2(-184.0, 177.0),
	])
	var right_points := PackedVector2Array([
		Vector2(175.0, 155.0),
		Vector2(45.0, 184.0),
		Vector2(52.0, 205.0),
		Vector2(184.0, 177.0),
	])
	draw_colored_polygon(left_points, config.accent_color)
	draw_colored_polygon(right_points, config.accent_color)
	draw_circle(Vector2(-180.0, 166.0), 13.0, config.bumper_color)
	draw_circle(Vector2(180.0, 166.0), 13.0, config.bumper_color)


func _draw_ball() -> void:
	draw_circle(Vector2(42.0, 78.0), 18.0, Color("dbe9f4"))
	draw_arc(Vector2(42.0, 78.0), 18.0, 0.0, TAU, 24, Color("5f7585"), 3.0, true)


func _draw_boss() -> void:
	draw_circle(Vector2(0.0, -72.0), 52.0, config.accent_color)
	draw_circle(Vector2(0.0, -72.0), 36.0, Color("7c241f"))
