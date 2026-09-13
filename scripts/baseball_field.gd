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
const SEGMENTS := 26           # panels making up the fence arc
const FOUL := PI * 0.25        # foul line angle off centre
const TRACK := 3.2             # warning track width
const SKIN := 30.0             # dirt infield, home plate to the arc
const PATH := 1.5              # base path half width

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

## Playing surface.
##
## This used to be laid out with boxes, one per wedge. A box cannot taper, so
## every wedge stayed full width all the way in to home plate and all 26 of
## them piled up on top of each other over the batter's boxes — that was the
## green covering the plate, and the flickering across the infield. Ground
## markings are built as real fan geometry now, so a wedge is actually a wedge
## and nothing overlaps anything.
func _surface() -> void:
	# Outfield and foul ground, in alternating mown bands.
	for i in SEGMENTS:
		var a0 := -FOUL + (2.0 * FOUL) * i / float(SEGMENTS)
		var a1 := -FOUL + (2.0 * FOUL) * (i + 1) / float(SEGMENTS)
		_sector(0.0, FENCE - TRACK, a0, a1, 0.02, _cut if i % 2 == 0 else _grass)
	# Foul ground carries on past the poles to the fence line.
	_sector(0.0, FENCE - TRACK, -FOUL - 0.22, -FOUL, 0.02, _grass)
	_sector(0.0, FENCE - TRACK, FOUL, FOUL + 0.22, 0.02, _grass)
	# Warning track, a band of dirt inside the wall.
	_sector(FENCE - TRACK, FENCE, -FOUL - 0.22, FOUL + 0.22, 0.04, _dirt)


func _infield() -> void:
	var b := BASE / sqrt(2.0)
	var second := BASE * sqrt(2.0)
	# Skinned infield: dirt from the plate out to the arc, cut off at the
	# foul lines the way it is on a real field.
	_sector(0.0, SKIN, -FOUL, FOUL, 0.06, _dirt)
	# Grass inside the base paths — a diamond, inset from the paths by PATH.
	var inset := PATH * sqrt(2.0)
	_poly([
		Vector2(0.0, inset),
		Vector2(b - inset * 0.5, b),
		Vector2(0.0, second - inset),
		Vector2(-b + inset * 0.5, b),
	], 0.09, _cut)
	# Plate circle and the mound, both dirt cut back into that grass. Each
	# marking sits a clear step above whatever it covers, so no two coplanar
	# surfaces are left to fight over the depth buffer.
	_disc(Vector2.ZERO, 3.4, 0.12, _dirt)
	_disc(Vector2(0.0, MOUND), 2.7, 0.12, _dirt)
	_disc(Vector2(0.0, MOUND), 1.8, 0.17, _dirt)
	_disc(Vector2(0.0, MOUND), 0.9, 0.21, _dirt)
	_box(Vector3(0, 0.25, MOUND), Vector3(0.6, 0.04, 0.16), _chalk)
	# On-deck circles, out in foul ground where only grass lies under them.
	for side: float in [-1.0, 1.0]:
		var a := side * (FOUL + 0.11)
		_disc(Vector2(sin(a), cos(a)) * 13.0, 1.5, 0.06, _dirt)

	# Plate, bases, and the chalk.
	_box(Vector3(0, 0.17, 0.26), Vector3(0.45, 0.04, 0.45), _chalk, PI * 0.25)
	for at: Vector3 in [Vector3(b, 0.17, b), Vector3(0, 0.17, second), Vector3(-b, 0.17, b)]:
		_box(at, Vector3(0.5, 0.05, 0.5), _chalk)
	# Foul lines run from the plate out to the poles, along the 45s.
	for side: float in [-1.0, 1.0]:
		var a := side * FOUL
		_box(Vector3(sin(a), 0.16, cos(a)) * FENCE * 0.5, Vector3(0.12, 0.03, FENCE), _chalk, a)
	# Batter's boxes: chalk outline with the dirt showing through the middle.
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * 1.05, 0.16, 0.26), Vector3(1.25, 0.03, 1.85), _chalk)
		_box(Vector3(side * 1.05, 0.19, 0.26), Vector3(1.05, 0.03, 1.65), _dirt)
	# Catcher's box behind the plate.
	_box(Vector3(0, 0.16, -1.15), Vector3(1.9, 0.03, 2.4), _chalk)
	_box(Vector3(0, 0.19, -1.15), Vector3(1.7, 0.03, 2.2), _dirt)
	# Coach's boxes down each line.
	for side: float in [-1.0, 1.0]:
		var a := side * (FOUL + 0.085)
		_box(Vector3(sin(a), 0.16, cos(a)) * 17.0, Vector3(1.4, 0.03, 4.0), _chalk, a)


