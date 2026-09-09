extends Node3D

# Alpharetta High School baseball field. Node origin sits on home plate, the
# field opening toward +Z, so every measurement below reads the way a ground
# plan does: bases at BASE, mound at MOUND, fence at FENCE.
#
# Foul lines run at 45 degrees either side of +Z, which puts first base at
# (BASE/root2, BASE/root2) and second base straight out at BASE*root2.

const BASE := 22.0             # base path
const FENCE := 62.0            # home plate to the outfield wall
const MOUND := 15.0
const WALL_H := 2.4
const SEGMENTS := 26           # boxes making up the fence arc
const FOUL := PI * 0.25        # foul line angle off centre

var _grass: StandardMaterial3D
var _cut: StandardMaterial3D
var _dirt: StandardMaterial3D
var _chalk: StandardMaterial3D
var _wall: StandardMaterial3D
var _steel: StandardMaterial3D
var _pad: StandardMaterial3D


func _ready() -> void:
	add_to_group("baseball_field")
	_mats()
	_surface()
	_infield()
	_fence()
	_backstop()
	_dugouts()
	_bleachers()
	_scoreboard()
	_lights()


func _mats() -> void:
	_grass = _mat(Color("38702c"), 0.95)
	_cut = _mat(Color("4c8a34"), 0.95)
	_dirt = _mat(Color("9c6b42"), 0.95)
	_chalk = _mat(Color("f2f2ea"), 0.7)
	_wall = _mat(Color("1f4d2b"), 0.8)
	_steel = _mat(Color("9aa0a6"), 0.45, 0.55)
	_pad = _mat(Color("2b2f36"), 0.8)


# ------------------------------------------------------------------ ground

## Playing surface: a fan of wedges out to the fence, so the grass stops where
## the wall does instead of sitting in a square that pokes out behind it.
func _surface() -> void:
	for i in SEGMENTS:
		var a0 := -FOUL + (2.0 * FOUL) * i / float(SEGMENTS)
		var a1 := -FOUL + (2.0 * FOUL) * (i + 1) / float(SEGMENTS)
		var mid := (a0 + a1) * 0.5
		var chord := 2.0 * FENCE * sin((a1 - a0) * 0.5)
		# Every other wedge a shade lighter: the mown-in pattern.
		_box(Vector3(sin(mid), 0.0, cos(mid)) * FENCE * 0.5 + Vector3(0, 0.02, 0),
			Vector3(chord + 0.4, 0.04, FENCE), _cut if i % 2 == 0 else _grass, mid)
	# Foul ground either side, out to the poles.
	for side in [-1.0, 1.0]:
		var a := side * (FOUL + 0.16)
		_box(Vector3(sin(a), 0.02, cos(a)) * FENCE * 0.5, Vector3(9.0, 0.04, FENCE), _grass, a)
	# Warning track just inside the wall.
	for i in SEGMENTS:
		var a := -FOUL + (2.0 * FOUL) * (i + 0.5) / float(SEGMENTS)
		var chord := 2.0 * FENCE * sin(FOUL / float(SEGMENTS))
		_box(Vector3(sin(a), 0.03, cos(a)) * (FENCE - 1.6), Vector3(chord + 0.4, 0.04, 3.2), _dirt, a)


func _infield() -> void:
	var b := BASE / sqrt(2.0)
	# Skinned infield: a diamond of dirt, drawn as a square turned 45 degrees.
	_box(Vector3(0, 0.05, b), Vector3(BASE + 9.0, 0.04, BASE + 9.0), _dirt, PI * 0.25)
	# Infield grass sits inside the base paths.
	_box(Vector3(0, 0.07, b), Vector3(BASE - 5.0, 0.04, BASE - 5.0), _cut, PI * 0.25)
	# Home plate circle and the mound.
	_box(Vector3(0, 0.06, 0), Vector3(7.0, 0.04, 7.0), _dirt)
	_box(Vector3(0, 0.08, MOUND), Vector3(5.4, 0.16, 5.4), _dirt)
	_box(Vector3(0, 0.17, MOUND), Vector3(0.6, 0.05, 0.16), _chalk)

	# Bases and plate.
	_box(Vector3(0, 0.09, 0.2), Vector3(0.5, 0.05, 0.5), _chalk, PI * 0.25)
	for at in [Vector3(b, 0.09, b), Vector3(0, 0.09, BASE * sqrt(2.0)), Vector3(-b, 0.09, b)]:
		_box(at, Vector3(0.55, 0.06, 0.55), _chalk)

	# Foul lines from the plate out to the poles.
	for side in [-1.0, 1.0]:
		var a := side * FOUL
		_box(Vector3(sin(a), 0.09, cos(a)) * FENCE * 0.5, Vector3(0.14, 0.04, FENCE), _chalk, a)
	# Batter's boxes.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 1.1, 0.09, 0.1), Vector3(1.2, 0.04, 1.8), _chalk)
		_box(Vector3(side * 1.1, 0.10, 0.1), Vector3(0.95, 0.04, 1.55), _dirt)


