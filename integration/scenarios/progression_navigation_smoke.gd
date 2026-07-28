extends SceneTree

const APP_ROOT_SCENE := preload("res://app/bootstrap/app_root.tscn")
const ACTIONS := preload("res://game_flow/progression_actions.gd")
const PHASES := preload("res://game_flow/progression_phases.gd")
const SCREEN_IDS := preload("res://app/navigation/screen_ids.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_full_button_flow()
	await _test_failure_and_retry_flow()
	_finish()


func _test_full_button_flow() -> void:
	var app_root := APP_ROOT_SCENE.instantiate()
	root.add_child(app_root)
	await process_frame
	var navigator: ScreenNavigator = app_root.get_navigator()
	_expect_screen(navigator, SCREEN_IDS.MAIN_LOBBY, "초기")

	await _press_current_button(navigator)
	_expect_progress(app_root, navigator, PHASES.STAGE_READY, SCREEN_IDS.STAGE_SELECTION, 1, 0)

	for stage_number in range(1, 4):
		await _press_current_button(navigator)
		_expect_progress(app_root, navigator, PHASES.NORMAL_WAVE, SCREEN_IDS.WAVE, stage_number, 1)

		for wave_number in range(1, 4):
			await _press_current_button(navigator)
			_expect_progress(app_root, navigator, PHASES.REWARD, SCREEN_IDS.REWARD, stage_number, wave_number)
			await _press_current_button(navigator)
			if wave_number < 3:
				_expect_progress(app_root, navigator, PHASES.NORMAL_WAVE, SCREEN_IDS.WAVE, stage_number, wave_number + 1)
			else:
				_expect_progress(app_root, navigator, PHASES.BOSS_WAVE, SCREEN_IDS.BOSS, stage_number, 3)

		await _press_current_button(navigator)
		var result_phase := PHASES.RUN_RESULT if stage_number == 3 else PHASES.STAGE_RESULT
		_expect_progress(app_root, navigator, result_phase, SCREEN_IDS.RESULTS, stage_number, 3)
		await _press_current_button(navigator)

		if stage_number < 3:
			_expect_progress(app_root, navigator, PHASES.STAGE_READY, SCREEN_IDS.STAGE_SELECTION, stage_number + 1, 0)
		else:
			_expect_progress(app_root, navigator, PHASES.RUN_INACTIVE, SCREEN_IDS.MAIN_LOBBY, 0, 0)

	app_root.queue_free()
	await process_frame


func _test_failure_and_retry_flow() -> void:
	var app_root := APP_ROOT_SCENE.instantiate()
	root.add_child(app_root)
	await process_frame
	var navigator: ScreenNavigator = app_root.get_navigator()

	await _press_current_button(navigator)
	await _press_current_button(navigator)
	_expect_progress(app_root, navigator, PHASES.NORMAL_WAVE, SCREEN_IDS.WAVE, 1, 1)

	var failure_result: ProgressionTransitionResult = app_root.request_progression_action(ACTIONS.WAVE_FAILED)
	_expect(failure_result.accepted, "활성 일반 웨이브 실패 결과가 승인돼야 합니다.")
	await process_frame
	_expect_progress(app_root, navigator, PHASES.STAGE_RESULT, SCREEN_IDS.RESULTS, 1, 1)

	var active_result_screen := navigator.current_screen
	var duplicate_result: ProgressionTransitionResult = app_root.request_progression_action(ACTIONS.WAVE_FAILED)
	_expect(not duplicate_result.accepted, "중복 실패 결과가 거부돼야 합니다.")
	_expect(navigator.current_screen == active_result_screen, "거부된 실패 결과는 결과 화면을 보존해야 합니다.")

	await _press_current_button(navigator)
	_expect_progress(app_root, navigator, PHASES.NORMAL_WAVE, SCREEN_IDS.WAVE, 1, 1)

	app_root.queue_free()
	await process_frame


func _press_current_button(navigator: ScreenNavigator) -> void:
	var screen := navigator.current_screen as NavigableScreen
	if screen == null and navigator.current_screen_id == SCREEN_IDS.WAVE:
		navigator.current_screen.emit_signal(&"progression_requested", ACTIONS.WAVE_CLEARED)
		await process_frame
		return
	_expect(screen != null, "현재 화면이 진행 요청을 제공해야 합니다.")
	if screen == null:
		return
	var button := screen.get_node_or_null(screen.next_button_path) as Button
	_expect(button != null, "현재 화면의 진행 버튼이 존재해야 합니다.")
	if button == null:
		return
	button.pressed.emit()
	await process_frame


func _expect_progress(
	app_root: AppRoot,
	navigator: ScreenNavigator,
	expected_phase: StringName,
	expected_screen_id: StringName,
	expected_stage_number: int,
	expected_wave_number: int
) -> void:
	var progression := app_root.get_progression()
	_expect(progression.get_phase() == expected_phase, "진행 단계가 '%s'이어야 합니다." % expected_phase)
	_expect(progression.get_current_stage_number() == expected_stage_number, "현재 스테이지가 %d이어야 합니다." % expected_stage_number)
	_expect(progression.get_current_normal_wave_number() == expected_wave_number, "현재 일반 웨이브가 %d이어야 합니다." % expected_wave_number)
	_expect_screen(navigator, expected_screen_id, "진행 단계 '%s'" % expected_phase)


func _expect_screen(navigator: ScreenNavigator, expected_screen_id: StringName, context: String) -> void:
	_expect(navigator.current_screen_id == expected_screen_id, "%s 화면은 '%s'이어야 합니다." % [context, expected_screen_id])
	_expect(navigator.get_active_screen_count() == 1, "%s 활성 화면은 하나여야 합니다." % context)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PROGRESSION_NAVIGATION_SMOKE: PASS")
		quit(0)
		return

	for failure in _failures:
		push_error("PROGRESSION_NAVIGATION_SMOKE: %s" % failure)
	quit(1)
