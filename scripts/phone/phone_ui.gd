extends CanvasLayer

# Jacob's phone. Drawn as a handset in the middle of the screen — rounded body,
# dynamic island, status bar, home bar — with a home screen of apps and a
# working Messages app over GameState's threads.
#
# The body is a plain Control, deliberately. The first cut used a
# PanelContainer, which sizes every child to fill it: the dynamic island got
# stretched to the full 392x812 and painted the whole phone black.

const BODY := Vector2(392.0, 812.0)
const RADIUS := 54
const INK := Color("f2f2f7")
const DIM := Color("8e8e93")
const BLUE := Color("0a84ff")
const GREY := Color("2c2c2e")
const BG := Color("101014")

const APPS := [
	["Messages", "messages", Color("30d158")],
	["Clock", "clock", Color("1c1c1e")],
	["Salesforce", "crm", Color("0176d3")],
	["Wallet", "wallet", Color("2c2c2e")],
	["Maps", "maps", Color("34c759")],
	["Weather", "weather", Color("3a86ff")],
	["Camera", "camera", Color("48484a")],
	["Settings", "settings", Color("636366")],
]

var _screen: String = "home"
var _thread: String = ""
var _root: Control
var _page: VBoxContainer
var _status: Label
var _title: Label
var _back: Button


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.ensure_threads()
	_build()
	_show("home")


func _process(_delta: float) -> void:
	if _status:
		_status.text = "  %s" % GameState.time_string()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("phone"):
		get_viewport().set_input_as_handled()
		_on_back()


func _close() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


# ---------------------------------------------------------------- chrome

func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.8)
	add_child(dim)

	# Plain Control: children are placed by their own anchors, so nothing gets
	# stretched over anything else.
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.offset_left = -BODY.x * 0.5
	_root.offset_right = BODY.x * 0.5
	_root.offset_top = -BODY.y * 0.5
	_root.offset_bottom = BODY.y * 0.5
	add_child(_root)

	var shell := Panel.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(RADIUS)
	sb.border_color = Color("3a3a3c")
	sb.set_border_width_all(5)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 22
	shell.add_theme_stylebox_override("panel", sb)
	_root.add_child(shell)

	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_status.offset_left = 24
	_status.offset_top = 16
	_status.offset_right = 160
	_status.offset_bottom = 36
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", INK)
	_root.add_child(_status)

	var bars := Label.new()
	bars.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bars.offset_left = -108
	bars.offset_top = 16
	bars.offset_right = -22
	bars.offset_bottom = 36
	bars.text = "▪▪▪  ⌁  ▮"
	bars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bars.add_theme_font_size_override("font_size", 13)
	bars.add_theme_color_override("font_color", INK)
	_root.add_child(bars)

	var island := Panel.new()
	island.set_anchors_preset(Control.PRESET_CENTER_TOP)
	island.offset_left = -58
	island.offset_right = 58
	island.offset_top = 12
	island.offset_bottom = 44
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color.BLACK
	isb.set_corner_radius_all(16)
	island.add_theme_stylebox_override("panel", isb)
	_root.add_child(island)

	_back = Button.new()
	_back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back.offset_left = 14
	_back.offset_top = 50
	_back.offset_right = 46
	_back.offset_bottom = 84
	_back.text = "‹"
	_back.flat = true
	_back.add_theme_color_override("font_color", BLUE)
	_back.add_theme_color_override("font_hover_color", INK)
	_back.add_theme_font_size_override("font_size", 26)
	_back.pressed.connect(_on_back)
	_root.add_child(_back)

	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_left = 48
	_title.offset_top = 54
	_title.offset_right = -20
	_title.offset_bottom = 84
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", INK)
	_root.add_child(_title)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 18
	scroll.offset_right = -18
	scroll.offset_top = 92
	scroll.offset_bottom = -46
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)

	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 8)
	scroll.add_child(_page)

	var bar := Button.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 110
	bar.offset_right = -110
	bar.offset_top = -34
	bar.offset_bottom = -12
	bar.flat = true
	bar.text = "▂▂▂▂▂▂"
	bar.add_theme_color_override("font_color", Color("6e6e73"))
	bar.add_theme_color_override("font_hover_color", INK)
	bar.pressed.connect(_on_back)
	_root.add_child(bar)


func _on_back() -> void:
	if _screen == "home":
		_close()
	elif _screen == "thread":
		_show("messages")
	else:
		_show("home")


func _show(screen: String) -> void:
	_screen = screen
	for c in _page.get_children():
		c.queue_free()
	_back.visible = screen != "home"
	match screen:
		"home":
			_title.text = ""
			_home()
		"messages":
			_title.text = "Messages"
			_messages()
		"thread":
			_title.text = _thread
			_conversation()
		"clock":
			_title.text = "Clock"
			_clock()
		"crm":
			_title.text = "Salesforce"
			_crm()
		"wallet":
			_title.text = "Wallet"
			_wallet()
		"maps":
			_title.text = "Maps"
			_maps()
		"weather":
			_title.text = "Weather"
			_weather()
		"camera":
			_title.text = "Camera"
			_stub("The lens is smudged. It is always smudged.")
		_:
			_title.text = "Settings"
			_stub("Everything is on. Nothing can be changed.")


# ---------------------------------------------------------------- screens

func _home() -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 18)
	_page.add_child(grid)
	for app in APPS:
		grid.add_child(_icon(String(app[0]), String(app[1]), Color(app[2])))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	_page.add_child(gap)

	var n := GameState.unread_texts()
	var hint := Label.new()
	hint.text = "%d unread" % n if n > 0 else "No new messages"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", DIM)
	_page.add_child(hint)


