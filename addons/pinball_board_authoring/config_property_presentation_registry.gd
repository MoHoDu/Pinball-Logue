@tool
extends RefCounted

# 내부 영문 속성명은 .tres 직렬화와 코드 계약으로 유지한다.
# 이 표는 Godot 인스펙터와 미래 개발자 모드가 공유할 사람용 표시 정보만 제공한다.
static var PRESENTATIONS: Dictionary = {
	"ProgressionConfig": {
		"stage_count": _entry("스테이지 수", "한 런에서 진행할 전체 스테이지 수입니다.", "개"),
		"normal_wave_count": _entry("일반 웨이브 수", "한 스테이지에서 보스 전에 진행할 일반 웨이브 수입니다.", "개"),
	},
	"NavigationConfig": {
		"initial_screen_id": _entry("최초 화면", "게임을 시작했을 때 가장 먼저 표시할 화면입니다."),
		"routes": _entry("화면 연결 목록", "화면 이름과 실제 씬을 연결하는 목록입니다."),
	},
	"ScreenRoute": {
		"screen_id": _entry("화면 이름", "화면 전환에서 사용하는 변경되지 않는 내부 이름입니다."),
		"scene": _entry("연결할 화면 씬", "이 화면 이름으로 이동할 때 표시할 Godot 씬입니다."),
	},
	"BoardLayoutConfig": {
		"boundary_points": _entry("보드 외곽선", "보드 모양을 이루는 정규화 좌표의 꼭짓점 목록입니다."),
		"anchors": _entry("배치 지점", "발사·드레인·범퍼·플리퍼·유물·일반 오브젝트와 범퍼 경로·목표를 표시하는 자리입니다."),
		"launch_anchor_id": _entry("발사 지점", "공을 생성하고 발사를 시작할 배치 지점 이름입니다."),
		"drain_anchor_id": _entry("드레인 지점", "공이 낙하한 것으로 판정할 배치 지점 이름입니다."),
	},
	"BoardAnchorConfig": {
		"anchor_id": _entry("배치 지점 이름", "웨이브 배치가 이 자리를 찾을 때 사용하는 고유 이름입니다."),
		"anchor_type": _entry("배치 지점 역할", "이 자리에 배치할 수 있는 오브젝트 역할입니다."),
		"board_position": _entry("보드 위치", "보드 중심을 기준으로 한 -0.5~0.5 범위의 위치입니다.", "보드 비율"),
		"rotation_degrees": _entry("회전", "보드 평면에서 오브젝트가 바라보는 방향입니다.", "°", "°"),
		"snap_to_boundary": _entry("외곽선에 붙이기", "플리퍼 지점을 보드 외곽선에 고정합니다."),
		"boundary_edge_index": _entry("외곽선 변 번호", "플리퍼가 붙어 있는 외곽선 구간의 번호입니다."),
		"boundary_edge_offset": _entry("외곽선 위 위치", "선택한 외곽선 구간에서 플리퍼가 있는 0~1 위치입니다.", "비율"),
	},
	"BoardViewConfig": {
		"view_angle_degrees": _entry("보드 시점 각도", "보드 상단이 좁아 보이는 정도를 조절합니다.", "°", "°"),
		"board_size": _entry("보드 표시 크기", "2D 목업에서 보드를 표시할 기준 너비와 높이입니다.", "px"),
		"rail_width": _entry("레일 두께", "2D 목업의 보드 외곽 레일 두께입니다.", "px", "px"),
		"board_color": _entry("보드 색상", "2D 목업의 보드 바닥 색상입니다."),
		"rail_color": _entry("레일 색상", "2D 목업의 외곽 레일 색상입니다."),
		"lane_color": _entry("경로 색상", "2D 목업에서 이동 경로를 구분하는 색상입니다."),
		"bumper_color": _entry("범퍼 색상", "기본 범퍼 미리보기 색상입니다."),
		"accent_color": _entry("강조 색상", "발사·드레인 등 강조 표식에 사용하는 색상입니다."),
		"bumper_radius": _entry("범퍼 바깥 반지름", "기본 범퍼 미리보기의 바깥 크기입니다.", "px", "px"),
		"bumper_inner_radius": _entry("범퍼 안쪽 반지름", "기본 범퍼 미리보기의 안쪽 크기입니다.", "px", "px"),
		"flipper_length": _entry("플리퍼 길이", "기본 플리퍼 미리보기의 길이입니다.", "px", "px"),
		"flipper_width": _entry("플리퍼 너비", "기본 플리퍼 미리보기의 너비입니다.", "px", "px"),
		"flipper_pivot_radius": _entry("플리퍼 회전축 반지름", "기본 플리퍼 회전축 표식의 크기입니다.", "px", "px"),
		"launch_marker_radius": _entry("발사 지점 표식 반지름", "공 대신 표시하는 발사 지점 표식의 크기입니다.", "px", "px"),
		"relic_slot_radius": _entry("유물 지점 반지름", "유물 배치 지점 미리보기의 크기입니다.", "px", "px"),
		"drain_width": _entry("드레인 너비", "낙하 구간 미리보기의 너비입니다.", "px", "px"),
	},
	"PlayableBoard2D": {
		"composition_override": _entry("시험할 웨이브 배치", "기본 파일을 바꾸지 않고 이번 플레이 화면에서 시험할 웨이브 배치 복제본입니다."),
		"rail_collision_width": _entry("레일 충돌 두께", "공이 보드 외곽선을 통과하지 않게 하는 실제 충돌 레일의 두께입니다.", "px", "px"),
		"drain_sensor_depth": _entry("드레인 감지 깊이", "공이 드레인을 지난 것으로 감지할 영역의 깊이입니다.", "px", "px"),
		"out_of_bounds_margin": _entry("보드 밖 종료 여백", "공이 이 여백 밖으로 나가면 안전하게 낙하 처리합니다.", "px", "px"),
	},
	"WaveBoardCompositionConfig": {
		"layout_config": _entry("보드 설계도", "이 웨이브 배치가 사용할 보드 외곽선과 배치 지점입니다."),
		"assignments": _entry("웨이브 배치", "각 배치 지점에 놓을 오브젝트 원형의 목록입니다."),
		"flipper_control_targets": _entry("플리퍼 조작 대상", "방향키 하나로 작동할 왼쪽만·오른쪽만·좌우 쌍 플리퍼 묶음입니다."),
	},
	"BoardPlacementAssignmentConfig": {
		"point_id": _entry("배치 지점", "오브젝트를 놓을 보드 배치 지점의 이름입니다."),
		"content_id": _entry("오브젝트 원형", "선택한 지점에 배치할 범퍼·벽·플리퍼·유물 등의 원형 이름입니다."),
		"track_point_ids": _entry("경로 지점 순서", "경로 범퍼가 공을 안내할 경로 지점 이름을 이동 순서대로 지정합니다."),
		"shot_target_point_id": _entry("발사 목표 지점", "발사 범퍼가 공을 내보낼 목표 지점 이름입니다."),
	},
	"FlipperControlTargetConfig": {
		"mode": _entry("작동 방식", "왼쪽만·오른쪽만·좌우 쌍 중 이 방향키로 함께 작동할 방식을 고릅니다."),
		"left_point_id": _entry("왼쪽 플리퍼 지점", "왼쪽 플리퍼로 사용할 배치 지점 이름입니다."),
		"right_point_id": _entry("오른쪽 플리퍼 지점", "오른쪽 플리퍼로 사용할 배치 지점 이름입니다."),
	},
	"BoardPlaceableDefinition": {
		"content_id": _entry("오브젝트 원형 ID", "다른 웨이브에서도 바뀌지 않는 오브젝트의 고유 이름입니다."),
		"display_name": _entry("표시 이름", "기획자가 제작 도구에서 알아볼 수 있는 이름입니다."),
		"object_type": _entry("오브젝트 종류", "범퍼·벽·일반 오브젝트·플리퍼·유물 미리보기 중 역할입니다."),
		"indestructible": _entry("파괴되지 않음", "사용하면 내구도가 줄어도 이 오브젝트는 파괴되지 않습니다."),
		"max_durability": _entry("최대 내구도", "파괴 가능한 오브젝트가 버틸 수 있는 최대 타격 기준입니다.", "내구도"),
	},
	"BumperDefinition": {
		"bumper_type": _entry("범퍼 종류", "일반·반동·트랙·샷 중 범퍼의 규칙 종류입니다."),
		"collision_radius_board_ratio": _entry("충돌 반지름", "공이 이 범퍼와 접촉하는 보드 너비 기준 반지름입니다.", "보드 비율"),
		"durability_damage_per_hit": _entry("타격당 내구도 감소", "한 번의 유효한 타격에서 감소할 내구도입니다.", "내구도"),
		"base_score_value": _entry("기본 점수 근거", "7단계 점수 시스템에 전달할 범퍼의 기본 점수 근거입니다.", "점"),
		"recovery_enabled": _entry("파괴 후 복구", "내구도가 0이 된 범퍼를 안전 확인 뒤 다시 활성화합니다."),
		"recovery_seconds": _entry("복구 대기 시간", "파괴된 뒤 안전 복구 확인을 시작하기까지 기다리는 시간입니다.", "초"),
		"recovery_warning_seconds": _entry("복구 예고 시간", "안전 확인 뒤 범퍼가 다시 활성화되기 전에 예고하는 시간입니다.", "초"),
		"recovery_safe_margin_board_ratio": _entry("안전 복구 여백", "공과 겹친 채 복구하지 않도록 충돌 영역 바깥에 더하는 여백입니다.", "보드 비율"),
		"bounce_speed_multiplier": _entry("반동 속도 배율", "반동 범퍼가 기본 반사 속도에 곱하는 값입니다.", "배"),
		"track_speed_board_per_second": _entry("경로 이동 속도", "경로 범퍼가 공을 경로 지점 사이로 안내하는 속도입니다.", "보드 폭/초"),
		"shot_speed_board_per_second": _entry("목표 발사 속도", "발사 범퍼가 공을 목표 지점 방향으로 내보내는 속도입니다.", "보드 폭/초"),
		"shot_direction_error_degrees": _entry("목표 방향 오차", "발사 목표 방향에 적용할 최대 오차입니다. 0이면 정확히 목표를 향합니다.", "°", "°"),
	},
	"FlipperDefinition": {
		"motion_profile": _entry("플리퍼 작동 설정", "플리퍼의 크기·회전 시간·복귀 시간·공 패링 힘을 모아 둔 설정입니다."),
	},
	"FlipperMotionProfile": {
		"length_board_ratio": _entry("플리퍼 길이", "보드 너비를 기준으로 한 플리퍼의 길이입니다.", "보드 비율"),
		"width_board_ratio": _entry("플리퍼 너비", "보드 너비를 기준으로 한 플리퍼의 두께입니다.", "보드 비율"),
		"activation_angle_degrees": _entry("작동 회전 각도", "Space를 눌렀을 때 쉬는 위치에서 회전하는 각도입니다.", "°", "°"),
		"activation_seconds": _entry("올라가는 시간", "플리퍼가 쉬는 위치에서 타격 위치까지 움직이는 시간입니다.", "초"),
		"hold_seconds": _entry("타격 위치 유지 시간", "플리퍼가 가장 올라간 위치에 머무는 시간입니다.", "초"),
		"return_seconds": _entry("돌아오는 시간", "플리퍼가 타격 위치에서 쉬는 위치로 자동 복귀하는 시간입니다.", "초"),
		"base_hit_impulse_board_per_second": _entry("기본 타격 힘", "플리퍼가 공을 밀어내는 기본 힘입니다.", "보드 폭/초"),
		"parry_window_seconds": _entry("공 패링 시간", "작동 직후 추가 타격 힘을 받을 수 있는 짧은 시간입니다.", "초"),
		"parry_impulse_multiplier": _entry("공 패링 힘 배수", "공 패링 시간에 맞춘 충돌의 추가 힘 배수입니다.", "배"),
	},
	"BoardObjectPresentation2D": {
		"content_id": _entry("오브젝트 원형 ID", "2D 디자인과 연결할 오브젝트 원형의 고유 이름입니다."),
		"scene_2d": _entry("2D 디자인", "현재 2D 목업에서 사용할 재사용 씬입니다."),
	},
	"BoardObjectPresentation2DCatalog": {
		"presentations": _entry("2D 디자인 연결표", "오브젝트 원형별 2D 재사용 씬의 목록입니다."),
	},
	"BallDefinition": {
		"ball_id": _entry("공 식별자", "선택·발사·결과에서 같은 공인지 구분하는 고유 이름입니다."),
		"display_name": _entry("표시 이름", "공 선택 화면과 개발자 모드에 표시할 이름입니다."),
		"description": _entry("설명", "기획자가 공의 역할을 이해할 수 있는 쉬운 설명입니다."),
		"presentation_id": _entry("디자인 연결 키", "같은 공 규칙을 현재 2D 또는 미래 3D 디자인과 연결하는 이름입니다."),
		"physics_profile": _entry("공 물리 설정", "공의 크기·질량·반발력·마찰과 안전 속도를 모아 둔 설정입니다."),
	},
	"BallPhysicsProfile": {
		"radius_board_ratio": _entry("공 반지름", "보드 너비에 대한 공 반지름 비율입니다.", "보드 비율"),
		"mass": _entry("질량", "충돌할 때 공이 힘을 주고받는 기준 질량입니다."),
		"bounce": _entry("반발력", "충돌한 뒤 공이 튀어 나오는 정도입니다.", "0~1"),
		"friction": _entry("마찰", "표면을 따라 움직일 때 속도가 줄어드는 정도입니다.", "0~1"),
		"gravity_scale": _entry("중력 영향", "보드 아래쪽으로 받는 중력의 배율입니다.", "배율"),
		"linear_damping": _entry("직선 감쇠", "공의 직선 이동 속도가 자연스럽게 줄어드는 정도입니다."),
		"angular_damping": _entry("회전 감쇠", "공의 회전 속도가 자연스럽게 줄어드는 정도입니다."),
		"max_linear_speed_board_per_second": _entry("최대 직선 속도", "과속을 막는 보드 너비 기준 속도 상한입니다.", "보드 폭/초"),
		"max_angular_speed_radians": _entry("최대 회전 속도", "과도한 회전을 막는 회전 속도 상한입니다.", "rad/s", "rad/s"),
		"continuous_collision_detection": _entry("연속 충돌 검사", "빠른 공이 얇은 벽을 통과하는 현상을 줄입니다."),
		"can_sleep": _entry("물리 휴면 허용", "공이 매우 느릴 때 물리 계산을 멈출 수 있는지 결정합니다."),
	},
	"WaveBallLoadoutConfig": {
		"slots": _entry("가져갈 공 목록", "웨이브에 가져갈 공 1~3개의 순서 있는 목록입니다."),
	},
	"WaveBallSlotConfig": {
		"slot_id": _entry("공 슬롯 이름", "숫자키 1·2·3과 연결되는 공 자리의 고유 이름입니다."),
		"ball_definition": _entry("공 원형", "이 슬롯에서 선택하고 발사할 공의 규칙 설정입니다."),
	},
	"LaunchConfig": {
		"aim_mode": _entry("조준 방식", "방향키 조준 또는 마우스 조준 중 사용할 방식을 선택합니다."),
		"default_aim_angle_degrees": _entry("기본 조준 각도", "조준을 시작할 때 발사 지점 안쪽을 기준으로 한 각도입니다.", "°", "°"),
		"minimum_aim_angle_degrees": _entry("최소 조준 각도", "조준할 수 있는 부채꼴의 왼쪽 경계입니다.", "°", "°"),
		"maximum_aim_angle_degrees": _entry("최대 조준 각도", "조준할 수 있는 부채꼴의 오른쪽 경계입니다.", "°", "°"),
		"keyboard_angle_step_degrees": _entry("방향키 각도 변화량", "좌우 방향키 입력 한 번에 바뀌는 조준 각도입니다.", "°", "°"),
		"keyboard_strength_step": _entry("방향키 세기 변화량", "상하 방향키 입력 한 번에 바뀌는 발사 세기입니다.", "0~1"),
		"default_strength": _entry("기본 발사 세기", "조준을 시작할 때 사용하는 발사 세기입니다.", "0~1"),
		"minimum_speed_board_per_second": _entry("최소 발사 속도", "가장 약하게 발사할 때의 보드 너비 기준 속도입니다.", "보드 폭/초"),
		"maximum_speed_board_per_second": _entry("최대 발사 속도", "가장 강하게 발사할 때의 보드 너비 기준 속도입니다.", "보드 폭/초"),
		"mouse_max_distance_board_ratio": _entry("마우스 최대 조준 거리", "최대 발사 세기가 되는 마우스와 발사 지점 사이 거리입니다.", "보드 비율"),
		"aim_guide_length_board_ratio": _entry("조준선 길이", "예상 발사 방향을 보여 주는 선의 길이입니다.", "보드 비율"),
	},
	"ScoreConfig": {
		"combo_window_seconds": _entry("콤보 시간", "이 시간 안에 다음 범퍼를 타격하면 콤보가 이어집니다.", "초"),
		"multiplier_step": _entry("타격당 배수 증가", "콤보가 한 번 늘 때마다 스코어 배수가 증가하는 양입니다.", "배"),
		"maximum_multiplier": _entry("최대 스코어 배수", "콤보로 올라갈 수 있는 스코어 배수의 상한입니다.", "배"),
	},
	"ScoreObjectiveConfig": {
		"target_score": _entry("목표 스코어", "공을 모두 사용한 뒤 웨이브 성공 여부를 판단하는 기준 스코어입니다.", "점"),
	},
}


static func get_presentation_for_class(
	class_name_value: StringName,
	property_name: StringName
) -> Dictionary:
	var class_presentations: Dictionary = PRESENTATIONS.get(String(class_name_value), {})
	return class_presentations.get(String(property_name), {})


static func get_presentation(object: Object, property_name: StringName) -> Dictionary:
	if object == null:
		return {}
	var script := object.get_script() as Script
	while script != null:
		var global_name := script.get_global_name()
		var presentation := get_presentation_for_class(global_name, property_name)
		if not presentation.is_empty():
			return presentation
		script = script.get_base_script()
	return {}


static func supports(object: Object) -> bool:
	if object == null:
		return false
	var script := object.get_script() as Script
	while script != null:
		if PRESENTATIONS.has(String(script.get_global_name())):
			return true
		script = script.get_base_script()
	return false


static func _entry(
	label: String,
	description: String,
	unit: String = "",
	suffix: String = ""
) -> Dictionary:
	return {
		"label": label,
		"description": description,
		"unit": unit,
		"suffix": suffix,
	}
