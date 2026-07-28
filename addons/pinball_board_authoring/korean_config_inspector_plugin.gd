@tool
extends EditorInspectorPlugin

const ConfigPropertyPresentationRegistry := preload(
	"res://addons/pinball_board_authoring/config_property_presentation_registry.gd"
)

var _default_editor_creation_depth := 0


func _can_handle(object: Object) -> bool:
	return ConfigPropertyPresentationRegistry.supports(object)


func _parse_property(
	object: Object,
	type: Variant.Type,
	name: String,
	hint_type: PropertyHint,
	hint_string: String,
	usage_flags: int,
	wide: bool
) -> bool:
	# Godot 4.7.1 may call registered inspector plugins again while it creates the
	# default editor requested below. Let that nested call use Godot's default
	# path instead of recursively requesting another default editor.
	if _default_editor_creation_depth > 0:
		return false
	var presentation: Dictionary = ConfigPropertyPresentationRegistry.get_presentation(
		object,
		StringName(name)
	)
	if presentation.is_empty():
		return false
	var displayed_hint := _get_displayed_hint(hint_type, hint_string, presentation)
	_default_editor_creation_depth += 1
	var editor := EditorInspector.instantiate_property_editor(
		object,
		type,
		name,
		hint_type,
		displayed_hint,
		usage_flags,
		wide
	)
	_default_editor_creation_depth -= 1
	if editor == null:
		return false
	var label := String(presentation.get("label", name.capitalize()))
	var description := String(presentation.get("description", ""))
	var unit := String(presentation.get("unit", ""))
	if not unit.is_empty():
		description += "\n단위: %s" % unit
	editor.tooltip_text = description
	add_property_editor(name, editor, false, label)
	return true


func _get_displayed_hint(
	hint_type: PropertyHint,
	hint_string: String,
	presentation: Dictionary
) -> String:
	var suffix := String(presentation.get("suffix", ""))
	if hint_type != PROPERTY_HINT_RANGE or suffix.is_empty() or "suffix:" in hint_string:
		return hint_string
	if hint_string.is_empty():
		return "suffix:%s" % suffix
	return "%s,suffix:%s" % [hint_string, suffix]