# ------------------------------------------------------------------ structure

func _fence() -> void:
	for i in SEGMENTS:
		var a := -FOUL + (2.0 * FOUL) * (i + 0.5) / float(SEGMENTS)
		var chord := 2.0 * FENCE * sin(FOUL / float(SEGMENTS))
		var at := Vector3(sin(a), 0.0, cos(a)) * FENCE
		_box(at + Vector3(0, WALL_H * 0.5, 0), Vector3(chord + 0.3, WALL_H, 0.3), _wall, a, true)
		_box(at + Vector3(0, WALL_H + 0.06, 0), Vector3(chord + 0.3, 0.12, 0.42), _chalk, a)
	# Foul poles.
	for side in [-1.0, 1.0]:
		var a := side * FOUL
		var at := Vector3(sin(a), 0.0, cos(a)) * FENCE
		_box(at + Vector3(0, 4.5, 0), Vector3(0.3, 9.0, 0.3), _mat(Color("f6c000"), 0.5), 0.0, true)
	# Distance markers on the wall.
	for pair in [[-FOUL * 0.82, "310"], [0.0, "375"], [FOUL * 0.82, "310"]]:
		var a: float = float(pair[0])
		var mark := Label3D.new()
		mark.text = String(pair[1])
		mark.position = Vector3(sin(a), 1.4, cos(a)) * (FENCE - 0.3)
		mark.font_size = 40
		mark.modulate = Color("f2f2ea")
		mark.rotation.y = a + PI
		add_child(mark)


func _backstop() -> void:
	# Chain link behind the plate, curved round on both sides.
	var mesh := _mat(Color(0.72, 0.76, 0.72, 0.28), 0.6, 0.3)
	mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mesh.alpha_scissor_threshold = 0.2
	mesh.cull_mode = BaseMaterial3D.CULL_DISABLED
	for pair in [[-0.62, -7.2], [0.0, -8.6], [0.62, -7.2]]:
		var a: float = float(pair[0])
		var r: float = absf(float(pair[1]))
		var at := Vector3(sin(a) * r, 0.0, -r * cos(a))
		_box(at + Vector3(0, 2.6, 0), Vector3(7.2, 5.2, 0.14), mesh, a, true)
		_box(at + Vector3(0, 2.6, 0) + Vector3(3.5 * cos(a), 0, 3.5 * sin(a)),
			Vector3(0.22, 5.4, 0.22), _steel, a)
	_box(Vector3(0, 1.1, -6.6), Vector3(9.0, 2.2, 0.2), _pad, 0.0, true)

	var sign := Label3D.new()
	sign.text = "ALPHARETTA HIGH SCHOOL"
	sign.position = Vector3(0, 6.0, -8.6)
	sign.font_size = 54
	sign.modulate = Color("f6c000")
	sign.outline_modulate = Color("10241a")
	sign.outline_size = 9
	sign.rotation.y = PI
	add_child(sign)

	var sub := Label3D.new()
	sub.text = "HOME OF THE RAIDERS   ·   BASEBALL FIELD"
	sub.position = Vector3(0, 5.0, -8.6)
	sub.font_size = 26
	sub.modulate = Color("f2f2ea")
	sub.outline_modulate = Color("10241a")
	sub.outline_size = 6
	sub.rotation.y = PI
	add_child(sub)


