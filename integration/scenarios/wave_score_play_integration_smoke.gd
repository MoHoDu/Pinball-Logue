extends SceneTree

const WAVE_SCENE := preload("res://app/navigation/screens/wave_screen.tscn")

var _failures := PackedStringArray()
var _progression_actions: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := WAVE_SCENE.instantiate() as WavePlayScreen
	screen.score_objective = screen.score_objective.duplicate(true) as ScoreObjectiveConfig
	screen.score_objective.target_score = 250
	screen.progression_requested.connect(_progression_actions.append)
	root.add_child(screen)
	await process_frame
	var router := screen.get_node("WaveInputRouter") as WaveInputRouter
	var board := screen.get_node("PlayableBoard2D") as PlayableBoard2D
	router._unhandled_input(_space_event())
	router._unhandled_input(_space_event())
	_expect(screen.get_shot_phase() == ShotPhases.IN_PLAY, "스코어 통합 검사의 공이 발사되지 않았습니다.")
	var shot_id := screen.get_active_shot_id()
	screen._on_bumper_hit_applied(_make_hit(&"score_play_1", shot_id, 100))
	screen._on_bumper_hit_applied(_make_hit(&"score_play_2", shot_id, 100))
	_expect(screen.get_current_score() == 250, "두 타격 스코어가 250점이 아닙니다: %d" % screen.get_current_score())
	_expect(screen.is_score_target_reached(), "목표 스코어 도달 상태가 켜지지 않았습니다.")
	_expect(not screen.is_wave_mockup_complete(), "목표 달성 즉시 웨이브가 종료됐습니다.")
	_expect(screen.get_shot_phase() == ShotPhases.IN_PLAY, "목표 달성 즉시 현재 발사가 종료됐습니다.")
	_expect(_progression_actions.is_empty(), "목표 달성 즉시 진행 결과를 보냈습니다.")
	var score_label := screen.get_node("Overlay/LeftPanel/Content/Score") as Label
	_expect("현재 공 계속 진행" in score_label.text, "목표 달성 뒤 현재 공 진행 안내가 HUD에 없습니다.")
	screen._on_bumper_hit_applied(_make_hit(&"score_play_3", shot_id, 100))
	_expect(screen.get_current_score() == 450, "목표 달성 뒤 추가 득점이 반영되지 않았습니다: %d" % screen.get_current_score())
	board.ball_exit_detected.emit(shot_id, ShotEndReasons.DRAIN)
	board.ball_exit_detected.emit(shot_id, ShotEndReasons.DRAIN)
	await process_frame
	await process_frame
	_expect(screen.is_wave_mockup_complete(), "목표 달성 공 낙하 뒤 웨이브가 종료되지 않았습니다.")
	_expect(screen.get_remaining_ball_count() == 2, "클리어 시 사용한 공만 한 개 소모되지 않았습니다.")
	_expect(_progression_actions == [ProgressionActions.WAVE_CLEARED], "웨이브 클리어 결과가 정확히 한 번 발생하지 않았습니다: %s" % [_progression_actions])
	var score_after_finish := screen.get_current_score()
	screen._on_bumper_hit_applied(_make_hit(&"delayed_hit", shot_id, 1000))
	_expect(screen.get_current_score() == score_after_finish, "종료 뒤 지연 타격이 최종 스코어를 바꿨습니다.")
	screen.queue_free()
	_finish()


func _make_hit(hit_id: StringName, shot_id: StringName, base_score: int) -> BumperHitResult:
	var hit := BumperHitResult.new()
	hit.is_applied = true
	hit.hit_id = hit_id
	hit.contact_id = StringName("contact_%s" % hit_id)
	hit.shot_id = shot_id
	hit.ball_id = &"standard_ball"
	hit.point_id = &"bumper_score"
	hit.content_id = &"bumper_normal"
	hit.bumper_type = BumperDefinition.BUMPER_TYPE_NORMAL
	hit.effect_type = BumperHitResult.EFFECT_NORMAL_REFLECT
	hit.contact_time_fraction = 0.0
	hit.contact_board_position = Vector2.ZERO
	hit.contact_board_normal = Vector2.UP
	hit.incoming_board_velocity = Vector2(0.0, 1.0)
	hit.reflected_board_velocity = Vector2(0.0, -1.0)
	hit.collision_strength_board_per_second = 1.0
	hit.base_score_value = base_score
	hit.durability_before = 3
	hit.durability_after = 2
	hit.output_board_velocity = Vector2(0.0, -1.0)
	return hit


func _space_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("WAVE_SCORE_PLAY_INTEGRATION_SMOKE: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("WAVE_SCORE_PLAY_INTEGRATION_SMOKE: %s" % failure)
	quit(1)