## An annulus sector laid flat: the real shape of a wedge of a ball field, so
## it tapers to nothing at the middle instead of staying full width.
func _sector(r0: float, r1: float, a0: float, a1: float, y: float, material: Material) -> void:
	var steps := maxi(2, int(ceil((a1 - a0) / 0.12)))
	var verts := PackedVector3Array()
	for i in steps:
		var t0 := a0 + (a1 - a0) * i / float(steps)
		var t1 := a0 + (a1 - a0) * (i + 1) / float(steps)
		var i0 := Vector3(sin(t0), 0.0, cos(t0)) * r0
		var i1 := Vector3(sin(t1), 0.0, cos(t1)) * r0
		var o0 := Vector3(sin(t0), 0.0, cos(t0)) * r1
		var o1 := Vector3(sin(t1), 0.0, cos(t1)) * r1
		verts.append_array([i0, o0, o1, i0, o1, i1])
	_flat_mesh(verts, y, material)


func _disc(centre: Vector2, radius: float, y: float, material: Material) -> void:
	var steps := 28
	var verts := PackedVector3Array()
	var mid := Vector3(centre.x, 0.0, centre.y)
	for i in steps:
		var t0 := TAU * i / float(steps)
		var t1 := TAU * (i + 1) / float(steps)
		verts.append_array([mid,
			mid + Vector3(sin(t0), 0.0, cos(t0)) * radius,
			mid + Vector3(sin(t1), 0.0, cos(t1)) * radius])
	_flat_mesh(verts, y, material)


## Convex polygon, as a fan off the first point.
func _poly(points: Array, y: float, material: Material) -> void:
	var verts := PackedVector3Array()
	for i in range(1, points.size() - 1):
		var a: Vector2 = points[0]
		var b: Vector2 = points[i]
		var c: Vector2 = points[i + 1]
		verts.append_array([Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y), Vector3(c.x, 0.0, c.y)])
	_flat_mesh(verts, y, material)


## Ground markings are flat, unlit-ish and never collide — you walk on the
## world's own ground plane, these only paint it.
func _flat_mesh(verts: PackedVector3Array, y: float, material: Material) -> void:
	if verts.is_empty():
		return
	var normals := PackedVector3Array()
	for v in verts:
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position.y = y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------------ structure

func _fence() -> void:
	for i in SEGMENTS:
		var a := -FOUL + (2.0 * FOUL) * (i + 0.5) / float(SEGMENTS)
		var chord := 2.0 * FENCE * sin(FOUL / float(SEGMENTS))
		var at := Vector3(sin(a), 0.0, cos(a)) * FENCE
		_box(at + Vector3(0, WALL_H * 0.5, 0), Vector3(chord + 0.3, WALL_H, 0.3), _wall, a, true)
		_box(at + Vector3(0, WALL_H + 0.06, 0), Vector3(chord + 0.3, 0.12, 0.42), _chalk, a)
	# Foul poles.
	for side: float in [-1.0, 1.0]:
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


## Chain link behind the plate, on an arc centred on it. The wings used to be
## placed by one angle and yawed by another, which left them sitting at 70
## degrees to the arc — the main reason the whole thing read as sloppy.
func _backstop() -> void:
	var mesh := _mat(Color(0.74, 0.78, 0.74, 0.30), 0.6, 0.3)
	mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mesh.alpha_scissor_threshold = 0.2
	mesh.cull_mode = BaseMaterial3D.CULL_DISABLED

	var r := 8.6
	var spread := 0.85          # half the arc, either side of straight back
	var panels := 7
	for i in panels:
		# Measured round from straight behind the plate, so position and yaw
		# come from the same angle and every panel sits square to the arc.
		var t0 := PI - spread + (2.0 * spread) * i / float(panels)
		var t1 := PI - spread + (2.0 * spread) * (i + 1) / float(panels)
		var a := (t0 + t1) * 0.5
		var chord := 2.0 * r * sin((t1 - t0) * 0.5)
		var at := Vector3(sin(a), 0.0, cos(a)) * r
		_box(at + Vector3(0, 1.1, 0), Vector3(chord + 0.12, 2.2, 0.22), _pad, a, true)
		_box(at + Vector3(0, 3.9, 0), Vector3(chord + 0.12, 3.4, 0.08), mesh, a, true)
		# Canopy leaning out over the catcher, the way they always do.
		var lean := Vector3(sin(a), 0.0, cos(a)) * -0.8
		_box(at + lean + Vector3(0, 5.7, 0), Vector3(chord + 0.12, 0.08, 1.7), mesh, a)
	# Posts on every panel edge, carried up past the canopy.
	for i in panels + 1:
		var t := PI - spread + (2.0 * spread) * i / float(panels)
		var at := Vector3(sin(t), 0.0, cos(t)) * r
		_box(at + Vector3(0, 2.9, 0), Vector3(0.16, 5.8, 0.16), _steel, t, true)

	var sign := Label3D.new()
	sign.text = "ALPHARETTA HIGH SCHOOL"
	sign.position = Vector3(0, 6.6, -r - 0.2)
	sign.font_size = 54
	sign.modulate = Color("f6c000")
	sign.outline_modulate = Color("10241a")
	sign.outline_size = 9
	sign.rotation.y = PI
	add_child(sign)

	var sub := Label3D.new()
	sub.text = "HOME OF THE RAIDERS   ·   BASEBALL FIELD"
	sub.position = Vector3(0, 5.6, -r - 0.2)
	sub.font_size = 26
	sub.modulate = Color("f2f2ea")
	sub.outline_modulate = Color("10241a")
	sub.outline_size = 6
	sub.rotation.y = PI
	add_child(sub)


