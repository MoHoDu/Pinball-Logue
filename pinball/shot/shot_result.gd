class_name ShotResult
extends RefCounted

var request_id: StringName = &""
var shot_id: StringName = &""
var slot_id: StringName = &""
var ball_id: StringName = &""
var end_reason: StringName = &""
var launch_solution: LaunchSolution
var final_snapshot: BallPhysicsSnapshot


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if request_id == &"":
		errors.append("발사 결과의 요청 식별자가 비어 있습니다.")
	if shot_id == &"":
		errors.append("발사 결과의 발사 식별자가 비어 있습니다.")
	if slot_id == &"":
		errors.append("발사 결과의 공 슬롯 식별자가 비어 있습니다.")
	if ball_id == &"":
		errors.append("발사 결과의 공 식별자가 비어 있습니다.")
	if not ShotEndReasons.is_supported(end_reason):
		errors.append("지원하지 않는 발사 종료 이유입니다: %s" % end_reason)
	if launch_solution == null or not launch_solution.is_valid():
		errors.append("발사 결과에 유효한 발사 계산 결과가 없습니다.")
	if final_snapshot == null:
		errors.append("발사 결과에 마지막 공 물리 상태가 없습니다.")
	else:
		errors.append_array(final_snapshot.get_validation_errors())
		if final_snapshot.shot_id != shot_id:
			errors.append("마지막 공 물리 상태의 발사 식별자가 결과와 다릅니다.")
		if final_snapshot.slot_id != slot_id:
			errors.append("마지막 공 물리 상태의 공 슬롯이 결과와 다릅니다.")
		if final_snapshot.ball_id != ball_id:
			errors.append("마지막 공 물리 상태의 공 식별자가 결과와 다릅니다.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()
