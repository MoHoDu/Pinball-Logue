@tool
class_name BumperDefinition
extends BoardPlaceableDefinition

const BUMPER_TYPE_NORMAL := &"normal"
const BUMPER_TYPE_BOUNCE := &"bounce"
const BUMPER_TYPE_TRACK := &"track"
const BUMPER_TYPE_SHOT := &"shot"

@export_category("범퍼")
@export_enum("normal", "bounce", "track", "shot") var bumper_type := "normal"

@export_category("충돌과 타격")
# 프로토타입 후보값이다. 보드·공 크기별 QA 뒤 원형 복제본에서 조정한다.
@export_range(0.005, 0.2, 0.001) var collision_radius_board_ratio := 0.04
@export_range(1, 1000000, 1) var durability_damage_per_hit := 1
@export_range(0, 100000000, 1) var base_score_value := 100

@export_category("안전 복구")
@export var recovery_enabled := true
@export_range(0.1, 60.0, 0.05) var recovery_seconds := 4.0
# 프로토타입 후보값이다. 실제 예고 가독성과 공 속도를 함께 검증한다.
@export_range(0.0, 10.0, 0.05) var recovery_warning_seconds := 0.75
# 프로토타입 후보값이다. 공과 겹친 채 복구되지 않는 최소 여백이다.
@export_range(0.0, 0.1, 0.001) var recovery_safe_margin_board_ratio := 0.01

@export_category("종류별 반응")
@export_range(1.0, 5.0, 0.05) var bounce_speed_multiplier := 1.2
# 프로토타입 후보값이다. Track 경로의 실제 길이와 함께 조정한다.
@export_range(0.1, 10.0, 0.05) var track_speed_board_per_second := 1.2
# 프로토타입 후보값이다. Shot 목표 지점까지의 거리와 함께 조정한다.
@export_range(0.1, 10.0, 0.05) var shot_speed_board_per_second := 1.5
@export_range(0.0, 180.0, 0.5) var shot_direction_error_degrees := 0.0


func _init() -> void:
	object_type = String(OBJECT_TYPE_BUMPER)


static func get_supported_bumper_types() -> Array[StringName]:
	return [
		BUMPER_TYPE_NORMAL,
		BUMPER_TYPE_BOUNCE,
		BUMPER_TYPE_TRACK,
		BUMPER_TYPE_SHOT,
	]


func get_bumper_type_id() -> StringName:
	return StringName(bumper_type)


func get_validation_errors() -> PackedStringArray:
	var errors := super.get_validation_errors()
	if get_object_type_id() != OBJECT_TYPE_BUMPER:
		errors.append("범퍼 원형의 오브젝트 종류는 범퍼여야 합니다: %s" % display_name)
	if not get_supported_bumper_types().has(get_bumper_type_id()):
		errors.append("지원하지 않는 범퍼 종류입니다: %s" % bumper_type)
	_validate_positive_finite(collision_radius_board_ratio, "범퍼 충돌 반지름", errors)
	if durability_damage_per_hit <= 0:
		errors.append("타격당 내구도 감소량은 1 이상이어야 합니다.")
	if base_score_value < 0:
		errors.append("기본 점수 근거는 0 이상이어야 합니다.")
	_validate_positive_finite(recovery_seconds, "범퍼 복구 대기", errors)
	_validate_non_negative_finite(recovery_warning_seconds, "범퍼 복구 예고", errors)
	_validate_non_negative_finite(
		recovery_safe_margin_board_ratio,
		"범퍼 안전 복구 여백",
		errors
	)
	_validate_positive_finite(bounce_speed_multiplier, "반동 속도 배율", errors)
	if bounce_speed_multiplier < 1.0:
		errors.append("반동 속도 배율은 1 이상이어야 합니다.")
	_validate_positive_finite(track_speed_board_per_second, "경로 이동 속도", errors)
	_validate_positive_finite(shot_speed_board_per_second, "목표 발사 속도", errors)
	_validate_non_negative_finite(shot_direction_error_degrees, "목표 방향 오차", errors)
	if shot_direction_error_degrees > 180.0:
		errors.append("목표 방향 오차는 180도 이하여야 합니다.")
	return errors


func _validate_positive_finite(
	value: float,
	label: String,
	errors: PackedStringArray
) -> void:
	if not is_finite(value) or value <= 0.0:
		errors.append("%s은(는) 유한한 양수여야 합니다." % label)


func _validate_non_negative_finite(
	value: float,
	label: String,
	errors: PackedStringArray
) -> void:
	if not is_finite(value) or value < 0.0:
		errors.append("%s은(는) 유한한 0 이상의 값이어야 합니다." % label)
