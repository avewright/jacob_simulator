extends AnimatableBody3D

# Harman. Four's problem, everyone's problem. He is nominally on the fourth
# floor but he is never on the fourth floor — he does a circuit of the whole
# building all day, stopping to talk at every desk, and he is covered head to
# boot in grease. It comes off him as he goes. Like a snail.
#
# He walks a fixed circuit rather than steering, because the building is known:
# the tower hands him the stair waypoints through stair_path(), and the desk
# stops below are chosen to sit in the gaps between the pods.
#
# AnimatableBody3D with sync_to_physics off, same as Evan: solid to bump into,
# and the transform written each frame is the one that sticks.

const WALK := 1.05             # he is not in a hurry and the floors are slick
const TURN := 4.0              # rad/s
const ARRIVE := 0.12
const SMEAR_EVERY := 0.42      # metres between grease marks
const MAX_SMEARS := 520        # oldest gets reused, so the pool never grows
const EARSHOT := 15.0

# Desk stops, in the order he does them, with the way in. `via` is the path
# from that floor's JUNCTION out to the desk — stepping straight off the
# corridor walks him through a desk for two of these, so the corners are
# spelled out rather than derived. He retraces `via` on the way back.
const ROUNDS := [
	# Lobby: reception runs x -6.7..-5.3, so he stops just east of it.
	{"floor": 0, "who": "Myriam", "via": [Vector2(0.0, 0.0)], "at": Vector2(-3.4, 0.0)},
	# Four: pods occupy x -11.45..-8.7, -6.45..-3.7, -1.45..1.3 by
	# z -1.05..1.0 and 4.95..7.0. So z 3.0 is clear right across the floor,
	# and x -3.2 is the gap between the middle and east pods — which is how
	# Collin gets approached from the south rather than through the pod.
	{"floor": 1, "who": "Wei", "via": [], "at": Vector2(1.9, 3.0)},
	{"floor": 1, "who": "Collin", "via": [Vector2(-3.2, 3.0)], "at": Vector2(-3.2, 6.4)},
	{"floor": 1, "who": "Porter", "via": [], "at": Vector2(-7.9, 3.0)},
	# Six: desks at x -10.2..-7.8 and -4.2..-1.8 by z -5.6..-4.4, -0.6..0.6,
	# 4.4..5.6. x 0.0 runs clear north to south; x -4.8 is the gap between the
	# desk columns, reached across z 2.5 which is between two desk rows.
	{"floor": 2, "who": "Ralph", "via": [Vector2(0.0, -6.0)], "at": Vector2(0.6, -6.0)},
	{"floor": 2, "who": "Ayden", "via": [Vector2(0.0, 0.0)], "at": Vector2(-4.8, 0.0)},
	{"floor": 2, "who": "Fiona", "via": [Vector2(0.0, 2.5), Vector2(-4.8, 2.5)],
		"at": Vector2(-4.8, 5.0)},
	{"floor": 2, "who": "Tyler", "via": [Vector2(0.0, 6.0)], "at": Vector2(0.6, 6.0)},
]

# Corridor lane on each floor: he runs along this to get between stops and the
# stairwell door, rather than cutting across the desks.
# The run between the stairwell door and the floor proper, and where that run
# meets the corridor. Everything on a floor hangs off its junction.
const DOOR_X := 6.7
const LANE_Z := -1.75
const JUNCTION := [Vector2(0.0, -1.75), Vector2(2.5, 3.0), Vector2(0.0, -1.75)]
# The circuit: lobby, four, six, four, and round again. Four comes up twice
# because that is the floor he is supposed to be on.
const ORDER := [0, 1, 2, 1]

const CHAT := {
	"Myriam": [
		"Morning Myriam. Don't lean on the counter, I leaned on the counter.",
		"You smell that? That's a healthy machine. That's what that is.",
	],
	"Wei": [
		"Wei. Your rack fans were screaming so I put some grease on them.",
		"Wei, I fixed the noise. Different noise now. Better noise.",
	],
	"Collin": [
		"Collin. Your chair squeaks. I've had a look at it. Don't sit down yet.",
		"Collin, quick one — is a spreadsheet meant to be this warm?",
	],
	"Porter": [
		"Porter. The lift's fine. I don't care what the panel says.",
		"Porter, I've been in the ceiling. There's a lot going on up there.",
	],
	"Ralph": [
		"Ralph! Godfather! I got the handle back on the fridge.",
		"Ralph, I'm not on your floor, I'm passing through your floor.",
	],
	"Ayden": [
		"Ayden. Don't shake my hand. I'm saying that as a friend.",
		"Ayden, your headset was crackling so I opened it up. Bit of a project.",
	],
	"Fiona": [
		"Fiona. I've done the door. It still sticks but it sticks quieter.",
		"Fiona, if anyone asks, the smell was there before I got here.",
	],
	"Tyler": [
		"Tyler, I don't know what a workstream is and I've stopped asking.",
		"Tyler. Partner. Your desk drawer runs like butter now. Literally.",
	],
}

