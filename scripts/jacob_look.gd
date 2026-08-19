class_name JacobLook
extends Node3D

const BODY := preload("res://assets/characters/BusinessMan.glb")
const FACE := preload("res://assets/characters/jacob_face.png")

@export var team_tint := Color(0.18, 0.38, 0.78)

var _actor: Node3D
var _ap: AnimationPlayer
var _current := ""
var _clip_map: Dictionary = {}


func _ready() -> void:
	_actor = BODY.instantiate() as Node3D
	_actor.name = "Actor"
	add_child(_actor)
	_apply_tint_to_all()
	_ap = _actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap:
		_ap.playback_default_blend_time = 0.15
		_build_clip_map()
		for base in ["Idle", "Walk", "Run"]:
			var actual: String = str(_clip_map.get(base, ""))
			if actual != "" and _ap.has_animation(actual):
				_ap.get_animation(actual).loop_mode = Animation.LOOP_LINEAR
		_play("Idle")
	call_deferred("_finish_setup")


func animate(vel: Vector3, on_floor: bool, sprinting: bool, moving: bool, _delta: float) -> void:
	var planar := Vector2(vel.x, vel.z).length()
	if not on_floor and vel.y > 1.2:
		_play("Idle")
		if _ap:
			_ap.speed_scale = 0.4
		return
	if moving or planar > 0.55:
		if sprinting:
			_play("Run")
			if _ap:
				_ap.speed_scale = clampf(planar / 7.8, 0.85, 1.2)
		else:
			_play("Walk")
			if _ap:
				_ap.speed_scale = clampf(planar / 5.0, 0.85, 1.2)
	else:
		_play("Idle")
		if _ap:
			_ap.speed_scale = 1.0


func apply_team(color: Color) -> void:
	team_tint = color
	if _actor:
		_apply_tint_to_all()


func _play(clip: String) -> void:
	if _ap == null:
		return
	var actual: String = str(_clip_map.get(clip, clip))
	if not _ap.has_animation(actual):
		for n in _ap.get_animation_list():
			if String(n).ends_with("|" + clip) or String(n).ends_with(clip):
				actual = n
				break
	if not _ap.has_animation(actual):
		return
	if actual == _current and _ap.is_playing():
		return
	_current = actual
	_ap.play(actual)


func _finish_setup() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_plant_feet()
	_attach_face()


func _plant_feet() -> void:
	var aabb := _body_aabb()
	if aabb.size.y < 0.01:
		return
	# BusinessMan already stands on y=0. Only correct a bad import.
	if absf(aabb.position.y) > 0.05:
		_actor.position.y -= aabb.position.y


func _body_aabb() -> AABB:
	var aabb := AABB()
	var started := false
	for node in _actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null or mesh.name == "JacobFace":
			continue
		var piece := mesh.global_transform * mesh.get_aabb()
		if started:
			aabb = aabb.merge(piece)
		else:
			aabb = piece
			started = true
	return aabb


func _attach_face() -> void:
	var head := _actor.find_child("Suit_Head", true, false) as MeshInstance3D
	if head == null:
		return
	var world_aabb := head.global_transform * head.get_aabb()
	var center := world_aabb.get_center()
	var world_pos := Vector3(center.x, center.y + world_aabb.size.y * 0.04, world_aabb.position.z - 0.012)

	var quad := MeshInstance3D.new()
	quad.name = "JacobFace"
	var qm := QuadMesh.new()
	qm.size = Vector2(world_aabb.size.x * 0.64, world_aabb.size.y * 0.54)
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = FACE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.4
	mat.roughness = 0.48
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material_override = mat

	var attach := _actor.find_child("Head", true, false) as BoneAttachment3D
	var parent_node: Node3D = attach if attach else head
	parent_node.add_child(quad)
	var gs := parent_node.global_transform.basis.get_scale()
	var inv := 1.0 / maxf(absf(gs.x), 0.001)
	quad.scale = Vector3(inv, inv, inv)
	quad.global_position = world_pos
	# QuadMesh faces +Z. Point +Z toward the character's front (-Z).
	quad.look_at(quad.global_position + Vector3(0.0, 0.0, 1.0), Vector3.UP)


func _apply_tint_to_all() -> void:
	if _actor == null:
		return
	var m := _actor.find_child("Suit_Body", true, false) as MeshInstance3D
	if m:
		_tint_mesh(m)


func _tint_mesh(mesh: MeshInstance3D) -> void:
	var src := mesh.get_active_material(0)
	if src == null:
		return
	var mat := src.duplicate() as Material
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		bm.albedo_color = team_tint
		bm.roughness = 0.7
	mesh.material_override = mat


func _build_clip_map() -> void:
	if _ap == null:
		return
	var list := _ap.get_animation_list()
	for base in ["Idle", "Walk", "Run"]:
		if base in list:
			_clip_map[base] = base
			continue
		for name in list:
			var s := String(name)
			if s.ends_with("|" + base) or s == base:
				_clip_map[base] = s
				break
