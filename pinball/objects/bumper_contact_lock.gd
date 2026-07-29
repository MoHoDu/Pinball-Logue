class_name BumperContactLock
extends RefCounted

var _active_contact_ids: Dictionary = {}


func try_begin(contact_id: StringName) -> bool:
	if contact_id == &"" or _active_contact_ids.has(contact_id):
		return false
	_active_contact_ids[contact_id] = true
	return true


func end(contact_id: StringName) -> bool:
	if contact_id == &"" or not _active_contact_ids.has(contact_id):
		return false
	_active_contact_ids.erase(contact_id)
	return true


func is_active(contact_id: StringName) -> bool:
	return contact_id != &"" and _active_contact_ids.has(contact_id)


func clear() -> void:
	_active_contact_ids.clear()


func get_active_count() -> int:
	return _active_contact_ids.size()
