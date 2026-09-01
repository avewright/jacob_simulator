extends CanvasLayer

# Northwind CRM — a Salesforce-shaped console.
#
# A record starts as a Lead. Working it converts it to an Opportunity, which
# then walks the standard stage ladder (Prospecting -> Qualification -> Needs
# Analysis -> Proposal -> Negotiation -> Closed Won/Lost). Probability is
# driven by how well you work it, not by the stage alone, and every call and
# email is written to the activity timeline the way a real CRM would.

const NAVY := Color("032d60")
const BLUE := Color("0176d3")
const GOLD := Color("ffb703")
const BG := Color("f3f3f3")
const CARD := Color("ffffff")
const INK := Color("181818")
const MUTED := Color("5c5c5c")

const STAGES := [
	"Prospecting", "Qualification", "Needs Analysis",
	"Proposal/Price Quote", "Negotiation/Review",
]
# Per stage: [what you say, quality] — only one reply fits the stage you're in.
const SCRIPTS := [
	[
		["\"Hi, it's Jacob at Northwind — did I catch you at an okay time?\"", "good"],
		["\"Hi, I'll be quick, I know you're busy.\"", "ok"],
		["\"Hi! Do you want to hear about our platform?\"", "bad"],
	],
	[
		["\"Are you the person who owns renewals, or is that someone else?\"", "good"],
		["\"Roughly how big is the team touching this?\"", "ok"],
		["\"What's your budget?\"", "bad"],
	],
	[
		["\"Walk me through what breaks today when a renewal slips.\"", "good"],
		["\"How are you tracking all this at the moment?\"", "ok"],
		["\"We're cheaper than what you've got.\"", "bad"],
	],
	[
		["\"Given the slipped renewals — here's the number, and here's what it fixes.\"", "good"],
		["\"I'll send over pricing and you can have a look.\"", "ok"],
		["\"Everyone in your industry is buying this.\"", "bad"],
	],
	[
		["\"If I can get legal to sign off this week, can you start Monday?\"", "good"],
		["\"Should we set up another call to talk it through?\"", "ok"],
		["\"So can I put you down for a yes or not?\"", "bad"],
	],
]

var _list: VBoxContainer
var _detail: VBoxContainer
var _feed: RichTextLabel
var _stats: Label
var _pipeline: Label
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
	_post("Logged in as jacob@northwind.com. %d records in your queue." % GameState.sales_leads.size())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


# ---------------------------------------------------------------- record ops

func _rec() -> Dictionary:
	if _selected < 0 or _selected >= GameState.sales_leads.size():
		return {}
	return GameState.sales_leads[_selected]


func _on_convert() -> void:
	var r := _rec()
	if r.is_empty() or r.converted:
		return
	r.converted = true
	GameState.sales_converted += 1
	_post("[b]Lead converted.[/b] %s at %s is now an Opportunity — %s, %s."
		% [r.contact, r.company, _money(r.value), STAGES[r.stage]])
	_refresh()


func _on_call() -> void:
	var r := _rec()
	if r.is_empty() or r.status != "open":
		return
	GameState.sales_calls += 1
	_show_call(r)


func _on_reply(r: Dictionary, quality: String) -> void:
	match quality:
		"good":
			r.interest = mini(100, r.interest + 18)
			var was: int = r.stage
			r.stage = mini(STAGES.size() - 1, r.stage + 1)
			_post("[color=#2e844a]Call logged — positive.[/color] %s warms up (+18)%s"
				% [r.contact, "." if was == r.stage else ", stage moved to %s." % STAGES[r.stage]])
		"ok":
			r.interest = mini(100, r.interest + 6)
			_post("Call logged — neutral. %s is polite about it (+6). Still %s." % [r.contact, STAGES[r.stage]])
		_:
			r.interest = maxi(0, r.interest - 16)
			_post("[color=#ba0517]Call logged — negative.[/color] %s cools off (-16)." % r.contact)
			if r.interest <= 0:
				r.status = "lost"
				GameState.sales_lost += 1
				_post("[color=#ba0517]Closed Lost — %s stopped taking your calls.[/color]" % r.company)
	_refresh()


func _on_email() -> void:
	var r := _rec()
	if r.is_empty() or r.status != "open":
		return
	GameState.sales_emails += 1
	r.emails += 1
	if r.emails > 3:
		r.interest = maxi(0, r.interest - 8)
		_post("[color=#ba0517]Email logged (#%d).[/color] You're in spam territory now (-8)." % r.emails)
	else:
		var gain: int = maxi(3, 12 - (r.emails - 1) * 4)
		r.interest = mini(100, r.interest + gain)
		_post("Email logged (#%d) to %s (+%d)." % [r.emails, r.contact, gain])
	_refresh()


