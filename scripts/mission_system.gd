extends Node3D

const MISSIONS := [
	{
		"id": "north_point",
		"label": "WORK — CLOCK IN",
		"hint": "Walk into the office and clock in (E).",
		"pos": Vector3(46, 0, 0),
		"color": Color("ffb703"),
		"kind": "sales",
	},
	{
		"id": "avalon",
		"label": "AVALON — TENNIS",
		"hint": "Get to Avalon and hold still for a set.",
		"pos": Vector3(128, 0, 62),
		"color": Color("90be6d"),
		"kind": "hold",
		"hold": 4.0,
		"reward": 60,
	},
	{
		"id": "apartment",
		"label": "APARTMENT — SIEGE",
		"hint": "Head home and run a Siege session.",
		"pos": Vector3(48, 0, -172),
		"color": Color("219ebc"),
		"kind": "hold",
		"hold": 6.0,
		"reward": 0,
	},
	{
		"id": "qt",
		"label": "QT — GAS",
		"hint": "Stop at QT. $40 fills the tank (E).",
		"pos": Vector3(-42, 0, 148),
		"color": Color.WHITE,
		"kind": "gas",
	},
]

var _hold_id: String = ""
var _hold_time: float = 0.0
var _areas: Dictionary = {}


func _ready() -> void:
	add_to_group("mission_system")
	for spec in MISSIONS:
		_spawn(spec)
	_refresh_objective()
	GameState.missions_changed.connect(_refresh_objective)


func _physics_process(delta: float) -> void:
	if GameState.is_paused:
		return
	var actor := _actor()
	if actor == null:
		return
	var speed := 0.0
	if actor is RigidBody3D:
		speed = (actor as RigidBody3D).linear_velocity.length()
	elif actor is CharacterBody3D:
		speed = (actor as CharacterBody3D).velocity.length()

	for spec in MISSIONS:
		var id: String = spec.id
		if GameState.is_mission_done(id):
			continue
		var area: Area3D = _areas.get(id)
		if area == null:
			continue
		var inside := actor.global_position.distance_to(area.global_position) < 7.0
		if spec.kind == "hold":
			if inside and speed < 1.4:
				if _hold_id != id:
					_hold_id = id
					_hold_time = 0.0
					GameState.notice.emit("Hold still…")
				_hold_time += delta
				var need := float(spec.hold)
				if _hold_time >= need:
					_complete_hold(spec)
			elif _hold_id == id:
				_hold_id = ""
				_hold_time = 0.0


func try_interact() -> bool:
	var actor := _actor()
	if actor == null:
		return false
	for spec in MISSIONS:
		if spec.kind not in ["sales", "gas"]:
			continue
		if GameState.is_mission_done(spec.id):
			continue
		var area: Area3D = _areas.get(spec.id)
		if area and actor.global_position.distance_to(area.global_position) < 7.0:
			_complete_interact(spec)
			return true
	return false


func _complete_hold(spec: Dictionary) -> void:
	_hold_id = ""
	_hold_time = 0.0
	if spec.id == "apartment":
		GameState.notice.emit("Siege session done. Back to the grind.")
	else:
		GameState.add_money(int(spec.reward))
		GameState.notice.emit("Set complete. +$%d" % int(spec.reward))
	GameState.mark_mission(spec.id)
	_hide_marker(spec.id)


func _complete_interact(spec: Dictionary) -> void:
	if spec.kind == "gas":
		if not GameState.spend_money(40):
			GameState.notice.emit("Need $40 for gas.")
			return
		GameState.fuel = 100.0
		GameState.notice.emit("Tank full.")
	else:
		GameState.add_money(180)
		GameState.notice.emit("Clocked in. Closed a deal. +$180")
	GameState.mark_mission(spec.id)
	_hide_marker(spec.id)


func _hide_marker(id: String) -> void:
	var area: Area3D = _areas.get(id)
	if area:
		area.visible = false
		area.monitoring = false


func _refresh_objective() -> void:
	for spec in MISSIONS:
		if not GameState.is_mission_done(spec.id):
			GameState.objective = String(spec.hint)
			return
	GameState.objective = "All jobs done. Drive around or start a new game."


func _actor() -> Node3D:
	if GameState.in_car:
		return get_tree().get_first_node_in_group("camry") as Node3D
	return get_tree().get_first_node_in_group("player") as Node3D


func _spawn(spec: Dictionary) -> void:
	var area := Area3D.new()
	area.name = spec.id
	area.position = spec.pos
	area.collision_layer = 0
	area.collision_mask = 0
	area.add_to_group("mission_marker")
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 7.2
	pillar.mesh = cyl
	pillar.position.y = 3.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = spec.color
	mat.emission_enabled = true
	mat.emission = spec.color
	mat.emission_energy_multiplier = 2.2
	pillar.material_override = mat
	area.add_child(pillar)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.6
	torus.outer_radius = 2.1
	ring.mesh = torus
	ring.position.y = 0.08
	ring.material_override = mat
	area.add_child(ring)
	var label := Label3D.new()
	label.text = spec.label
	label.position.y = 8.2
	label.font_size = 64
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	area.add_child(label)
	if GameState.is_mission_done(spec.id):
		area.visible = false
	add_child(area)
	_areas[spec.id] = area