## Somewhere out on the field, in the frame of something facing along `yaw`:
## +x is to its right, +z is straight ahead of it.
func _out(at: Vector3, yaw: float, right: float, up: float, ahead: float) -> Vector3:
	return at + Vector3(cos(yaw) * right + sin(yaw) * ahead, up,
		-sin(yaw) * right + cos(yaw) * ahead)


## Dugouts either side of the plate, dug in behind a low wall, roofed, opening
## on to the field. Everything is placed in the dugout's own frame — the old
## version mixed local and world offsets, so the benches slid sideways out of
## the shelters on both sides.
func _dugouts() -> void:
	var block := _mat(Color("b9b4a6"), 0.9)
	var roof := _mat(Color("55606d"), 0.7)
	for side: float in [-1.0, 1.0]:
		var yaw := side * (FOUL + 0.14)
		var at := Vector3(sin(yaw), 0.0, cos(yaw)) * 23.0
		# Back wall, two ends, and a low wall along the front with the middle
		# left open so you can see in.
		_box(_out(at, yaw, 0, 1.3, 1.9), Vector3(9.4, 2.6, 0.3), block, yaw, true)
		for end_x: float in [-4.55, 4.55]:
			_box(_out(at, yaw, end_x, 1.3, 0.6), Vector3(0.3, 2.6, 2.9), block, yaw, true)
		for front_x: float in [-3.6, 3.6]:
			_box(_out(at, yaw, front_x, 0.55, -0.8), Vector3(2.2, 1.1, 0.25), block, yaw, true)
		# Bench against the back wall, and the step down into it.
		_box(_out(at, yaw, 0, 0.45, 1.35), Vector3(8.6, 0.12, 0.55), _mat(Color("6b4a2f"), 0.8), yaw, true)
		_box(_out(at, yaw, 0, 0.22, 1.35), Vector3(8.6, 0.44, 0.1), block, yaw)
		_box(_out(at, yaw, 0, 0.06, 0.3), Vector3(8.8, 0.12, 3.2), _mat(Color("8e8b82"), 0.9), yaw)
		# Roof, on two posts at the open front.
		_box(_out(at, yaw, 0, 2.7, 0.5), Vector3(9.8, 0.2, 4.2), roof, yaw, true)
		for post_x: float in [-4.3, 4.3]:
			_box(_out(at, yaw, post_x, 1.3, -1.4), Vector3(0.16, 2.6, 0.16), _steel, yaw, true)
		# Netting over the front, so nothing lands in the bench.
		var net := _mat(Color(0.74, 0.78, 0.74, 0.26), 0.6, 0.3)
		net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		net.alpha_scissor_threshold = 0.2
		net.cull_mode = BaseMaterial3D.CULL_DISABLED
		_box(_out(at, yaw, 0, 1.9, -1.45), Vector3(8.8, 1.4, 0.06), net, yaw)


func _bleachers() -> void:
	var steel := _mat(Color("8d949c"), 0.5, 0.4)
	for side: float in [-1.0, 1.0]:
		var base := Vector3(side * 12.0, 0.0, -11.0)
		for row in 5:
			var y := 0.5 + row * 0.42
			var z := base.z - row * 0.72
			_box(Vector3(base.x, y, z), Vector3(11.0, 0.14, 0.62), steel)
			_box(Vector3(base.x, y - 0.25, z), Vector3(11.0, 0.5, 0.08), _pad)
		_box(Vector3(base.x, 1.9, base.z - 3.6), Vector3(11.0, 0.1, 0.1), steel)
		for post: float in [-5.2, 0.0, 5.2]:
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
		for lamp: float in [-1.2, 0.0, 1.2]:
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