func _on_close() -> void:
	var r := _rec()
	if r.is_empty() or r.status != "open":
		return
	if not r.converted:
		_post("[color=#ba0517]Convert the lead first.[/color] You can't close what isn't an Opportunity.")
		return
	if r.stage < STAGES.size() - 1:
		_post("[color=#ba0517]Too early.[/color] %s is only at %s." % [r.contact, STAGES[r.stage]])
		return
	if randi() % 100 < r.interest:
		r.status = "won"
		var commission: int = int(r.value * 0.1)
		GameState.add_money(commission)
		GameState.sales_deals += 1
		_post("[color=#2e844a][b]Closed Won — %s, %s.[/b][/color] Commission %s."
			% [r.company, _money(r.value), _money(commission)])
		if GameState.sales_deals == GameState.SALES_QUOTA:
			GameState.add_money(500)
			GameState.mark_mission("sales_quota")
			GameState.objective = "Quota hit. Ralph owes you a coffee."
			_post("[color=#ffb703][b]QUOTA ATTAINED. $500 accelerator paid.[/b][/color]")
	else:
		r.status = "lost"
		GameState.sales_lost += 1
		_post("[color=#ba0517]Closed Lost — %s went another way at %d%%.[/color]" % [r.company, r.interest])
	_selected = -1
	_refresh()


