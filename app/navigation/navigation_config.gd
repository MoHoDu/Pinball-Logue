class_name NavigationConfig
extends Resource

@export var initial_screen_id: StringName = ScreenIds.MAIN_LOBBY
@export var routes: Array[ScreenRoute] = []


func get_screen_scene(screen_id: StringName) -> PackedScene:
	for route in routes:
		if route != null and route.screen_id == screen_id:
			return route.scene
	return null


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary = {}

	if initial_screen_id == &"":
		errors.append("초기 화면 식별자가 비어 있습니다.")

	for route_index in routes.size():
		var route := routes[route_index]
		if route == null:
			errors.append("경로 목록의 %d번 항목이 비어 있습니다." % route_index)
			continue

		var route_error := route.get_validation_error()
		if not route_error.is_empty():
			errors.append(route_error)
			continue

		if seen_ids.has(route.screen_id):
			errors.append("중복 화면 식별자: %s" % route.screen_id)
			continue

		seen_ids[route.screen_id] = true

	if not seen_ids.has(initial_screen_id):
		errors.append("초기 화면 '%s'이 경로 목록에 없습니다." % initial_screen_id)

	return errors