func _icon(label: String, screen: String, tint: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var b := Button.new()
	b.custom_minimum_size = Vector2(64, 64)
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.set_corner_radius_all(16)
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate() as StyleBoxFlat
	hb.bg_color = tint.lightened(0.18)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", hb)
	if screen == "messages":
		var n := GameState.unread_texts()
		b.text = str(n) if n > 0 else ""
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(_show.bind(screen))
	box.add_child(b)
	var cap := Label.new()
	cap.text = label
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", INK)
	box.add_child(cap)
	return box


func _messages() -> void:
	var names := GameState.text_contacts()
	if names.is_empty():
		_stub("Nobody has texted you. Give it time.")
		return
	for who in names:
		var thread: Array = GameState.threads.get(who, [])
		if thread.is_empty():
			continue
		var last: Dictionary = thread[thread.size() - 1]
		var unread: int = GameState.unread_in(who)
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 60)
		b.text = "%s%s\n    %s" % ["● " if unread > 0 else "   ", who, _clip(String(last.get("body", "")), 34)]
		b.add_theme_color_override("font_color", INK)
		b.add_theme_font_size_override("font_size", 14)
		var sb := StyleBoxFlat.new()
		sb.bg_color = GREY
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(10)
		b.add_theme_stylebox_override("normal", sb)
		var hb := sb.duplicate() as StyleBoxFlat
		hb.bg_color = GREY.lightened(0.1)
		b.add_theme_stylebox_override("hover", hb)
		b.pressed.connect(_open_thread.bind(who))
		_page.add_child(b)


func _open_thread(who: String) -> void:
	_thread = who
	GameState.mark_read(who)
	_show("thread")


func _conversation() -> void:
	for entry in GameState.threads.get(_thread, []):
		var mine: bool = bool(entry.get("mine", false))
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if mine:
			var pad := Control.new()
			pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(pad)
		var bubble := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = BLUE if mine else GREY
		sb.set_corner_radius_all(16)
		sb.set_content_margin_all(10)
		bubble.add_theme_stylebox_override("panel", sb)
		var text := Label.new()
		text.text = String(entry.get("body", ""))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(212, 0)
		text.add_theme_font_size_override("font_size", 14)
		text.add_theme_color_override("font_color", Color.WHITE if mine else INK)
		bubble.add_child(text)
		row.add_child(bubble)
		if not mine:
			var pad2 := Control.new()
			pad2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(pad2)
		_page.add_child(row)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	_page.add_child(gap)
	for reply in ["Yeah", "On my way", "Can't right now", "lol"]:
		var b := Button.new()
		b.text = reply
		b.custom_minimum_size = Vector2(0, 32)
		b.pressed.connect(_reply.bind(reply))
		_page.add_child(b)


func _reply(text: String) -> void:
	GameState.push_text(_thread, text, true, true)
	_show("thread")


func _clock() -> void:
	_line("Day %d" % GameState.day, 15, DIM)
	_line(GameState.time_string(), 42, INK)
	_line("Alarm 7:30 — you keep dismissing it.", 13, DIM)


func _crm() -> void:
	GameState.ensure_leads()
	var open_v: int = 0
	var won_v: int = 0
	for r in GameState.sales_leads:
		if r.status == "open" and r.converted:
			open_v += int(r.value)
		elif r.status == "won":
			won_v += int(r.value)
	_line("Pipeline", 13, DIM)
	_line("$%s open" % _money(open_v), 24, INK)
	_line("$%s closed won" % _money(won_v), 18, Color("30d158"))
	_line(" ", 8, DIM)
	_line("Calls %d    Emails %d" % [GameState.sales_calls, GameState.sales_emails], 15, INK)
	_line("Deals %d of %d" % [GameState.sales_deals, GameState.SALES_QUOTA], 15, INK)
	_line(" ", 8, DIM)
	_line("Read only. Log activity from your desk.", 12, DIM)


func _wallet() -> void:
	_line("Balance", 13, DIM)
	_line("$%s" % _money(GameState.money), 34, INK)
	_line(" ", 8, DIM)
	_line("Fuel %d%%" % int(round(GameState.fuel)), 15, INK)
	_line("Camry %d%%" % int(round(GameState.car_health)), 15, INK)
	_line("Sodas %d    Candy %d" % [GameState.sodas, GameState.candy], 15, DIM)


func _maps() -> void:
	for row in [
		"10000 Avalon — Kahua, 6th floor",
		"Chastain Place — home",
		"5955 Haterleigh Dr",
		"Whole Foods — across the avenue",
		"QT — north of the office",
		"Avalon Tennis Centre",
		"Super Strikers",
	]:
		_line(row, 14, INK)
	_line(" ", 8, DIM)
	_line("Rerouting. Rerouting. Rerouting.", 12, DIM)


func _weather() -> void:
	var night: bool = GameState.is_night()
	_line("Alpharetta", 13, DIM)
	_line("58°" if night else "72°", 42, INK)
	_line("Clear and dark" if night else "Clear", 16, DIM)
	_line(" ", 8, DIM)
	_line("Sunrise 6:00      Sunset 19:30", 13, DIM)


func _stub(text: String) -> void:
	_line(text, 15, DIM)


func _line(text: String, size: int, tint: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", tint)
	_page.add_child(l)


func _clip(text: String, n: int) -> String:
	return text if text.length() <= n else text.substr(0, n - 1) + "…"


func _money(v: int) -> String:
	var s := str(v)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
