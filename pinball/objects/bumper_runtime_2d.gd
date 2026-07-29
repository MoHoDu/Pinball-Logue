class_name BumperRuntime2D
extends AnimatableBody2D

signal contact_started(
	point_id: StringName,
	body: Ball2D,
	contact_id: StringName,
	contact_time_fraction: float,
	contact_world_position: Vector2,
	world_normal: Vector2
)
signal contact_ended(point_id: StringName, contact_id: StringName)

const BALL_GROUP: StringName = &"pinball_ball_2d"
const MIN_SENSOR_MARGIN_PIXELS := 2.0

var point_id: StringName = &""
var definition: BumperDefinition
var collision_radius_pixels := 28.0
var safe_margin_pixels := 6.0

var _body_shape: CollisionShape2D
var _contact_sensor: Area2D
var _sensor_shape: CollisionShape2D
var _presentation_instance: Node2D
var _contacts_by_body_id: Dictionary = {}
var _is_collision_active := true
var _is_telegraphing := false
var _ball_scope: Node


func configure(
	requested_point_id: StringName,
	requested_definition: BumperDefinition,
	radius_pixels: float,
	requested_safe_margin_pixels: float,
	presentation_scene: PackedScene
) -> String:
	if requested_point_id == &"":
		return "범퍼 배치 지점 식별자가 비어 있습니다."
	if requested_definition == null:
		return "범퍼 원형 설정이 없습니다: %s" % requested_point_id
	var definition_errors := requested_definition.get_validation_errors()
	if not definition_errors.is_empty():
		return definition_errors[0]
	if not is_finite(radius_pixels) or radius_pixels <= 0.0:
		return "2D 범퍼 충돌 반지름은 유한한 양수여야 합니다."
	if not is_finite(requested_safe_margin_pixels) or requested_safe_margin_pixels < 0.0:
		return "2D 범퍼 안전 복구 여백은 유한한 0 이상의 값이어야 합니다."

	point_id = requested_point_id
	definition = requested_definition
	collision_radius_pixels = radius_pixels
	safe_margin_pixels = requested_safe_margin_pixels
	name = "Bumper_%s" % point_id
	set_meta(&"board_point_id", point_id)
	_build_collision_nodes()
	var presentation_error := _set_presentation_scene(presentation_scene)
	if not presentation_error.is_empty():
		return presentation_error
	set_collision_active(true)
	return ""


func set_collision_active(is_active: bool) -> void:
	_is_collision_active = is_active
	if _body_shape != null:
		_body_shape.set_deferred("disabled", not is_active)
	if _sensor_shape != null:
		_sensor_shape.set_deferred("disabled", not is_active)
	if _contact_sensor != null:
		_contact_sensor.set_deferred("monitoring", is_active)
	if not is_active:
		_clear_contacts()
	modulate = Color(1.0, 1.0, 1.0, 1.0) if is_active else Color(0.55, 0.55, 0.55, 0.28)


func set_recovery_telegraph(is_telegraphing: bool) -> void:
	_is_telegraphing = is_telegraphing
	if not _is_collision_active:
		modulate = (
			Color(1.0, 0.88, 0.42, 0.72)
			if is_telegraphing
			else Color(0.55, 0.55, 0.55, 0.28)
		)


func set_ball_scope(ball_scope: Node) -> void:
	_ball_scope = ball_scope


func is_collision_active() -> bool:
	return _is_collision_active


func is_recovery_telegraphing() -> bool:
	return _is_telegraphing


func get_safe_radius_pixels() -> float:
	return collision_radius_pixels + safe_margin_pixels


func begin_swept_contact(
	body: Ball2D,
	contact_time_fraction: float,
	contact_world_position: Vector2
) -> bool:
	if not _is_collision_active or body == null or not is_instance_valid(body):
		return false
	return _begin_contact(body, contact_time_fraction, contact_world_position)