const MUTTER := [
	"That's a two-rag job, that is.",
	"Whoever specified these floors never had to walk on them.",
	"Six flights a day. Six. Nobody's counting but me.",
	"I'll come back to it.",
]

var _route: Array = []          # [{at: Vector3, hold: float, who: String}]
var _leg: int = 0
var _hold: float = 0.0
var _heading: float = 0.0
var _pitch: float = 0.0
var _since_smear: float = 0.0
var _smears: Array[MeshInstance3D] = []
var _smear_at: int = 0
var _said: float = 0.0
var _rng := RandomNumberGenerator.new()
var _grease: StandardMaterial3D
var _tower: Node = null


func setup(tower: Node) -> void:
	_tower = tower
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	add_to_group("greaser")
	add_to_group("office_npc")
	_rng.randomize()
	_build_route()
	var first: Dictionary = _route[0]
	position = first["at"]
	_build_grease()
	_build_body()


func _physics_process(delta: float) -> void:
	if GameState.is_paused or _route.is_empty():
		return
	_said = maxf(_said - delta, 0.0)
	if _hold > 0.0:
		_hold -= delta
		return
	_advance(delta)


# ------------------------------------------------------------------ the round

func _push(at: Vector3, hold: float = 0.0, who: String = "") -> void:
	_route.append({"at": at, "hold": hold, "who": who})


## Lobby, up to four, up to six, back down. The stair legs come from the tower
## so the flights and the half landing only exist in one place.
func _build_route() -> void:
	var stops := {0: [], 1: [], 2: []}
	for r: Dictionary in ROUNDS:
		stops[int(r["floor"])].append(r)

	for k in ORDER.size():
		var i: int = ORDER[k]
		var y: float = _tower.floor_y(i)
		var junction: Vector2 = JUNCTION[i]
		# In off the stairs, out to the corridor, round the desks, back out.
		_push(Vector3(DOOR_X, y, LANE_Z))
		_push(Vector3(junction.x, y, junction.y))
		for r: Dictionary in stops[i]:
			var via: Array = r["via"]
			var at: Vector2 = r["at"]
			for v: Vector2 in via:
				_push(Vector3(v.x, y, v.y))
			_push(Vector3(at.x, y, at.y), _rng.randf_range(3.0, 5.0), String(r["who"]))
			for j in range(via.size() - 1, -1, -1):
				var back: Vector2 = via[j]
				_push(Vector3(back.x, y, back.y))
			_push(Vector3(junction.x, y, junction.y))
		_push(Vector3(DOOR_X, y, LANE_Z))
		# And the stairs to wherever he is going next. Reading the next entry
		# rather than the next floor number matters: four appears twice, and
		# which way he leaves it depends on which visit this is.
		var next: int = ORDER[(k + 1) % ORDER.size()]
		if next != i:
			for step: Vector3 in _tower.stair_path(i, next):
				_push(step)


func _advance(delta: float) -> void:
	var here: Dictionary = _route[_leg]
	var goal: Vector3 = here["at"]
	var to := goal - position
	var flat := Vector2(to.x, to.z)

	if flat.length() < ARRIVE:
		position = goal
		_arrive(here)
		_leg = (_leg + 1) % _route.size()
		return

	var want := atan2(to.x, to.z)
	_heading = _turn_toward(_heading, want, TURN * delta)
	rotation.y = _heading
	# Grease lies along the slope, so the marks on the stairs tilt with the
	# flight instead of hovering flat over it.
	_pitch = -atan2(to.y, maxf(flat.length(), 0.001))

	var step := minf(WALK * delta, flat.length())
	var move := Vector3(sin(_heading), 0.0, cos(_heading)) * step
	move.y = to.y * (step / maxf(flat.length(), 0.001))
	position += move

	_since_smear += step
	if _since_smear >= SMEAR_EVERY:
		_smear()
		_since_smear = 0.0


func _turn_toward(from: float, to: float, most: float) -> float:
	return from + clampf(wrapf(to - from, -PI, PI), -most, most)


func _arrive(leg: Dictionary) -> void:
	var hold := float(leg["hold"])
	if hold <= 0.0:
		return
	_hold = hold
	var who := String(leg["who"])
	if who == "" or _said > 0.0 or not _in_earshot():
		return
	var lines: Array = CHAT.get(who, MUTTER)
	GameState.notice.emit("Harman: %s" % String(lines[_rng.randi_range(0, lines.size() - 1)]))
	_said = 12.0


func _in_earshot() -> bool:
	var here := GameState.here()
	if absf(here.y - global_position.y) > 3.0:
		return false
	return Vector2(here.x - global_position.x, here.z - global_position.z).length() < EARSHOT


# ------------------------------------------------------------------ the trail

