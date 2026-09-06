extends Node

# Delivers texts as the day runs. Each entry fires the first time the clock
# passes its hour on a given day, so a message arrives once rather than every
# frame you happen to be at that time.
#
# Threads live on GameState so they survive walking in and out of buildings.

const TEXTS := [
	# hour, contact, body
	[7.4, "Jack", "did you take the good pan"],
	[7.5, "Jack", "the one with the handle"],
	[8.1, "Ralph", "Morning. Pipeline review at nine. Come correct."],
	[8.3, "Myriam", "Badge in slowly today. I want to enjoy it."],
	[9.2, "Tyler", "Howdy partner. Circling back on that thing we never discussed."],
	[9.6, "Ralph", "They call me the SDR Godfather for a reason. Dial."],
	[10.4, "Fiona", "if ralph says godfather one more time im walking into the sea"],
	[11.2, "Ayden", "coffee run. you want anything. saying no is also an answer"],
	[12.0, "Tyler", "Lunch is a state of mind. Also I'm at the break table."],
	[12.6, "Jack", "there is a smell in the flat. not me. probably"],
	[13.5, "Ralph", "Let's double-click on Brightline. My office. I don't have an office."],
	[14.8, "Myriam", "Someone asked if you were single. It was me. I asked."],
	[15.9, "Collin", "your pipeline has a lead from 2019 in it. just so you know"],
	[16.7, "Fiona", "kirby beat wei at foosball 5-0. wei has gone quiet"],
	[17.8, "Ralph", "Numbers by close. The Godfather does not chase."],
	[18.4, "Jack", "im making a thing for dinner. do not ask what"],
	[19.5, "Myriam", "Off the clock. Just so you know where I am."],
	[20.6, "Jack", "the thing did not work out. we are getting food"],
	[21.8, "Unknown", "Your car's extended warranty is expiring. Reply STOP."],
	[22.9, "Tyler", "Sleep is just a hard reset on the human OS. Night, partner."],
]

var _fired: Dictionary = {}      # "day:index" -> true


func _ready() -> void:
	add_to_group("phone_service")
	GameState.ensure_threads()
	# Anything already due today is treated as read history, so opening the
	# phone mid-morning does not dump the whole day at you as unread.
	for i in TEXTS.size():
		if float(TEXTS[i][0]) <= GameState.clock:
			_deliver(i, true)


func _process(_delta: float) -> void:
	if GameState.is_paused:
		return
	for i in TEXTS.size():
		var at: float = float(TEXTS[i][0])
		if GameState.clock >= at and not _fired.has(_key(i)):
			_deliver(i, false)


func _key(i: int) -> String:
	return "%d:%d" % [GameState.day, i]


func _deliver(i: int, silent: bool) -> void:
	_fired[_key(i)] = true
	var who := String(TEXTS[i][1])
	var body := String(TEXTS[i][2])
	GameState.push_text(who, body, silent)
	if not silent:
		GameState.notice.emit("%s: %s" % [who, body])
