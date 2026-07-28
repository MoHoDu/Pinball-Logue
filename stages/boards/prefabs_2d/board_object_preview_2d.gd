@tool
class_name BoardObjectPreview2D
extends Node2D

@export_enum("bumper", "wall", "general", "flipper", "relic") var preview_kind := "bumper"
@export var primary_color := Color("e3c65f")
@export var secondary_color := Color("8f552f")
@export var accent_color := Color("d94b3d")
@export_range(8.0, 180.0, 1.0) var preview_size := 28.0


func _ready() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	match preview_kind:
		"bumper":
			_draw_bumper()
		"wall":
			_draw_wall()
		"general":
			_draw_general_object()
		"flipper":
			_draw_flipper()
		"relic":
			_draw_relic_preview()


func _draw_bumper() -> void:
	draw_circle(Vector2.ZERO, preview_size, secondary_color)
	draw_circle(Vector2.ZERO, preview_size * 0.76, primary_color)
	draw_arc(Vector2.ZERO, preview_size * 0.48, 0.0, TAU, 16, accent_color, 3.0, true)


func _draw_wall() -> void:
	var half_length := preview_size * 1.6
	draw_line(Vector2(-half_length, 0.0), Vector2(half_length, 0.0), secondary_color, preview_size * 0.65, true)
	draw_line(Vector2(-half_length, -2.0), Vector2(half_length, -2.0), primary_color, 4.0, true)


func _draw_general_object() -> void:
	var points := PackedVector2Array()
	for point_index in 6:
		points.append(Vector2.RIGHT.rotated(TAU * float(point_index) / 6.0) * preview_size)
	draw_colored_polygon(points, primary_color)
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, secondary_color, 4.0, true)


func _draw_flipper() -> void:
	var length := preview_size * 4.4
	var width := preview_size * 0.75
	var points := PackedVector2Array([
		Vector2(0.0, -width * 0.5),
		Vector2(length, -width * 0.32),
		Vector2(length, width * 0.32),
		Vector2(0.0, width * 0.5),
	])
	draw_colored_polygon(points, primary_color)
	draw_circle(Vector2.ZERO, width * 0.6, secondary_color)


func _draw_relic_preview() -> void:
	draw_circle(Vector2.ZERO, preview_size, Color(primary_color, 0.24))
	draw_arc(Vector2.ZERO, preview_size, 0.0, TAU, 24, primary_color, 3.0, true)
	var diamond := PackedVector2Array([
		Vector2(0.0, -preview_size * 0.65),
		Vector2(preview_size * 0.5, 0.0),
		Vector2(0.0, preview_size * 0.65),
		Vector2(-preview_size * 0.5, 0.0),
	])
	draw_colored_polygon(diamond, Color(accent_color, 0.7))
