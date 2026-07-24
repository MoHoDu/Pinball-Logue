class_name BallPhysicsData
extends Resource


@export_category("공 크기")

@export_range(12.0, 40.0, 1.0)
var radius_px: float = 22.0


@export_category("공 속도")

@export_range(50.0, 1000.0, 10.0)
var min_speed: float = 300.0

@export_range(100.0, 2000.0, 10.0)
var launch_speed: float = 850.0

@export_range(300.0, 3000.0, 10.0)
var max_speed: float = 1450.0


@export_category("충돌")

@export_range(0.0, 1.0, 0.01)
var bounce: float = 0.85

@export_range(0.0, 1.0, 0.01)
var friction: float = 0.02


@export_category("속도 보정")

@export_range(0.0, 1.0, 0.01)
var low_speed_grace: float = 0.25


@export_category("조준")

@export_range(20.0, 89.0, 1.0)
var aim_max_angle_deg: float = 70.0

@export_range(30.0, 360.0, 5.0)
var aim_turn_speed_deg: float = 100.0

@export_range(100.0, 800.0, 10.0)
var aim_line_length: float = 360.0

@export_range(0.0, 0.7, 0.01)
var aim_curve_strength: float = 0.28

@export_range(8, 64, 1)
var aim_line_segments: int = 24


func is_valid() -> bool:
	return (
		radius_px > 0.0
		and min_speed > 0.0
		and min_speed <= launch_speed
		and launch_speed <= max_speed
		and bounce >= 0.0
		and bounce <= 1.0
		and friction >= 0.0
		and friction <= 1.0
		and aim_max_angle_deg > 0.0
		and aim_line_length > 0.0
		and aim_line_segments >= 2
	)
