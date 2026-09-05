extends StaticBody3D

# A lamp post you can flatten with the car. Takes a hit, throws sparks, dies,
# and topples. Stays down.

const POLE_H := 6.2

var _lit: bool = false
var _down: bool = false
var _fall: float = 0.0
var _fall_dir: Vector3 = Vector3.FORWARD
var _pivot: Node3D
var _light: OmniLight3D
var _bulb: MeshInstance3D
var _sparks: GPUParticles3D
var _bulb_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("street_lamp")
	add_to_group("smashable")
	_build()
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _down:
		return
	# Topple over about the base, then rest.
	_fall = minf(_fall + delta * 1.9, 1.0)
	var ease := 1.0 - pow(1.0 - _fall, 3.0)
	# Rotate about the fall axis properly. Assigning the axis scaled by the
	# angle to `rotation` treats it as Euler XYZ, which skews any diagonal fall.
	_pivot.basis = Basis(_fall_dir, ease * PI * 0.5)
	if _fall >= 1.0:
		set_physics_process(false)


## Called by whatever ran into it. `from` is the impact direction in world space.
func hit(from: Vector3) -> void:
	if _down:
		return
	_down = true
	set_physics_process(true)
	var flat := Vector3(from.x, 0.0, from.z)
	if flat.length_squared() < 0.001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	# Fall away from the impact: spin about the horizontal axis square to it.
	_fall_dir = Vector3(flat.z, 0.0, -flat.x).normalized()
	set_lit(false)
	if _bulb_mat:
		_bulb_mat.emission_energy_multiplier = 0.0
		_bulb_mat.albedo_color = Color("2b2b28")
	if _sparks:
		_sparks.restart()
		_sparks.emitting = true
	GameState.notice.emit("You flattened a lamp post.")


func set_lit(on: bool) -> void:
	_lit = on and not _down
	if _light:
		_light.visible = _lit
	if _bulb_mat and not _down:
		_bulb_mat.emission_energy_multiplier = 2.4 if _lit else 0.15


func _build() -> void:
	collision_layer = 1
	collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.22
	shape.height = POLE_H
	col.shape = shape
	col.position.y = POLE_H * 0.5
	add_child(col)

	_pivot = Node3D.new()
	add_child(_pivot)

	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.12
	cyl.height = POLE_H
	pole.mesh = cyl
	pole.material_override = _mat(Color("2a2a2a"), 0.4, 0.3)
	pole.position.y = POLE_H * 0.5
	_pivot.add_child(pole)

	var arm := MeshInstance3D.new()
	var abox := BoxMesh.new()
	abox.size = Vector3(1.0, 0.1, 0.1)
	arm.mesh = abox
	arm.material_override = _mat(Color("2a2a2a"), 0.4, 0.3)
	arm.position = Vector3(-0.5, POLE_H - 0.1, 0)
	_pivot.add_child(arm)

	_bulb_mat = _mat(Color("fff1c2"), 0.3)
	_bulb_mat.emission_enabled = true
	_bulb_mat.emission = Color("fff1c2")
	_bulb_mat.emission_energy_multiplier = 0.15
	_bulb = MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.24
	bulb.height = 0.34
	_bulb.mesh = bulb
	_bulb.material_override = _bulb_mat
	_bulb.position = Vector3(-0.95, POLE_H - 0.24, 0)
	_pivot.add_child(_bulb)

	_light = OmniLight3D.new()
	_light.position = Vector3(-0.95, POLE_H - 0.4, 0)
	_light.light_color = Color("ffe6b0")
	_light.light_energy = 2.4
	_light.omni_range = 16.0
	_light.shadow_enabled = false
	_light.visible = false
	_pivot.add_child(_light)

	_sparks = GPUParticles3D.new()
	_sparks.amount = 40
	_sparks.lifetime = 0.7
	_sparks.one_shot = true
	_sparks.explosiveness = 0.85
	_sparks.emitting = false
	_sparks.local_coords = false
	_sparks.position = Vector3(-0.95, POLE_H - 0.3, 0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 55.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.3
	pm.scale_max = 0.8
	pm.color = Color(1.0, 0.92, 0.5, 1.0)
	_sparks.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.billboard_keep_scale = true
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(1.0, 0.92, 0.5, 1.0)
	quad.material = qm
	_sparks.draw_pass_1 = quad
	_pivot.add_child(_sparks)


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m
