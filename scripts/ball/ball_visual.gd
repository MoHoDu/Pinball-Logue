extends Node2D


var radius_px: float = 22.0


func set_radius_px(value: float) -> void:
	radius_px = value
	queue_redraw()


func _draw() -> void:
	# 외곽 발광
	draw_circle(
		Vector2.ZERO,
		radius_px + 7.0,
		Color(0.1, 0.9, 0.85, 0.2)
	)

	# 공 본체
	draw_circle(
		Vector2.ZERO,
		radius_px,
		Color(0.95, 0.98, 1.0)
	)

	# 공 외곽선
	draw_arc(
		Vector2.ZERO,
		radius_px,
		0.0,
		TAU,
		64,
		Color(0.1, 0.85, 0.8),
		3.0,
		true
	)