# ---------------------------------------------------------------- chrome

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Global header bar.
	var bar := PanelContainer.new()
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = NAVY
	bar_sb.content_margin_left = 20
	bar_sb.content_margin_right = 20
	bar_sb.content_margin_top = 10
	bar_sb.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", bar_sb)
	root.add_child(bar)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 16)
	bar.add_child(bar_row)

	var cloud := Label.new()
	cloud.text = "☁  Northwind CRM"
	cloud.add_theme_font_size_override("font_size", 20)
	cloud.add_theme_color_override("font_color", Color.WHITE)
	bar_row.add_child(cloud)

	var tab := Label.new()
	tab.text = "Sales  ›  Leads & Opportunities"
	tab.add_theme_color_override("font_color", Color("9fc6ea"))
	bar_row.add_child(tab)

	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(pad)

	_stats = Label.new()
	_stats.add_theme_color_override("font_color", Color("cde3f6"))
	bar_row.add_child(_stats)

	var inner := MarginContainer.new()
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("margin_left", 18)
	inner.add_theme_constant_override("margin_right", 18)
	inner.add_theme_constant_override("margin_top", 14)
	inner.add_theme_constant_override("margin_bottom", 14)
	root.add_child(inner)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	inner.add_child(col)

	_pipeline = Label.new()
	_pipeline.add_theme_font_size_override("font_size", 15)
	_pipeline.add_theme_color_override("font_color", NAVY)
	col.add_child(_pipeline)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	col.add_child(body)

	var left := _card(body, 360)
	left.add_child(_heading("MY PIPELINE"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	_detail = _card(body, 0)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bottom := _card(col, 0)
	bottom.custom_minimum_size = Vector2(0, 150)
	bottom.add_child(_heading("ACTIVITY TIMELINE"))
	_feed = RichTextLabel.new()
	_feed.bbcode_enabled = true
	_feed.scroll_following = true
	_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feed.add_theme_color_override("default_color", INK)
	bottom.add_child(_feed)

	var quit := Button.new()
	quit.text = "LOG OUT — back to the floor  (Esc)"
	quit.custom_minimum_size = Vector2(0, 38)
	quit.pressed.connect(_close)
	col.add_child(quit)


func _card(parent: Control, min_w: float) -> VBoxContainer:
	var wrap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	sb.border_color = Color("dddbda")
	sb.set_border_width_all(1)
	wrap.add_theme_stylebox_override("panel", sb)
	if min_w > 0.0:
		wrap.custom_minimum_size = Vector2(min_w, 0)
	parent.add_child(wrap)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	wrap.add_child(box)
	return box


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", MUTED)
	return l


func _money(v: int) -> String:
	var s := str(v)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return "$" + out


func _refresh() -> void:
	var open_value := 0
	var won_value := 0
	for r in GameState.sales_leads:
		if r.status == "open" and r.converted:
			open_value += int(r.value)
		elif r.status == "won":
			won_value += int(r.value)
	_stats.text = "Calls %d   Emails %d   Converted %d   Won %d / %d" % [
		GameState.sales_calls, GameState.sales_emails,
		GameState.sales_converted, GameState.sales_deals, GameState.SALES_QUOTA,
	]
	_pipeline.text = "Open pipeline %s     Closed won %s     Commission earned %s" % [
		_money(open_value), _money(won_value), _money(GameState.money),
	]

	for c in _list.get_children():
		c.queue_free()
	for i in GameState.sales_leads.size():
		var r: Dictionary = GameState.sales_leads[i]
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 56)
		var kind := "Opportunity" if r.converted else "Lead"
		var tail := "%s · %d%%" % [STAGES[r.stage], r.interest]
		if r.status == "won":
			tail = "Closed Won ✓"
		elif r.status == "lost":
			tail = "Closed Lost ✗"
		b.text = "%s — %s\n%s · %s · %s" % [r.company, r.contact, kind, _money(r.value), tail]
		b.disabled = r.status != "open"
		b.pressed.connect(_select.bind(i))
		_list.add_child(b)
	_show_detail()


func _select(i: int) -> void:
	_selected = i
	_show_detail()


func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var r := _rec()
	if r.is_empty():
		_detail.add_child(_heading("RECORD"))
		var hint := Label.new()
		hint.text = "Pick a record from the pipeline.\n\nConvert a Lead to open it as an Opportunity.\nLog a Call to move it up the stage ladder.\nLog an Email to warm it between calls.\nClose it once it reaches Negotiation/Review."
		hint.add_theme_color_override("font_color", MUTED)
		_detail.add_child(hint)
		return

	_detail.add_child(_heading("OPPORTUNITY" if r.converted else "LEAD"))

	var title := Label.new()
	title.text = "%s — %s" % [r.company, r.contact]
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", NAVY)
	_detail.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 5)
	_detail.add_child(grid)
	for pair in [
		["Stage", STAGES[r.stage]],
		["Amount", _money(r.value)],
		["Probability", "%d%%" % r.interest],
		["Close Date", r.close_date],
		["Lead Source", r.source],
		["Emails Sent", str(r.emails)],
	]:
		var k := Label.new()
		k.text = pair[0]
		k.add_theme_font_size_override("font_size", 12)
		k.add_theme_color_override("font_color", MUTED)
		grid.add_child(k)
		var v := Label.new()
		v.text = pair[1]
		v.add_theme_color_override("font_color", INK)
		grid.add_child(v)

	# Stage path, the way the Lightning bar reads.
	var path := HBoxContainer.new()
	path.add_theme_constant_override("separation", 4)
	_detail.add_child(path)
	for i in STAGES.size():
		var chip := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = BLUE if i <= r.stage else Color("e5e5e5")
		csb.set_corner_radius_all(4)
		csb.set_content_margin_all(5)
		chip.add_theme_stylebox_override("panel", csb)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cl := Label.new()
		cl.text = STAGES[i].split("/")[0]
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.add_theme_font_size_override("font_size", 11)
		cl.add_theme_color_override("font_color", Color.WHITE if i <= r.stage else MUTED)
		chip.add_child(cl)
		path.add_child(chip)

	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = r.interest
	bar.custom_minimum_size = Vector2(0, 20)
	_detail.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_detail.add_child(row)
	if not r.converted:
		row.add_child(_action("CONVERT LEAD", _on_convert))
	row.add_child(_action("LOG A CALL", _on_call))
	row.add_child(_action("LOG AN EMAIL", _on_email))
	var close_btn := _action("CLOSE WON?", _on_close)
	close_btn.disabled = not r.converted or r.stage < STAGES.size() - 1
	row.add_child(close_btn)


func _show_call(r: Dictionary) -> void:
	for c in _detail.get_children():
		c.queue_free()
	_detail.add_child(_heading("CALL IN PROGRESS · %s" % STAGES[r.stage].to_upper()))

	var head := Label.new()
	head.text = "%s — %s" % [r.contact, r.company]
	head.add_theme_font_size_override("font_size", 21)
	head.add_theme_color_override("font_color", NAVY)
	_detail.add_child(head)

	var prompt := Label.new()
	prompt.text = "\"%s\"" % _greeting(r)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_color_override("font_color", INK)
	_detail.add_child(prompt)

	var options: Array = SCRIPTS[r.stage].duplicate()
	options.shuffle()
	for opt in options:
		var b := Button.new()
		b.text = opt[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(_on_reply.bind(r, opt[1]))
		_detail.add_child(b)


func _greeting(r: Dictionary) -> String:
	match r.stage:
		0: return "%s speaking." % r.contact
		1: return "Alright, you've got a minute. What's this about?"
		2: return "Okay — so what is it you actually sell?"
		3: return "Right. What would this cost us?"
		_: return "Look, I'm interested. What happens next?"


func _action(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(130, 40)
	b.pressed.connect(cb)
	return b


func _post(text: String) -> void:
	_feed.append_text(text + "\n")
