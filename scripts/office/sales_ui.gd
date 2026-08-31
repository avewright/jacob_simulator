extends CanvasLayer

# Cold-call sim. A lead moves OPENING -> DISCOVERY -> PITCH -> CLOSE; each call
# offers three replies and only one is right for the stage the lead is actually
# in. Emails nudge interest but never advance the stage, and they sour after a
# few. Closing rolls against interest, so pushing early genuinely loses leads.

const GOLD := Color("ffb703")
const BG := Color("0d1117")
const PANEL := Color("161b22")

const STAGES := ["OPENING", "DISCOVERY", "PITCH", "CLOSE"]

# Per stage: [text, quality] where quality is "good", "ok" or "bad".
const SCRIPTS := [
	[
		["\"Hi, it's Jacob at North Point — did I catch you at an okay time?\"", "good"],
		["\"Hi, I'll be quick, I know you're busy.\"", "ok"],
		["\"Hi! Do you want to hear about our platform?\"", "bad"],
	],
	[
		["\"How is your team handling renewals right now?\"", "good"],
		["\"Are you the person who handles this?\"", "ok"],
		["\"We're cheaper than what you've got.\"", "bad"],
	],
	[
		["\"Given the renewal mess — that's exactly the gap we close.\"", "good"],
		["\"Here's what the product does, broadly.\"", "ok"],
		["\"Everyone in your industry is buying this.\"", "bad"],
	],
	[
		["\"Want me to send paperwork so you can start Monday?\"", "good"],
		["\"Should we set up another call?\"", "ok"],
		["\"So can I put you down for a yes or not?\"", "bad"],
	],
]

var _list: VBoxContainer
var _detail: VBoxContainer
var _log: RichTextLabel
var _stats: Label
var _selected: int = -1


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.ensure_leads()
	GameState.is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	_refresh()
	_say("Logged in. %d leads in the queue." % GameState.sales_leads.size())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


# ---------------------------------------------------------------- actions

func _lead() -> Dictionary:
	if _selected < 0 or _selected >= GameState.sales_leads.size():
		return {}
	return GameState.sales_leads[_selected]


func _on_call() -> void:
	var lead := _lead()
	if lead.is_empty() or lead.status != "open":
		return
	GameState.sales_calls += 1
	_show_call(lead)


func _on_reply(lead: Dictionary, quality: String) -> void:
	match quality:
		"good":
			lead.interest = mini(100, lead.interest + 18)
			lead.stage = mini(3, lead.stage + 1)
			_say("[color=#7ddf90]Good read.[/color] %s warms up (+18) and moves to %s." % [lead.contact, STAGES[lead.stage]])
		"ok":
			lead.interest = mini(100, lead.interest + 6)
			_say("%s is polite about it (+6). Still %s." % [lead.contact, STAGES[lead.stage]])
		_:
			lead.interest = maxi(0, lead.interest - 16)
			_say("[color=#ff8a80]That landed badly.[/color] %s cools off (-16)." % lead.contact)
			if lead.interest <= 0:
				lead.status = "lost"
				_say("[color=#ff8a80]%s at %s hung up for good.[/color]" % [lead.contact, lead.company])
	_refresh()


func _on_email() -> void:
	var lead := _lead()
	if lead.is_empty() or lead.status != "open":
		return
	GameState.sales_emails += 1
	lead.emails += 1
	if lead.emails > 3:
		lead.interest = maxi(0, lead.interest - 8)
		_say("[color=#ff8a80]Email %d to %s.[/color] You're in spam territory now (-8)." % [lead.emails, lead.contact])
	else:
		var gain: int = maxi(3, 12 - (lead.emails - 1) * 4)
		lead.interest = mini(100, lead.interest + gain)
		_say("Sent follow-up %d to %s (+%d)." % [lead.emails, lead.contact, gain])
	_refresh()


func _on_close() -> void:
	var lead := _lead()
	if lead.is_empty() or lead.status != "open":
		return
	if lead.stage < 3:
		_say("[color=#ff8a80]Too early.[/color] Work %s up to CLOSE first." % lead.contact)
		return
	if randi() % 100 < lead.interest:
		lead.status = "won"
		var commission: int = int(lead.value * 0.1)
		GameState.add_money(commission)
		GameState.sales_deals += 1
		_say("[color=#7ddf90]CLOSED — %s, $%d.[/color] Commission $%d." % [lead.company, lead.value, commission])
		if GameState.sales_deals == GameState.SALES_QUOTA:
			GameState.add_money(500)
			GameState.mark_mission("sales_quota")
			GameState.objective = "Quota hit. Dana owes you a coffee."
			_say("[color=#ffb703]QUOTA HIT. $500 bonus.[/color]")
	else:
		lead.status = "lost"
		_say("[color=#ff8a80]They passed.[/color] %s is dead at %d%% interest." % [lead.company, lead.interest])
	_selected = -1
	_refresh()


