extends SceneTree

const APP_ROOT_SCENE := preload("res://app/bootstrap/app_root.tscn")
const SCREEN_IDS := preload("res://app/navigation/screen_ids.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app_root := APP_ROOT_SCENE.instantiate()
	root.add_child(app_root)
	await process_frame

	var navigator := app_root.get_node_or_null("ScreenNavigator")
	_expect(navigator != null, "ScreenNavigator가 존재해야 합니다.")
	if navigator == null:
		_finish(app_root)
		return

	_expect(
		navigator.current_screen_id == SCREEN_IDS.MAIN_LOBBY,
		"초기 화면은 메인 로비여야 합니다."
	)
	_expect(navigator.get_active_screen_count() == 1, "초기 활성 화면은 하나여야 합니다.")
	_expect(navigator.current_screen is Control, "메인 로비는 Control 루트여야 합니다.")

	var sequence: Array[StringName] = [
		SCREEN_IDS.STAGE_SELECTION,
		SCREEN_IDS.WAVE,
		SCREEN_IDS.REWARD,
		SCREEN_IDS.BOSS,
		SCREEN_IDS.RESULTS,
		SCREEN_IDS.MAIN_LOBBY,
	]

	for loop_index in 3:
		for target_screen_id in sequence:
			var accepted: bool = navigator.request_navigation(target_screen_id)
			_expect(
				accepted,
				"%d회차 화면 '%s' 전환이 승인돼야 합니다." % [loop_index + 1, target_screen_id]
			)
			await process_frame
			_expect(
				navigator.current_screen_id == target_screen_id,
				"요청한 화면 '%s'이 활성화돼야 합니다." % target_screen_id
			)
			_expect(
				navigator.get_active_screen_count() == 1,
				"화면 '%s' 전환 뒤 활성 화면은 하나여야 합니다." % target_screen_id
			)

			if target_screen_id in [SCREEN_IDS.WAVE, SCREEN_IDS.BOSS]:
				_expect(navigator.current_screen is Node3D, "%s 화면은 Node3D 루트여야 합니다." % target_screen_id)
			else:
				_expect(navigator.current_screen is Control, "%s 화면은 Control 루트여야 합니다." % target_screen_id)

	var active_before_rejection: Node = navigator.current_screen
	_expect(
		not navigator.request_navigation(navigator.current_screen_id),
		"현재 화면 재요청은 거부돼야 합니다."
	)
	_expect(
		not navigator.request_navigation(&"unknown_screen"),
		"알 수 없는 화면 요청은 거부돼야 합니다."
	)
	_expect(
		navigator.current_screen == active_before_rejection,
		"거부된 요청은 현재 화면을 보존해야 합니다."
	)
	_expect(navigator.get_active_screen_count() == 1, "거부된 요청 뒤 활성 화면은 하나여야 합니다.")

	_finish(app_root)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(app_root: Node) -> void:
	app_root.queue_free()
	await process_frame

	if _failures.is_empty():
		print("SCENE_NAVIGATION_SMOKE: PASS")
		quit(0)
		return

	for failure in _failures:
		push_error("SCENE_NAVIGATION_SMOKE: %s" % failure)
	quit(1)
