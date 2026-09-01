class_name JacobLook
extends Node3D

const CIVILIAN := preload("res://assets/characters/BusinessMan.glb")
const SOLDIER := preload("res://assets/characters/Soldier.glb")
const FACE_TEX := preload("res://assets/characters/jacob_face.png")

## Royal blue, matched to the polo in the reference photo.
@export var team_tint := Color("1c6fc9")
@export var show_face := true
## Metres from the head bone: +Y up the skull, +Z out the front of the face.
## Nudge in the inspector if the photo lands high, low, or on the back of the head.
@export var face_offset := Vector3(0.0, 0.06, 0.15)
@export var face_size := Vector2(0.26, 0.33)
## Prints the measured head-bone position once, to dial face_offset in.
@export var face_debug := false

var _actor: Node3D
var _ap: AnimationPlayer
var _current := ""
var _clip_map: Dictionary = {}
var _face: MeshInstance3D
var _arm_bone: int = -1
var _arm_rest: Transform3D
var _skel: Skeleton3D
var _head_bone: int = -1


func _ready() -> void:
	var scene: PackedScene = CIVILIAN if ResourceLoader.exists("res://assets/characters/BusinessMan.glb") else SOLDIER
	_actor = scene.instantiate() as Node3D
	_actor.name = "Actor"
	add_child(_actor)
	var visor := _actor.find_child("vanguard_visor", true, false) as MeshInstance3D
	if visor:
		visor.visible = false
	_apply_tint_to_all()
	_ap = _actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap:
		_ap.playback_default_blend_time = 0.22
		_build_clip_map()
		for base in ["Idle", "Walk", "Run"]:
			var actual: String = str(_clip_map.get(base, ""))
			if actual != "" and _ap.has_animation(actual):
				_ap.get_animation(actual).loop_mode = Animation.LOOP_LINEAR
		_play("Idle")
	call_deferred("_fit_and_face")
	call_deferred("_attach_face")


func animate(vel: Vector3, on_floor: bool, sprinting: bool, moving: bool, delta: float) -> void:
	var planar := Vector2(vel.x, vel.z).length()
	if not on_floor and vel.y > 1.2:
		_play("Idle")
		if _ap:
			var target_air := 0.4
			_ap.speed_scale = lerpf(_ap.speed_scale, target_air, 1.0 - exp(-10.0 * delta))
		return
	# Hysteresis: avoid flicker at start/stop threshold
	var is_moving := moving or planar > 0.35
	if not is_moving and planar < 0.12:
		is_moving = false
	if is_moving:
		if sprinting:
			_play("Run")
			if _ap:
				# foot-speed matched: run cycle ~6.8 m/s at scale 1.0
				var target := clampf(planar / 6.8, 0.35, 1.35)
				_ap.speed_scale = lerpf(_ap.speed_scale, target, 1.0 - exp(-10.0 * delta))
		else:
			_play("Walk")
			if _ap:
				# foot-speed matched: walk cycle ~4.6 m/s at scale 1.0, low-speed scales down to avoid sliding
				var target := clampf(planar / 4.6, 0.32, 1.35)
				_ap.speed_scale = lerpf(_ap.speed_scale, target, 1.0 - exp(-10.0 * delta))
	else:
		_play("Idle")
		if _ap:
			_ap.speed_scale = lerpf(_ap.speed_scale, 1.0, 1.0 - exp(-8.0 * delta))


func _process(_delta: float) -> void:
	_update_face()


## Raise and swing the right arm. `lift` is radians up from rest, `swing` is
## the side-to-side wobble. Zero for both puts the arm back on its rest pose.
func wave_arm(lift: float, swing: float) -> void:
	if _skel == null or _arm_bone < 0:
		return
	if lift <= 0.001 and absf(swing) <= 0.001:
		_skel.set_bone_pose_rotation(_arm_bone, _arm_rest.basis.get_rotation_quaternion())
		return
	var turn := Quaternion(Vector3.FORWARD, -lift) * Quaternion(Vector3.RIGHT, swing)
	_skel.set_bone_pose_rotation(_arm_bone, _arm_rest.basis.get_rotation_quaternion() * turn)


func set_clothed(_has: bool) -> void:
	# BusinessMan visuals are clothing-aware; kept for player.gd compatibility.
	# Tint already applied via apply_team; no-op but must exist for headless.
	return

func apply_team(color: Color) -> void:
	team_tint = color
	if _actor == null:
		return
	_apply_tint_to_all()


func _play(clip: String) -> void:
	if _ap == null:
		return
	var actual: String = _clip_map.get(clip, clip)
	if actual == "":
		actual = clip
	if not _ap.has_animation(actual):
		if _ap.has_animation(clip):
			actual = clip
		else:
			for _n: String in _ap.get_animation_list():
				var s: String = String(_n)
				if s.ends_with("|" + clip) or s.ends_with(clip):
					actual = s
					break
			if not _ap.has_animation(actual):
				return
	if actual == _current and _ap.is_playing():
		return
	_current = actual
	_ap.play(actual)


