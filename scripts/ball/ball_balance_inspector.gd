extends CanvasLayer


@export var ball: Ball
@export var start_visible: bool = true


var panel: PanelContainer
var telemetry_label: Label

var editors: Dictionary = {}
var syncing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if ball == null:
		push_error(
			"BalanceInspector의 Ball 항목에 "
			+ "TestBoard의 Ball 노드를 연결하세요."
		)
		return

	_build_interface()

	panel.visible = start_visible

	_sync_editors()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(
		"toggle_balance_panel"
	):
		return

	var key_event := event as InputEventKey

	if key_event != null and key_event.echo:
		return

	panel.visible = not panel.visible

	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if ball == null:
		return

	if telemetry_label == null:
		return

	var current_speed := ball.get_current_speed()

	telemetry_label.text = (
		"상태: %s\n"
		+ "조준 각도: %.1f°\n"
		+ "현재 속도: %.1f px/s\n"
		+ "60FPS 환산: %.2f px/frame\n"
		+ "최대 속도 제한: %d회\n"
		+ "최소 속도 복구: %d회"
	) % [
		ball.get_state_name(),
		ball.aim_angle_deg,
		current_speed,
		current_speed / 60.0,
		ball.max_clamp_count,
		ball.min_recovery_count
	]


func _build_interface() -> void:
	panel = PanelContainer.new()
	panel.name = "BallBalancePanel"

	add_child(panel)

	panel.set_anchors_preset(
		Control.PRESET_TOP_RIGHT
	)

	panel.offset_left = -430.0
	panel.offset_top = 20.0
	panel.offset_right = -20.0
	panel.offset_bottom = 760.0

	var margin := MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		16
	)

	margin.add_theme_constant_override(
		"margin_right",
		16
	)

	margin.add_theme_constant_override(
		"margin_top",
		16
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		16
	)

	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	margin.add_child(scroll)

	var content := VBoxContainer.new()

	content.custom_minimum_size = Vector2(
		360.0,
		0.0
	)

	content.add_theme_constant_override(
		"separation",
		8
	)

	scroll.add_child(content)

	_add_title(content)
	_add_balance_editors(content)
	_add_action_buttons(content)
	_add_telemetry(content)


func _add_title(
	content: VBoxContainer
) -> void:
	var title := Label.new()

	title.text = "BALL BALANCE INSPECTOR"

	title.add_theme_font_size_override(
		"font_size",
		22
	)

	content.add_child(title)

	var help := Label.new()

	help.text = (
		"F1: 패널 숨김/표시\n"
		+ "← →: 조준\n"
		+ "↑ / Space: 발사\n"
		+ "R: 공 리셋"
	)

	content.add_child(help)

	content.add_child(
		HSeparator.new()
	)


func _add_balance_editors(
	content: VBoxContainer
) -> void:
	_add_number_editor(
		content,
		"공 반지름",
		&"radius_px",
		12.0,
		40.0,
		1.0
	)

	_add_number_editor(
		content,
		"최소 속도",
		&"min_speed",
		50.0,
		1000.0,
		10.0
	)

	_add_number_editor(
		content,
		"발사 속도",
		&"launch_speed",
		100.0,
		2000.0,
		10.0
	)

	_add_number_editor(
		content,
		"최대 속도",
		&"max_speed",
		300.0,
		3000.0,
		10.0
	)

	_add_number_editor(
		content,
		"반발력",
		&"bounce",
		0.0,
		1.0,
		0.01
	)

	_add_number_editor(
		content,
		"마찰",
		&"friction",
		0.0,
		1.0,
		0.01
	)

	_add_number_editor(
		content,
		"저속 복구 대기",
		&"low_speed_grace",
		0.0,
		1.0,
		0.01
	)

	_add_number_editor(
		content,
		"조준 이동 속도",
		&"aim_turn_speed_deg",
		20.0,
		360.0,
		5.0
	)

	_add_number_editor(
		content,
		"조준선 휘어짐",
		&"aim_curve_strength",
		0.0,
		0.8,
		0.01
	)


func _add_number_editor(
	parent: VBoxContainer,
	label_text: String,
	property_name: StringName,
	minimum: float,
	maximum: float,
	step_value: float
) -> void:
	var row := HBoxContainer.new()

	parent.add_child(row)

	var label := Label.new()

	label.text = label_text
	label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	row.add_child(label)

	var editor := SpinBox.new()

	editor.custom_minimum_size = Vector2(
		145.0,
		0.0
	)

	editor.min_value = minimum
	editor.max_value = maximum
	editor.step = step_value

	editor.allow_greater = false
	editor.allow_lesser = false

	editor.value_changed.connect(
		_on_editor_changed.bind(
			property_name
		)
	)

	row.add_child(editor)

	editors[property_name] = editor


func _on_editor_changed(
	value: float,
	property_name: StringName
) -> void:
	if syncing:
		return

	if ball == null:
		return

	ball.set(
		property_name,
		value
	)

	ball.apply_balance_values()

	# 공 크기가 바뀌면 충돌체가 벽과
	# 겹칠 수 있으므로 공을 초기화한다.
	if property_name == &"radius_px":
		ball.reset_ball(
			"radius_changed"
		)

	_sync_editors()


func _sync_editors() -> void:
	if ball == null:
		return

	syncing = true

	for property_name in editors.keys():
		var editor := (
			editors[property_name]
			as SpinBox
		)

		editor.value = float(
			ball.get(property_name)
		)

	syncing = false


func _add_action_buttons(
	content: VBoxContainer
) -> void:
	content.add_child(
		HSeparator.new()
	)

	var buttons := HBoxContainer.new()

	content.add_child(buttons)

	var reset_button := Button.new()

	reset_button.text = "공 리셋"

	reset_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	reset_button.pressed.connect(
		func() -> void:
			ball.reset_ball(
				"balance_panel"
			)
	)

	buttons.add_child(reset_button)

	var default_button := Button.new()

	default_button.text = "기본값 복구"

	default_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	default_button.pressed.connect(
		_restore_defaults
	)

	buttons.add_child(default_button)


func _restore_defaults() -> void:
	ball.radius_px = 22.0

	ball.min_speed = 300.0
	ball.launch_speed = 850.0
	ball.max_speed = 1450.0

	ball.bounce = 0.85
	ball.friction = 0.02

	ball.low_speed_grace = 0.25

	ball.aim_turn_speed_deg = 100.0
	ball.aim_curve_strength = 0.28

	ball.apply_balance_values()
	ball.reset_ball("default_values")

	_sync_editors()


func _add_telemetry(
	content: VBoxContainer
) -> void:
	content.add_child(
		HSeparator.new()
	)

	var title := Label.new()

	title.text = "실시간 측정값"

	title.add_theme_font_size_override(
		"font_size",
		18
	)

	content.add_child(title)

	telemetry_label = Label.new()

	telemetry_label.text = (
		"측정 준비 중"
	)

	content.add_child(
		telemetry_label
	)
