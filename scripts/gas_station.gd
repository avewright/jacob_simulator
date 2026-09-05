extends Node3D

# QT. Canopy over two pump islands, shop behind, pylon sign at the kerb.
# Local space: origin at the centre of the forecourt on the ground; the road
# is toward -Z, so you pull in from there.

const FILL_COST := 40
const CANOPY_Y := 5.2

var _concrete: StandardMaterial3D
var _red: StandardMaterial3D
var _white: StandardMaterial3D
var _dark: StandardMaterial3D
var _glass: StandardMaterial3D


func _ready() -> void:
	add_to_group("gas_station")
	_make_mats()
	_forecourt()
	_canopy()
	_islands()
	_shop()
	_pylon()


func _make_mats() -> void:
	_concrete = _mat(Color("b9b7ae"), 0.92)
	_red = _mat(Color("c8102e"), 0.5)
	_white = _mat(Color("f4f4f0"), 0.6)
	_dark = _mat(Color("23272b"), 0.5, 0.2)
	_glass = _mat(Color(0.55, 0.72, 0.82, 0.45), 0.06, 0.2)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _forecourt() -> void:
	_box(Vector3(0, 0.01, 0), Vector3(30.0, 0.02, 22.0), _concrete, false)
	# Lane arrows in from the road.
	for lx in [-5.0, 5.0]:
		for i in 3:
			_box(Vector3(lx, 0.022, -9.0 + i * 2.2), Vector3(0.16, 0.01, 1.2), _white, false)


func _canopy() -> void:
	_box(Vector3(0, CANOPY_Y, -1.0), Vector3(20.0, 0.7, 13.0), _white, true)
	_box(Vector3(0, CANOPY_Y - 0.45, -1.0), Vector3(20.4, 0.3, 13.4), _red, false)
	for cx in [-8.4, 8.4]:
		for cz in [-6.2, 4.2]:
			_box(Vector3(cx, CANOPY_Y * 0.5, cz), Vector3(0.55, CANOPY_Y, 0.55), _white, true)
	# Underside lighting — reads properly once the day/night pass dims things.
	for i in 3:
		for j in 2:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(-6.0 + i * 6.0, CANOPY_Y - 0.6, -5.0 + j * 8.0)
			lamp.light_color = Color("fbf6e4")
			lamp.light_energy = 2.6
			lamp.omni_range = 12.0
			lamp.shadow_enabled = false
			add_child(lamp)


func _islands() -> void:
	# Typed array, so `side` is a float rather than a Variant — bare literals
	# make the loop variable untyped and `:=` then has nothing to infer from.
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		var ix := side * 5.0
		_box(Vector3(ix, 0.12, -1.0), Vector3(2.2, 0.24, 9.0), _concrete, true)
		for j in 2:
			var pz := -4.0 + j * 6.0
			_pump(Vector3(ix, 0, pz), side)


func _pump(at: Vector3, side: float) -> void:
	# Cabinet, display, nozzle holsters, hose.
	_box(at + Vector3(0, 0.95, 0), Vector3(0.7, 1.6, 1.3), _white, true)
	_box(at + Vector3(0, 1.78, 0), Vector3(0.8, 0.24, 1.4), _red, false)
	for face in [-0.37, 0.37]:
		_box(at + Vector3(face, 1.35, 0), Vector3(0.04, 0.42, 0.72), _dark, false)
		_box(at + Vector3(face * 1.25, 0.95, 0.42), Vector3(0.12, 0.34, 0.14), _dark, false)
		_box(at + Vector3(face * 1.1, 1.16, 0.42), Vector3(0.06, 0.1, 0.06), _dark, false)

	var spot := Node3D.new()
	spot.name = "Pump"
	spot.position = at + Vector3(side * 1.9, 0, 0)
	spot.add_to_group("gas_pump")
	spot.set_script(load("res://scripts/gas_pump.gd"))
	add_child(spot)


func _shop() -> void:
	var bx := 0.0
	var bz := 8.0
	_box(Vector3(bx, 2.1, bz), Vector3(16.0, 4.2, 6.0), _white, true)
	_box(Vector3(bx, 4.45, bz), Vector3(16.6, 0.5, 6.6), _red, false)
	# Glazed shopfront facing the pumps.
	_box(Vector3(bx, 1.8, bz - 3.05), Vector3(13.0, 3.0, 0.14), _glass, false)
	for mx in [-4.4, 0.0, 4.4]:
		_box(Vector3(mx, 1.8, bz - 3.12), Vector3(0.16, 3.0, 0.1), _white, false)
	_box(Vector3(bx, 1.15, bz - 3.2), Vector3(1.8, 2.3, 0.12), _dark, false)

	var name_tag := Label3D.new()
	name_tag.text = "QT"
	name_tag.position = Vector3(bx, 4.45, bz - 3.4)
	name_tag.font_size = 90
	name_tag.modulate = Color("f4f4f0")
	name_tag.outline_modulate = Color("7a0a1c")
	name_tag.outline_size = 10
	add_child(name_tag)


func _pylon() -> void:
	# Price sign out at the kerb, facing the road.
	_box(Vector3(-11.5, 3.2, -10.0), Vector3(0.5, 6.4, 0.5), _dark, true)
	_box(Vector3(-11.5, 6.6, -10.0), Vector3(3.6, 2.4, 0.4), _red, false)
	_box(Vector3(-11.5, 5.9, -10.15), Vector3(3.0, 0.9, 0.14), _dark, false)

	var brand := Label3D.new()
	brand.text = "QT"
	brand.position = Vector3(-11.5, 7.2, -10.25)
	brand.font_size = 64
	brand.modulate = Color("f4f4f0")
	add_child(brand)

	var price := Label3D.new()
	price.text = "REGULAR\n$%d FILL" % FILL_COST
	price.position = Vector3(-11.5, 5.9, -10.3)
	price.font_size = 30
	price.modulate = Color("ffd166")
	add_child(price)


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