func _fit_and_face() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_actor.scale = Vector3.ONE
	_actor.position = Vector3.ZERO
	_actor.rotation = Vector3.ZERO
	var combined_aabb: AABB = _combined_aabb(_actor)
	if combined_aabb.size == Vector3.ZERO:
		return
	if combined_aabb.size.y < combined_aabb.size.z * 0.55:
		_actor.rotate_x(-PI * 0.5)
		await get_tree().process_frame
		combined_aabb = _combined_aabb(_actor)
	var height := maxf(combined_aabb.size.y, 0.05)
	var is_businessman := _actor.find_child("Suit_Body", true, false) != null
	var target_h := 1.78
	var s: float = 1.0
	if is_businessman:
		s = clampf(target_h / height, 0.5, 1.5)
	else:
		s = clampf(target_h / height, 0.005, 2.5)
	_actor.scale *= s
	combined_aabb = _combined_aabb(_actor)
	_actor.position.y -= combined_aabb.position.y

func _combined_aabb(root: Node) -> AABB:
	var first := true
	var aabb := AABB()
	for mi in _all_meshes(root):
		var m := mi as MeshInstance3D
		var ga := m.global_transform * m.get_aabb()
		if first:
			aabb = ga
			first = false
		else:
			aabb = aabb.merge(ga)
	return aabb

func _all_meshes(node: Node) -> Array:
	var out: Array = []
	_collect_meshes(node, out)
	return out

func _attach_face() -> void:
	if not show_face or _face != null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_skel = _find_skeleton(_actor)
	if _skel:
		_head_bone = _skel.find_bone("Head")
		for candidate in ["UpperArm.R", "RightArm", "Arm.R", "Shoulder.R", "UpperArmR"]:
			_arm_bone = _skel.find_bone(candidate)
			if _arm_bone >= 0:
				_arm_rest = _skel.get_bone_pose(_arm_bone)
				break

	var quad := QuadMesh.new()
	quad.size = face_size
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = FACE_TEX
	# ALPHA_SCISSOR, not ALPHA: alpha-blended materials skip the depth write and
	# get sorted per-object, which is what buried the face inside the skull.
	# Scissor renders it in the opaque pass so it occludes the head properly.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.85
	quad.material = mat

	# Parented to JacobLook rather than the head bone: this node carries the
	# character yaw at unit scale, so +Z is reliably "out the front of the face"
	# without depending on the rig's bone-space axes.
	_face = MeshInstance3D.new()
	_face.name = "Face"
	_face.mesh = quad
	_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_face)
	_update_face()
	if face_debug:
		var bone := "none" if _head_bone < 0 else str(_head_bone)
		print("[jacob_look] head bone=%s local=%s face=%s actor_scale=%s"
			% [bone, _head_pos(), _face.position, _actor.scale])


func _head_pos() -> Vector3:
	if _skel and _head_bone >= 0:
		return to_local((_skel.global_transform * _skel.get_bone_global_pose(_head_bone)).origin)
	return Vector3(0.0, 1.62, 0.0)


func _update_face() -> void:
	if _face == null:
		return
	_face.position = _head_pos() + face_offset
	_face.rotation = Vector3.ZERO


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for c in root.get_children():
		var found := _find_skeleton(c)
		if found:
			return found
	return null

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

func _apply_tint_to_all() -> void:
	var vm := _actor.find_child("vanguard_Mesh", true, false) as MeshInstance3D
	if vm:
		_tint_mesh(vm)
	for name in ["Suit_Body", "Suit_Legs", "Suit_Head"]:
		var m := _actor.find_child(name, true, false) as MeshInstance3D
		if m:
			if name == "Suit_Body":
				_tint_mesh(m)
	if _actor.find_child("Suit_Body", true, false) == null:
		var first := _find_primary_mesh()
		if first:
			_tint_mesh(first)

func _find_primary_mesh() -> MeshInstance3D:
	for n in ["Suit_Body", "vanguard_Mesh", "Suit_Legs", "Body"]:
		var m := _actor.find_child(n, true, false) as MeshInstance3D
		if m:
			return m
	var meshes: Array = []
	_collect_meshes(_actor, meshes)
	if meshes.size() > 0:
		return meshes[0] as MeshInstance3D
	return null

func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)

func _build_clip_map() -> void:
	if _ap == null:
		return
	var list: PackedStringArray = _ap.get_animation_list()
	for base in ["Idle", "Walk", "Run"]:
		if base in list:
			_clip_map[base] = base
			continue
		for name in list:
			var s: String = String(name)
			if s.ends_with("|" + base) or s == base or s.ends_with(base):
				_clip_map[base] = s
				break
		if not _clip_map.has(base):
			for name in list:
				var s2: String = String(name)
				if s2.to_lower().contains(base.to_lower()):
					_clip_map[base] = s2
					break