func _dugouts() -> void:
	var block := _mat(Color("b9b4a6"), 0.9)
	for side in [-1.0, 1.0]:
		var a := side * (FOUL + 0.13)
		var at := Vector3(sin(a), 0.0, cos(a)) * 22.0
		_box(at + Vector3(0, 1.1, 0), Vector3(9.0, 2.2, 0.35), block, a, true)
		_box(at + Vector3(0, 0.25, side * 1.6), Vector3(8.6, 0.5, 1.2), block, a)
		_box(at + Vector3(0, 0.85, side * 1.9), Vector3(8.6, 0.14, 0.5), _mat(Color("6b4a2f"), 0.8), a)
		_box(at + Vector3(0, 2.5, side * 1.4), Vector3(9.4, 0.18, 3.6), _mat(Color("55606d"), 0.7), a, true)
		for post in [-4.2, 4.2]:
			var off := Vector3(cos(a) * post, 1.2, -sin(a) * post)
			_box(at + off + Vector3(0, 0, side * 3.0), Vector3(0.18, 2.4, 0.18), _steel)


func _bleachers() -> void:
	var steel := _mat(Color("8d949c"), 0.5, 0.4)
	for side in [-1.0, 1.0]:
		var base := Vector3(side * 12.0, 0.0, -11.0)
		for row in 5:
			var y := 0.5 + row * 0.42
			var z := base.z - row * 0.72
			_box(Vector3(base.x, y, z), Vector3(11.0, 0.14, 0.62), steel)
			_box(Vector3(base.x, y - 0.25, z), Vector3(11.0, 0.5, 0.08), _pad)
		_box(Vector3(base.x, 1.9, base.z - 3.6), Vector3(11.0, 0.1, 0.1), steel)
		for post in [-5.2, 0.0, 5.2]:
			_box(Vector3(base.x + post, 1.0, base.z - 3.6), Vector3(0.12, 2.0, 0.12), steel)


func _scoreboard() -> void:
	var at := Vector3(0, 0, FENCE + 7.0)
	_box(at + Vector3(-3.2, 3.0, 0), Vector3(0.4, 6.0, 0.4), _steel, 0.0, true)
	_box(at + Vector3(3.2, 3.0, 0), Vector3(0.4, 6.0, 0.4), _steel, 0.0, true)
	_box(at + Vector3(0, 7.6, 0), Vector3(9.0, 4.4, 0.5), _mat(Color("14181d"), 0.8), 0.0, true)
	_box(at + Vector3(0, 7.6, -0.3), Vector3(8.4, 3.8, 0.06), _mat(Color("0d1116"), 0.6))

	var board := Label3D.new()
	board.text = "HOME  3\nGUEST 2\n\nINN 6"
	board.position = at + Vector3(0, 7.6, -0.4)
	board.font_size = 40
	board.modulate = Color("ffb703")
	board.rotation.y = PI
	add_child(board)

	var name_l := Label3D.new()
	name_l.text = "RAIDERS BASEBALL"
	name_l.position = at + Vector3(0, 5.1, -0.4)
	name_l.font_size = 26
	name_l.modulate = Color("f2f2ea")
	name_l.rotation.y = PI
	add_child(name_l)


func _lights() -> void:
	for spec in [[-FOUL * 0.9, 34.0], [FOUL * 0.9, 34.0], [-FOUL * 0.5, FENCE - 4.0], [FOUL * 0.5, FENCE - 4.0]]:
		var a: float = float(spec[0])
		var r: float = float(spec[1])
		var at := Vector3(sin(a), 0.0, cos(a)) * r
		_box(at + Vector3(0, 7.0, 0), Vector3(0.5, 14.0, 0.5), _steel, 0.0, true)
		_box(at + Vector3(0, 14.4, 0), Vector3(4.0, 0.9, 0.5), _pad)
		for lamp in [-1.2, 0.0, 1.2]:
			_box(at + Vector3(lamp, 14.4, -0.3), Vector3(1.0, 0.7, 0.14),
				_mat(Color("fff4dd"), 0.3))
		var light := SpotLight3D.new()
		light.position = at + Vector3(0, 14.2, 0)
		light.look_at_from_position(at + Vector3(0, 14.2, 0), Vector3(0, 0, MOUND), Vector3.UP)
		light.spot_range = 90.0
		light.spot_angle = 42.0
		light.light_energy = 2.4
		light.light_color = Color("eaf2ff")
		light.shadow_enabled = false
		add_child(light)


func _box(centre: Vector3, size: Vector3, material: Material, yaw: float = 0.0,
		solid: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = centre
	mi.rotation.y = yaw
	add_child(mi)
	if not solid:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = centre
	body.rotation.y = yaw
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m
