extends CanvasLayer

const GOLD := Color("ffb703")

var _money: Label
var _fuel: Label
var _health: Label
var _clock: Label
var _texts: Label
var _state: Label
var _speed: Label
var _objective: Label
var _notice: Label
var _prompt: Label
var _minimap: Control
var _nav_box: Control
var _nav_arrow: Control
var _nav_name: Label
var _nav_dist: Label
var _nav_bearing: float = 0.0
var _pause_root: Control
var _notice_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GameState.money_changed.connect(func(v: int) -> void: _money.text = "$%d" % v)
	GameState.fuel_changed.connect(func(v: float) -> void: _fuel.text = "%d%%" % int(round(v)))
	GameState.car_health_changed.connect(_on_car_health)
	GameState.objective_changed.connect(func(t: String) -> void: _objective.text = t)
	GameState.notice.connect(_flash)
	GameState.paused_changed.connect(_on_paused)
	GameState.prompt_changed.connect(func(t: String) -> void: _prompt.text = t)
	_money.text = "$%d" % GameState.money
	_fuel.text = "%d%%" % int(round(GameState.fuel))
	_objective.text = GameState.objective
	_on_car_health(GameState.car_health)


func _process(delta: float) -> void:
	if _notice_time > 0.0:
		_notice_time -= delta
		if _notice_time <= 0.0:
			_notice.visible = false
	if GameState.is_paused:
		return
	if GameState.in_car:
		_state.text = "IN CAMRY"
	elif GameState.has_clothes:
		_state.text = "ON FOOT"
	else:
		_state.text = "IN UNDERWEAR"
	_speed.text = ("%d mph" % int(round(GameState.speed_mph))) if GameState.in_car else ""
	_clock.text = "Day %d  %s" % [GameState.day, GameState.time_string()]
	var unread := GameState.unread_texts()
	_texts.text = "✉ %d" % unread if unread > 0 else ""
	_nav_tick()
	_minimap.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameState.is_paused:
			_resume()
		else:
			GameState.set_paused(true)


func _on_car_health(v: float) -> void:
	_health.text = "CAR %d%%" % int(round(v))
	if v <= 0.0:
		_health.add_theme_color_override("font_color", Color("ff3b30"))
	elif v <= 25.0:
		_health.add_theme_color_override("font_color", Color("ff7a1a"))
	elif v <= 60.0:
		_health.add_theme_color_override("font_color", Color("ffd166"))
	else:
		_health.add_theme_color_override("font_color", GOLD)


func _flash(text: String) -> void:
	_notice.text = text
	_notice.visible = true
	_notice_time = 3.2


func _on_paused(value: bool) -> void:
	_pause_root.visible = value


func _resume() -> void:
	GameState.set_paused(false)


func _save_quit() -> void:
	GameState.save_game()
	GameState.set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")


func _build() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 12
	top.offset_bottom = 48
	top.add_theme_constant_override("separation", 10)
	add_child(top)

	_money = _pill(top, "$420")
	_fuel = _pill(top, "78%")
	_health = _pill(top, "100%")
	_clock = _pill(top, "8:00 AM")
	_texts = _pill(top, "")
	_state = _pill(top, "ON FOOT")
	_speed = _pill(top, "")

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	_objective = Label.new()
	_objective.add_theme_color_override("font_color", GOLD)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_objective)

	_notice = Label.new()
	_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice.offset_left = -320
	_notice.offset_right = 320
	_notice.offset_top = 56
	_notice.offset_bottom = 88
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_color", Color.WHITE)
	_notice.visible = false
	add_child(_notice)

	var help := Label.new()
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 14
	help.offset_top = -92
	help.offset_right = 420
	help.offset_bottom = -14
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -220
	_prompt.offset_right = 220
	_prompt.offset_top = -120
	_prompt.offset_bottom = -80
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", GOLD)
	add_child(_prompt)

	help.text = "WASD move / drive   Mouse steers\nShift sprint  Space jump / handbrake  Q wave  P phone\nE Camry / clothes / arcade   R new Camry   Esc pause"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.85))
	add_child(help)

	_nav_box = Control.new()
	_nav_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_nav_box.offset_left = -176
	_nav_box.offset_right = -16
	_nav_box.offset_top = 222
	_nav_box.offset_bottom = 268
	_nav_box.visible = false
	add_child(_nav_box)

	var navbg := Panel.new()
	navbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var nsb := StyleBoxFlat.new()
	nsb.bg_color = Color(0, 0, 0, 0.72)
	nsb.set_corner_radius_all(12)
	navbg.add_theme_stylebox_override("panel", nsb)
	_nav_box.add_child(navbg)

	_nav_arrow = Control.new()
	_nav_arrow.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_nav_arrow.offset_left = 8
	_nav_arrow.offset_top = 7
	_nav_arrow.offset_right = 40
	_nav_arrow.offset_bottom = 39
	_nav_arrow.draw.connect(_draw_arrow)
	_nav_box.add_child(_nav_arrow)

	_nav_name = Label.new()
	_nav_name.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_nav_name.offset_left = 46
	_nav_name.offset_top = 4
	_nav_name.offset_right = 156
	_nav_name.offset_bottom = 24
	_nav_name.add_theme_font_size_override("font_size", 13)
	_nav_name.add_theme_color_override("font_color", Color.WHITE)
	_nav_box.add_child(_nav_name)

	_nav_dist = Label.new()
	_nav_dist.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_nav_dist.offset_left = 46
	_nav_dist.offset_top = 23
	_nav_dist.offset_right = 156
	_nav_dist.offset_bottom = 43
	_nav_dist.add_theme_font_size_override("font_size", 12)
	_nav_dist.add_theme_color_override("font_color", GOLD)
	_nav_box.add_child(_nav_dist)

	_minimap = Control.new()
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -176
	_minimap.offset_top = 56
	_minimap.offset_right = -16
	_minimap.offset_bottom = 216
	_minimap.draw.connect(_draw_minimap)
	add_child(_minimap)

	_pause_root = ColorRect.new()
	_pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_root.color = Color(0.02, 0.02, 0.05, 0.72)
	_pause_root.visible = false
	_pause_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_root)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -140
	box.offset_right = 140
	box.offset_top = -90
	box.offset_bottom = 90
	box.add_theme_constant_override("separation", 12)
	_pause_root.add_child(box)

	var pause_title := Label.new()
	pause_title.text = "PAUSED"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 28)
	pause_title.add_theme_color_override("font_color", GOLD)
	box.add_child(pause_title)

	box.add_child(_pbtn("RESUME", _resume))
	box.add_child(_pbtn("SAVE + TITLE", _save_quit))