func _build_grease() -> void:
	_grease = StandardMaterial3D.new()
	_grease.albedo_color = Color(0.10, 0.09, 0.06, 0.62)
	_grease.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grease.roughness = 0.08
	_grease.metallic = 0.35
	# A snail trail catches the light. Just enough sheen to show up in the
	# stairwell, where the only light is the landing lamp.
	_grease.emission_enabled = true
	_grease.emission = Color("3a3320")
	_grease.emission_energy_multiplier = 0.25


## One smear under his boots, laid flat on whatever he is standing on.
func _smear() -> void:
	var mi: MeshInstance3D
	if _smears.size() < MAX_SMEARS:
		mi = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.52, 0.015, SMEAR_EVERY + 0.22)
		mi.mesh = box
		mi.material_override = _grease
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(mi)
		_smears.append(mi)
	else:
		mi = _smears[_smear_at]
		_smear_at = (_smear_at + 1) % MAX_SMEARS
	mi.position = position + Vector3(0, 0.025, 0)
	# Yaw first, then tilt about the sideways axis of that yawed frame, so the
	# mark lies in the plane of the ramp rather than across it.
	mi.basis = Basis(Vector3.UP, _heading) * Basis(Vector3.RIGHT, _pitch)


# ------------------------------------------------------------------ the man

func _mat(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _box(centre: Vector3, size: Vector3, material: Material, yaw: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = centre
	mi.rotation.y = yaw
	add_child(mi)


func _build_body() -> void:
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.78
	col.shape = shape
	col.position.y = 0.89
	add_child(col)

	# Everything on him is the same shade of worked-in grease, at different
	# stages of drying. Low roughness so he catches the strip lights.
	var overall := _mat(Color("3a4048"), 0.45, 0.2)
	var stain := _mat(Color("15161a"), 0.12, 0.5)
	var shirt := _mat(Color("6f7360"), 0.55)
	var skin := _mat(Color("a98b6a"), 0.35)
	var hair := _mat(Color("2a2420"), 0.25, 0.3)
	var boot := _mat(Color("1b1a18"), 0.3, 0.3)
	var rag := _mat(Color("8a5f3a"), 0.7)

	_box(Vector3(0, 1.02, 0), Vector3(0.5, 0.62, 0.3), shirt)
	_box(Vector3(0, 0.74, 0), Vector3(0.52, 0.5, 0.32), overall)
	_box(Vector3(0, 1.12, 0.16), Vector3(0.3, 0.42, 0.04), overall)      # bib
	# Smeared over the front, down one thigh, and both forearms.
	_box(Vector3(0.1, 0.98, 0.17), Vector3(0.26, 0.3, 0.03), stain)
	_box(Vector3(-0.14, 0.5, 0.1), Vector3(0.16, 0.34, 0.03), stain)
	_box(Vector3(-0.13, 0.4, 0), Vector3(0.19, 0.62, 0.21), overall)
	_box(Vector3(0.13, 0.4, 0), Vector3(0.19, 0.62, 0.21), overall)
	_box(Vector3(-0.13, 0.05, 0.03), Vector3(0.21, 0.12, 0.3), boot)
	_box(Vector3(0.13, 0.05, 0.03), Vector3(0.21, 0.12, 0.3), boot)
	# Arms held slightly away from himself, the way you do.
	_box(Vector3(-0.33, 1.04, 0.02), Vector3(0.14, 0.5, 0.16), shirt, 0.0)
	_box(Vector3(0.33, 1.04, 0.02), Vector3(0.14, 0.5, 0.16), shirt, 0.0)
	_box(Vector3(-0.35, 0.74, 0.04), Vector3(0.13, 0.26, 0.14), stain)
	_box(Vector3(0.35, 0.74, 0.04), Vector3(0.13, 0.26, 0.14), stain)
	_box(Vector3(-0.36, 0.57, 0.05), Vector3(0.12, 0.12, 0.14), stain)
	_box(Vector3(0.36, 0.57, 0.05), Vector3(0.12, 0.12, 0.14), stain)
	# Rag hanging out of the back pocket, doing nothing for anyone.
	_box(Vector3(-0.2, 0.56, -0.16), Vector3(0.14, 0.2, 0.05), rag, 0.3)

	_box(Vector3(0, 1.4, 0), Vector3(0.13, 0.14, 0.13), skin)
	_box(Vector3(0, 1.57, 0), Vector3(0.25, 0.27, 0.24), skin)
	_box(Vector3(0.06, 1.52, 0.12), Vector3(0.1, 0.07, 0.02), stain)     # cheek
	_box(Vector3(0, 1.71, -0.01), Vector3(0.27, 0.1, 0.26), hair)
	_box(Vector3(0, 1.66, -0.12), Vector3(0.27, 0.14, 0.08), hair)
	_box(Vector3(0, 1.67, 0.12), Vector3(0.23, 0.07, 0.05), hair)

	var tag := Label3D.new()
	tag.text = "Harman — Facilities"
	tag.position = Vector3(0, 2.0, 0)
	tag.font_size = 24
	tag.modulate = Color("c9c2a4")
	tag.outline_modulate = Color.BLACK
	tag.outline_size = 6
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)