# ---------------------------------------------------------------- ui

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 28
	root.offset_right = -28
	root.offset_top = 20
	root.offset_bottom = -20
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var title := Label.new()
	title.text = "NORTH POINT  ·  SALES CONSOLE"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", GOLD)
	head.add_child(title)
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(pad)
	_stats = Label.new()
	_stats.add_theme_color_override("font_color", Color("9aa4b2"))
	head.add_child(_stats)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	var left := _panel(body, 340)
	var lead_head := Label.new()
	lead_head.text = "PIPELINE"
	lead_head.add_theme_color_override("font_color", GOLD)
	left.add_child(lead_head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	_detail = _panel(body, 0)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bottom := _panel(root, 0)
	bottom.custom_minimum_size = Vector2(0, 150)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_color_override("default_color", Color("c9d1d9"))
	bottom.add_child(_log)

	var quit := Button.new()
	quit.text = "LEAVE DESK  (Esc)"
	quit.custom_minimum_size = Vector2(0, 38)
	quit.pressed.connect(_close)
	root.add_child(quit)


func _panel(parent: Control, min_w: float) -> VBoxContainer:
	var wrap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	wrap.add_theme_stylebox_override("panel", sb)
	if min_w > 0.0:
		wrap.custom_minimum_size = Vector2(min_w, 0)
	parent.add_child(wrap)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	wrap.add_child(box)
	return box


func _refresh() -> void:
	_stats.text = "Calls %d    Emails %d    Closed %d / %d    Cash $%d" % [
		GameState.sales_calls, GameState.sales_emails,
		GameState.sales_deals, GameState.SALES_QUOTA, GameState.money,
	]
	for c in _list.get_children():
		c.queue_free()
	for i in GameState.sales_leads.size():
		var lead: Dictionary = GameState.sales_leads[i]
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 46)
		var mark := ""
		if lead.status == "won":
			mark = "  ✓"
		elif lead.status == "lost":
			mark = "  ✗"
		b.text = "%s\n%s · %d%%%s" % [lead.company, lead.contact, lead.interest, mark]
		b.disabled = lead.status != "open"
		b.pressed.connect(_select.bind(i))
		_list.add_child(b)
	_show_detail()


func _select(i: int) -> void:
	_selected = i
	_show_detail()


func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var lead := _lead()
	if lead.is_empty():
		var hint := Label.new()
		hint.text = "Pick a lead from the pipeline.\n\nCall to move them through the stages.\nEmail to warm them between calls.\nClose only once they reach CLOSE."
		hint.add_theme_color_override("font_color", Color("8b949e"))
		_detail.add_child(hint)
		return

	var name_lab := Label.new()
	name_lab.text = "%s — %s" % [lead.contact, lead.company]
	name_lab.add_theme_font_size_override("font_size", 20)
	name_lab.add_theme_color_override("font_color", GOLD)
	_detail.add_child(name_lab)

	var meta := Label.new()
	meta.text = "Stage %s    Contract $%d    Emails sent %d" % [STAGES[lead.stage], lead.value, lead.emails]
	meta.add_theme_color_override("font_color", Color("9aa4b2"))
	_detail.add_child(meta)

	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = lead.interest
	bar.custom_minimum_size = Vector2(0, 22)
	_detail.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_detail.add_child(row)
	row.add_child(_action("CALL", _on_call))
	row.add_child(_action("EMAIL", _on_email))
	var close_btn := _action("CLOSE DEAL", _on_close)
	close_btn.disabled = lead.stage < 3
	row.add_child(close_btn)


func _show_call(lead: Dictionary) -> void:
	for c in _detail.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = "CALLING %s — %s" % [lead.contact, STAGES[lead.stage]]
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", GOLD)
	_detail.add_child(head)

	var prompt := Label.new()
	prompt.text = "\"%s\"" % _greeting(lead)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_color_override("font_color", Color("c9d1d9"))
	_detail.add_child(prompt)

	var options: Array = SCRIPTS[lead.stage].duplicate()
	options.shuffle()
	for opt in options:
		var b := Button.new()
		b.text = opt[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(_on_reply.bind(lead, opt[1]))
		_detail.add_child(b)


func _greeting(lead: Dictionary) -> String:
	match lead.stage:
		0: return "%s speaking." % lead.contact
		1: return "Alright, you've got a minute. What's this about?"
		2: return "Okay — so what is it you actually sell?"
		_: return "Look, I'm interested. What happens next?"


func _action(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 40)
	b.pressed.connect(cb)
	return b


func _say(text: String) -> void:
	_log.append_text(text + "\n")
