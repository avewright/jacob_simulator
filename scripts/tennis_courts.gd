extends Node3D

# Two hard courts, laid out to regulation so a match minigame can use the
# markings directly rather than guessing at them.
#
#   full court   23.77 long x 10.97 wide (doubles)
#   singles      8.23 wide
#   service line 6.40 from the net
#   net          1.07 at the posts, 0.914 at centre
#
# Local space: origin between the two courts on the ground; courts run along Z.

const LEN := 23.77
const DOUBLES := 10.97
const SINGLES := 8.23
const SERVICE := 6.40
const LINE := 0.1
const NET_POST := 1.07
const NET_MID := 0.914
const RUNOFF_END := 6.4
const RUNOFF_SIDE := 3.66
const FENCE_H := 3.6
const COURT_GAP := 24.0     # centre-to-centre spacing of the two courts

var _surface: StandardMaterial3D
var _apron: StandardMaterial3D
var _line: StandardMaterial3D
var _mesh_m: StandardMaterial3D
var _post: StandardMaterial3D


func _ready() -> void:
	add_to_group("tennis_courts")
	_make_mats()
	_pad()
	for side in [-1.0, 1.0]:
		_court(side * COURT_GAP * 0.5)
	_fence()
	_furniture()


func _make_mats() -> void:
	_surface = _mat(Color("2e6f5e"), 0.92)
	_apron = _mat(Color("1f4f6e"), 0.92)
	_line = _mat(Color("f4f7f4"), 0.7)
	_mesh_m = _mat(Color("2a2f2c"), 0.85)
	_post = _mat(Color("22262a"), 0.5, 0.3)


func _pad() -> void:
	var w := COURT_GAP + DOUBLES + RUNOFF_SIDE * 2.0
	var d := LEN + RUNOFF_END * 2.0
	_box(Vector3(0, 0.008, 0), Vector3(w, 0.016, d), _apron, false)


## One court, centred at x = cx.
func _court(cx: float) -> void:
	var hl := LEN * 0.5
	var hw := DOUBLES * 0.5
	var hs := SINGLES * 0.5

	_box(Vector3(cx, 0.014, 0), Vector3(DOUBLES + 2.4, 0.014, LEN + 3.2), _surface, false)

	# Baselines and doubles sidelines.
	for dz in [-hl, hl]:
		_line_box(Vector2(cx, dz), Vector2(DOUBLES, LINE))
	for dx in [-hw, hw]:
		_line_box(Vector2(cx + dx, 0), Vector2(LINE, LEN))
	# Singles sidelines.
	for dx in [-hs, hs]:
		_line_box(Vector2(cx + dx, 0), Vector2(LINE, LEN))
	# Service lines and the centre service line.
	for dz in [-SERVICE, SERVICE]:
		_line_box(Vector2(cx, dz), Vector2(SINGLES, LINE))
	_line_box(Vector2(cx, 0), Vector2(LINE, SERVICE * 2.0))
	# Centre marks on the baselines.
	for dz in [-hl + 0.15, hl - 0.15]:
		_line_box(Vector2(cx, dz), Vector2(LINE, 0.3))

	# Net: posts, cord, and a band that dips to 0.914 at the centre.
	for dx in [-hw - 0.914, hw + 0.914]:
		_box(Vector3(cx + dx, NET_POST * 0.5, 0), Vector3(0.12, NET_POST, 0.12), _post, true)
	var span := DOUBLES + 1.83
	var segs := 9
	for i in segs:
		var t := (i + 0.5) / float(segs)
		var x := cx - span * 0.5 + span * t
		# Parabolic sag between the posts.
		var h: float = NET_MID + (NET_POST - NET_MID) * pow(2.0 * absf(t - 0.5), 2.0)
		_box(Vector3(x, h * 0.5, 0), Vector3(span / segs + 0.02, h, 0.05), _mesh_m, i == segs / 2)
		_box(Vector3(x, h - 0.03, 0), Vector3(span / segs + 0.02, 0.07, 0.07), _line, false)

	var marker := Node3D.new()
	marker.name = "CourtSpot"
	marker.position = Vector3(cx, 0, -hl - 1.6)
	marker.add_to_group("activity")
	marker.set_script(load("res://scripts/activity_spot.gd"))
	add_child(marker)
	marker.setup("tennis", "E  Play tennis", "The nets are up, but nobody's here to rally with yet.")


func _line_box(at: Vector2, size: Vector2) -> void:
	_box(Vector3(at.x, 0.022, at.y), Vector3(size.x, 0.012, size.y), _line, false)


func _fence() -> void:
	var w := COURT_GAP + DOUBLES + RUNOFF_SIDE * 2.0
	var d := LEN + RUNOFF_END * 2.0
	var hw := w * 0.5
	var hd := d * 0.5
	# Chain link as a thin dark screen, with posts and a rail.
	for dz in [-hd, hd]:
		_box(Vector3(0, FENCE_H * 0.5, dz), Vector3(w, FENCE_H, 0.08), _mesh_m, true)
		_box(Vector3(0, FENCE_H, dz), Vector3(w, 0.1, 0.14), _post, false)
	for dx in [-hw, hw]:
		# Gate gap in the middle of each long side.
		var seg := (d - 3.0) * 0.5
		for dir in [-1.0, 1.0]:
			_box(Vector3(dx, FENCE_H * 0.5, dir * (1.5 + seg * 0.5)), Vector3(0.08, FENCE_H, seg), _mesh_m, true)
		_box(Vector3(dx, FENCE_H, 0), Vector3(0.14, 0.1, d), _post, false)
	for px in [-hw, hw]:
		for pz in [-hd, -hd * 0.5, 0.0, hd * 0.5, hd]:
			_box(Vector3(px, FENCE_H * 0.5, pz), Vector3(0.14, FENCE_H, 0.14), _post, false)


func _furniture() -> void:
	var hw := (COURT_GAP + DOUBLES + RUNOFF_SIDE * 2.0) * 0.5
	# Benches between the courts.
	for bz in [-4.0, 4.0]:
		_box(Vector3(0, 0.45, bz), Vector3(0.5, 0.1, 2.4), _mat(Color("6b4a2f"), 0.7), true)
		for lx in [-0.18, 0.18]:
			_box(Vector3(lx, 0.22, bz), Vector3(0.1, 0.44, 2.2), _post, false)

	# Floodlights on the corners, lit after dark by the day/night pass.
	for px in [-hw + 1.0, hw - 1.0]:
		for pz in [-10.0, 10.0]:
			_box(Vector3(px, 4.5, pz), Vector3(0.26, 9.0, 0.26), _post, true)
			_box(Vector3(px, 9.2, pz), Vector3(1.4, 0.4, 0.5), _mat(Color("d8dce0"), 0.4), false)
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(px, 9.0, pz)
			lamp.light_color = Color("eaf2ff")
			lamp.light_energy = 2.6
			lamp.omni_range = 26.0
			lamp.shadow_enabled = false
			add_child(lamp)

	var sign := Label3D.new()
	sign.text = "AVALON TENNIS CENTRE"
	sign.position = Vector3(0, 4.3, -(LEN + RUNOFF_END * 2.0) * 0.5 - 0.2)
	sign.font_size = 48
	sign.modulate = Color("f1faee")
	sign.outline_modulate = Color.BLACK
	sign.outline_size = 8
	sign.rotation_degrees.y = 180.0
	add_child(sign)


func _box(centre: Vector3, size: Vector3, material: Material, solid: bool) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = centre
	add_child(mi)
	if not solid:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = centre
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