func is_safe_clear_for_balls(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0:
		return false
	var tree := get_tree()
	if tree == null:
		return false
	for candidate in tree.get_nodes_in_group(BALL_GROUP):
		if not candidate is Ball2D or not is_instance_valid(candidate):
			continue
		var ball := candidate as Ball2D
		if _ball_scope != null and not _ball_scope.is_ancestor_of(ball):
			continue
		var ball_radius := _get_ball_radius_pixels(ball)
		var required_distance := get_safe_radius_pixels() + ball_radius
		var start := ball.global_position
		var predicted := start + ball.linear_velocity * delta
		if _distance_to_segment_squared(global_position, start, predicted) <= required_distance * required_distance:
			return false
	return true


func _build_collision_nodes() -> void:
	for child in get_children():
		if child == _presentation_instance:
			continue
		remove_child(child)
		child.queue_free()

	collision_layer = 1
	collision_mask = 1
	sync_to_physics = true

	_body_shape = CollisionShape2D.new()
	_body_shape.name = "CollisionShape2D"
	var body_circle := CircleShape2D.new()
	body_circle.radius = collision_radius_pixels
	_body_shape.shape = body_circle
	add_child(_body_shape)

	_contact_sensor = Area2D.new()
	_contact_sensor.name = "ContactSensor"
	_contact_sensor.collision_layer = 0
	_contact_sensor.collision_mask = 1
	_contact_sensor.monitoring = true
	_contact_sensor.monitorable = false
	_sensor_shape = CollisionShape2D.new()
	_sensor_shape.name = "CollisionShape2D"
	var sensor_circle := CircleShape2D.new()
	sensor_circle.radius = collision_radius_pixels + MIN_SENSOR_MARGIN_PIXELS
	_sensor_shape.shape = sensor_circle
	_contact_sensor.add_child(_sensor_shape)
	add_child(_contact_sensor)
	_contact_sensor.body_entered.connect(_on_sensor_body_entered)
	_contact_sensor.body_exited.connect(_on_sensor_body_exited)


func _set_presentation_scene(presentation_scene: PackedScene) -> String:
	if is_instance_valid(_presentation_instance):
		_presentation_instance.queue_free()
		_presentation_instance = null
	if presentation_scene == null:
		return "범퍼에 연결할 2D 디자인 장면이 없습니다: %s" % point_id
	if not presentation_scene.can_instantiate():
		return "범퍼 2D 디자인 장면을 만들 수 없습니다: %s" % point_id
	var instance := presentation_scene.instantiate()
	if not instance is Node2D:
		instance.free()
		return "범퍼 2D 디자인의 루트는 Node2D여야 합니다: %s" % point_id
	_presentation_instance = instance
	_presentation_instance.name = "Presentation2D"
	add_child(_presentation_instance)
	move_child(_presentation_instance, 0)
	if _presentation_instance is BoardObjectPreview2D:
		var source_radius: float = maxf(_presentation_instance.preview_size, 0.001)
		_presentation_instance.scale = Vector2.ONE * (collision_radius_pixels / source_radius)
	return ""


func _on_sensor_body_entered(body: Node2D) -> void:
	if body is Ball2D:
		_begin_contact(body as Ball2D, 0.0, body.global_position)


func _on_sensor_body_exited(body: Node2D) -> void:
	if not body is Ball2D:
		return
	var body_id := body.get_instance_id()
	if not _contacts_by_body_id.has(body_id):
		return
	var contact_id := StringName(_contacts_by_body_id[body_id])
	_contacts_by_body_id.erase(body_id)
	contact_ended.emit(point_id, contact_id)


func _begin_contact(
	body: Ball2D,
	contact_time_fraction: float,
	contact_world_position: Vector2
) -> bool:
	var body_id := body.get_instance_id()
	if _contacts_by_body_id.has(body_id):
		return false
	var shot_id := StringName(body.get_meta(&"shot_id", ""))
	if shot_id == &"":
		return false
	var contact_id := StringName("%s:%s" % [point_id, shot_id])
	_contacts_by_body_id[body_id] = contact_id
	var world_normal := global_position.direction_to(body.global_position)
	if world_normal.is_zero_approx():
		world_normal = Vector2.UP
	var contact_position := global_position + world_normal * collision_radius_pixels
	if _is_finite_vector(contact_world_position):
		contact_position = contact_world_position
	contact_started.emit(
		point_id,
		body,
		contact_id,
		clampf(contact_time_fraction, 0.0, 1.0),
		contact_position,
		world_normal
	)
	return true


func _clear_contacts() -> void:
	for contact_id in _contacts_by_body_id.values():
		contact_ended.emit(point_id, StringName(contact_id))
	_contacts_by_body_id.clear()


func _get_ball_radius_pixels(ball: Ball2D) -> float:
	var collision_shape := ball.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		return (collision_shape.shape as CircleShape2D).radius
	return 0.0


func _distance_to_segment_squared(point: Vector2, start: Vector2, finish: Vector2) -> float:
	if start.is_equal_approx(finish):
		return point.distance_squared_to(start)
	var closest := Geometry2D.get_closest_point_to_segment(point, start, finish)
	return point.distance_squared_to(closest)


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