func _pill(parent: Control, text: String) -> Label:
	var wrap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.72)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	wrap.add_theme_stylebox_override("panel", sb)
	var lab := Label.new()
	lab.text = text
	lab.add_theme_color_override("font_color", GOLD)
	wrap.add_child(lab)
	parent.add_child(wrap)
	return lab


func _pbtn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	return b


## Live navigation readout: how far, which way to turn, and whether you have
## arrived. The bearing is taken against the camera, not the player, because
## the camera is the direction you are actually looking.
func _nav_tick() -> void:
	var place := GameState.nav_place()
	if place.is_empty():
		_nav_box.visible = false
		return
	if get_tree().get_first_node_in_group("player") == null:
		_nav_box.visible = false
		return
	var here := GameState.here()
	var target: Vector3 = place["at"]
	if Places.flat(here).distance_to(Places.flat(target)) < float(place["radius"]):
		GameState.clear_nav()
		GameState.notice.emit("Arrived at %s." % String(place["name"]))
		_nav_box.visible = false
		return

	var pts := Places.route(here, target)
	var leg := Places.next_waypoint(pts, here)
	var cam := get_viewport().get_camera_3d()
	var fwd := Vector2(0, -1)
	if cam:
		var f := -cam.global_transform.basis.z
		if Vector2(f.x, f.z).length() > 0.01:
			fwd = Vector2(f.x, f.z).normalized()
	var want := (leg - Places.flat(here))
	_nav_bearing = fwd.angle_to(want.normalized()) if want.length() > 0.01 else 0.0

	_nav_box.visible = true
	_nav_name.text = String(place["name"])
	_nav_dist.text = "%s  ·  %s" % [Places.distance_text(Places.route_length(pts)), _turn_text(_nav_bearing)]
	_nav_arrow.queue_redraw()


func _turn_text(rel: float) -> String:
	var d := rad_to_deg(rel)
	if absf(d) < 20.0:
		return "straight on"
	if absf(d) > 140.0:
		return "turn around"
	if absf(d) < 65.0:
		return "bear right" if d > 0.0 else "bear left"
	return "right" if d > 0.0 else "left"


func _draw_arrow() -> void:
	var c := _nav_arrow.size * 0.5
	_nav_arrow.draw_circle(c, 15.0, Color(1, 1, 1, 0.10))
	# Control space has +Y down, so a positive angle turns clockwise, which is
	# the same way a right turn reads on screen.
	_nav_arrow.draw_set_transform(c, _nav_bearing, Vector2.ONE)
	_nav_arrow.draw_colored_polygon(
		PackedVector2Array([Vector2(0, -12), Vector2(8, 9), Vector2(0, 4), Vector2(-8, 9)]), GOLD)
	_nav_arrow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_minimap() -> void:
	var s := 160.0 / 780.0
	_minimap.draw_rect(Rect2(0, 0, 160, 160), Color("1e3a1e"))
	_minimap.draw_rect(Rect2((0 + 390) * s - 14 * s, 0, 28 * s, 160), Color("2a2e36"))
	for z in [-48.0, 48.0, 160.0]:
		_minimap.draw_rect(Rect2(0, (z + 390) * s - 7 * s, 160, 14 * s), Color("2a2e36"))
	for x in [-140.0, 90.0]:
		_minimap.draw_rect(Rect2((x + 390) * s - 7 * s, 0, 14 * s, 160), Color("2a2e36"))

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var car := get_tree().get_first_node_in_group("camry") as Node3D

	var place := GameState.nav_place()
	if not place.is_empty():
		var pts := Places.route(GameState.here(), place["at"])
		for i in range(1, pts.size()):
			_minimap.draw_line(Vector2((pts[i - 1].x + 390) * s, (pts[i - 1].y + 390) * s),
				Vector2((pts[i].x + 390) * s, (pts[i].y + 390) * s), Color("0a84ff"), 2.0)
		var pin: Vector3 = place["at"]
		var at := Vector2((pin.x + 390) * s, (pin.z + 390) * s)
		_minimap.draw_circle(at, 5, Color(place["tint"]))
		_minimap.draw_arc(at, 8.0, 0.0, TAU, 18, Color.WHITE, 1.5)

	for m in get_tree().get_nodes_in_group("mission_marker"):
		if m is Node3D:
			var p: Vector3 = m.global_position
			_minimap.draw_circle(Vector2((p.x + 390) * s, (p.z + 390) * s), 4, Color("ffb703"))
	if car:
		_minimap.draw_circle(Vector2((car.global_position.x + 390) * s, (car.global_position.z + 390) * s), 4, Color("c1121f"))
	if player and not GameState.in_car:
		_minimap.draw_circle(Vector2((player.global_position.x + 390) * s, (player.global_position.z + 390) * s), 3, Color("0d4aa6"))
