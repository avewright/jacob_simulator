class_name Hinge
extends RefCounted

# Profiles for the Hinge app on Jacob's phone.
#
# ---------------------------------------------------------------------------
# TO ADD SOMEONE: append one dictionary to PROFILES.
#
#   id          unique key; what gets stored in the save
#   name, age   header line
#   job         grey line under the name
#   prompt      the Hinge prompt they picked
#   answer      what they wrote
#   tint        card colour
#   likes       true if liking them matches; false and you are left on read
#   opener      the text they send you when you match — lands in Messages
# ---------------------------------------------------------------------------

const PROFILES := [
	{
		"id": "myriam", "name": "Myriam", "age": 27, "job": "Front desk — Kahua",
		"prompt": "The way to win me over is",
		"answer": "Walk past my desk slowly. That's it. That's the whole thing.",
		"tint": Color("b5179e"), "likes": true,
		"opener": "I badge you in every morning and THIS is how I find out. Hi.",
	},
	{
		"id": "lilli", "name": "Lilli", "age": 29, "job": "Owns Lilli's Bakery",
		"prompt": "I'm looking for",
		"answer": "Someone who is awake at 5am on purpose. It's a short list.",
		"tint": Color("d988a8"), "likes": true,
		"opener": "You held the door once and didn't wash your hands. I remember.",
	},
	{
		"id": "brooke", "name": "Brooke", "age": 26, "job": "Dental hygienist",
		"prompt": "My simple pleasures",
		"answer": "Avalon on a Saturday. Iced coffee. Telling people to floss.",
		"tint": Color("4cc9f0"), "likes": true,
		"opener": "Alpharetta is small. You're the guy with the beige Camry, right?",
	},
	{
		"id": "sadie", "name": "Sadie", "age": 24, "job": "Peloton instructor",
		"prompt": "A life goal of mine",
		"answer": "Never work in an office. No offence to anyone in an office.",
		"tint": Color("f77f00"), "likes": false,
		"opener": "",
	},
	{
		"id": "priya", "name": "Priya", "age": 30, "job": "Litigation — Buckhead",
		"prompt": "Don't hate me if I",
		"answer": "Cross-examine you about your Sunday plans. It's a reflex.",
		"tint": Color("7209b7"), "likes": true,
		"opener": "Your profile has three photos in the same parking deck. Explain.",
	},
	{
		"id": "kayla", "name": "Kayla", "age": 25, "job": "Vet tech",
		"prompt": "Together we could",
		"answer": "Foster a dog. I've already got the dog. You'd be joining us.",
		"tint": Color("2a9d8f"), "likes": true,
		"opener": "The dog's called Biscuit and he has already judged you.",
	},
	{
		"id": "danielle", "name": "Danielle", "age": 28, "job": "Realtor",
		"prompt": "My most irrational fear",
		"answer": "Zillow. I work in it. I fear it. Both things are true.",
		"tint": Color("e63946"), "likes": false,
		"opener": "",
	},
	{
		"id": "megan", "name": "Megan", "age": 27, "job": "Nurse — Northside",
		"prompt": "The hallmark of a good relationship is",
		"answer": "Not texting me between 7pm and 7am on a Thursday. Nights.",
		"tint": Color("457b9d"), "likes": true,
		"opener": "I'm off at 7. That's am. Which am is your problem to work out.",
	},
	{
		"id": "hannah", "name": "Hannah", "age": 23, "job": "Grad student, GSU",
		"prompt": "Worst idea I've ever had",
		"answer": "Moved to Alpharetta for a boy. Stayed for the Whole Foods.",
		"tint": Color("ffb703"), "likes": true,
		"opener": "Ok but be honest, do you actually like it here or",
	},
	{
		"id": "evan", "name": "Evan", "age": 31, "job": "Grounds — City of Alpharetta",
		"prompt": "My greatest strength",
		"answer": "Straight lines. Ask anyone whose lawn I've done. Straight lines.",
		"tint": Color("606c38"), "likes": true,
		"opener": "Wrong app maybe but you seem sound. Anyway. Nice stripes on 9th.",
	},
]


static func profile(id: String) -> Dictionary:
	for p in PROFILES:
		if String(p["id"]) == id:
			return p
	return {}


## The next profile you have not swiped on, or {} once you have seen everyone.
static func next_unseen(seen: Array) -> Dictionary:
	for p in PROFILES:
		if not seen.has(String(p["id"])):
			return p
	return {}


static func initials(name: String) -> String:
	return name.substr(0, 1).to_upper() if name.length() > 0 else "?"
