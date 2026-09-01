extends CanvasLayer

const GOLD := Color("ffb703")

var _tower: Node3D
var _from: int = 0


func setup(tower: Node3D, from_index: int) -> void:
	_tower = tower
	_from = from_index
	_build()


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


func _ride(to: int) -> void:
	# Left untyped on purpose: `velocity` is a CharacterBody3D property and a
	# Node3D-typed local would fail the parser's property check.
	var player = get_tree().get_first_node_in_group("player")
	if player and _tower and _tower.has_method("landing"):
		player.global_position = _tower.landing(to)
		player.velocity = Vector3.ZERO
		# Teleport, not motion — don't interpolate or lerp the camera across it.
		player.reset_physics_interpolation()
		var rig = get_tree().get_first_node_in_group("camera_rig")
		if rig and rig.has_method("snap_to_target"):
			rig.snap_to_target()
		GameState.notice.emit("%s." % _tower.floor_name(to))
	_close()


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.82)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -170
	panel.offset_right = 170
	panel.offset_top = -150
	panel.offset_bottom = 160
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("161b22")
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "ELEVATOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)

	var here := Label.new()
	here.text = "Currently: %s" % _tower.floor_name(_from)
	here.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	here.add_theme_color_override("font_color", Color("9aa4b2"))
	box.add_child(here)

	for i in _tower.floor_count():
		var b := Button.new()
		b.text = _tower.floor_name(i)
		b.custom_minimum_size = Vector2(0, 46)
		b.disabled = i == _from
		b.pressed.connect(_ride.bind(i))
		box.add_child(b)

	var cancel := Button.new()
	cancel.text = "CLOSE  (Esc)"
	cancel.custom_minimum_size = Vector2(0, 36)
	cancel.pressed.connect(_close)
	box.add_child(cancel)
