"""Jacob.blend + Jacob.glb: BusinessMan rig, stock head, photo face card on the Head bone."""
import os
import bpy
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PHOTO = os.path.join(ROOT, "assets", "image.png")
BODY = os.path.join(ROOT, "assets", "characters", "BusinessMan.glb")
FACE_PNG = os.path.join(ROOT, "assets", "characters", "jacob_face.png")
BLEND = os.path.join(ROOT, "tools", "jacob", "Jacob.blend")
GLB = os.path.join(ROOT, "assets", "characters", "Jacob.glb")
PREVIEW = os.path.join(ROOT, "assets", "characters", "jacob_preview.png")
HEAD_PREVIEW = os.path.join(ROOT, "assets", "characters", "jacob_head_preview.png")

SKIN = (0.82, 0.62, 0.50, 1.0)
HAIR = (0.28, 0.16, 0.09, 1.0)
POLO = (0.08, 0.32, 0.78, 1.0)
PANTS = (0.12, 0.13, 0.16, 1.0)


def wipe():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=True)
    for block in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.images, bpy.data.actions):
        for item in list(block):
            block.remove(item)


def crop_face(src_path, dest_path):
    img = bpy.data.images.load(src_path)
    w, h = img.size
    px = list(img.pixels)
    x0 = int(w * 0.22)
    y0_top = int(h * 0.08)
    cw = int(w * 0.56)
    ch = int(h * 0.62)
    out = bpy.data.images.new("jacob_face", cw, ch, alpha=True)
    dst = [0.0] * (cw * ch * 4)
    for j in range(ch):
        src_y_top = y0_top + (ch - 1 - j)
        src_y = h - 1 - src_y_top
        for i in range(cw):
            si = (src_y * w + (x0 + i)) * 4
            r, g, b = px[si], px[si + 1], px[si + 2]
            blue_lead = b - max(r, g)
            a = 0.0 if (b > 0.26 and blue_lead > 0.05) else 1.0
            di = (j * cw + i) * 4
            dst[di : di + 4] = [r, g, b, a]
    out.pixels = dst
    out.filepath_raw = dest_path
    out.file_format = "PNG"
    out.save()
    return out


def set_color(mat, color, roughness=0.55):
    mat.use_nodes = True
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Alpha"].default_value = 1.0
    mat.blend_method = "OPAQUE"


def parent_keep_world(obj, arm, bone_name):
    mw = obj.matrix_world.copy()
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    bone = arm.pose.bones[bone_name]
    obj.matrix_parent_inverse = (arm.matrix_world @ bone.matrix).inverted()
    obj.matrix_world = mw
    bpy.context.view_layer.update()


def make_face_card(face_img, arm, head):
    mn, mx = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for c in head.bound_box:
        w = head.matrix_world @ Vector(c)
        mn.x, mn.y, mn.z = min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)
        mx.x, mx.y, mx.z = max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)
    # Cover the open face cavity. Front of this rig is -Y.
    width = (mx.x - mn.x) * 0.64
    height = (mx.z - mn.z) * 0.52
    cx = (mn.x + mx.x) * 0.5
    cz = mn.z + (mx.z - mn.z) * 0.54
    cy = mn.y - 0.035

    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(cx, cy, cz))
    card = bpy.context.active_object
    card.name = "JacobFace"
    # Default plane faces +Z. -X rot aims it at -Y (this rig's front).
    card.rotation_euler = (-1.5708, 0.0, 0.0)
    card.scale = (width, height, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    card.location = (cx, cy, cz)
    # -X rotation puts V=1 at world -Z. Flip so hair is up.
    uv = card.data.uv_layers.active
    for loop in uv.data:
        loop.uv.y = 1.0 - loop.uv.y

    mat = bpy.data.materials.new("JacobFace")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = face_img
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = 0.45
    mat.blend_method = "CLIP"
    mat.use_backface_culling = False
    card.data.materials.append(mat)

    parent_keep_world(card, arm, "Head")
    print("face card", "size", width, height, "pos", (cx, cy, cz))
    return card


def tint_meshes():
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        n = o.name.lower()
        if n == "jacobface":
            continue
        for mat in o.data.materials:
            if mat is None:
                continue
            mn = mat.name.lower()
            if "hair" in mn or "brow" in mn:
                set_color(mat, HAIR, 0.7)
            elif "eye" in mn:
                set_color(mat, SKIN, 0.5)
            elif "skin" in mn:
                set_color(mat, SKIN, 0.5)
            elif "leg" in n or "feet" in n:
                set_color(mat, PANTS, 0.62)
            else:
                set_color(mat, POLO, 0.58)


def nuke_junk():
    keep = {"Suit_Head", "Suit_Body", "Suit_Legs", "Suit_Feet", "CharacterArmature", "JacobFace"}
    for o in list(bpy.data.objects):
        if o.name not in keep:
            bpy.data.objects.remove(o, do_unlink=True)


def render_previews():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 768
    scene.render.image_settings.file_format = "PNG"
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam
    light_data = bpy.data.lights.new("PreviewKey", "SUN")
    light_data.energy = 4.0
    light = bpy.data.objects.new("PreviewKey", light_data)
    bpy.context.scene.collection.objects.link(light)
    light.rotation_euler = (0.85, 0.2, 0.35)

    cam.location = (0.0, -3.5, 0.95)
    cam.rotation_euler = (1.48, 0.0, 0.0)
    cam.data.lens = 50
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)

    cam.location = (0.0, -1.05, 1.62)
    cam.rotation_euler = (1.57, 0.0, 0.0)
    cam.data.lens = 85
    scene.render.filepath = HEAD_PREVIEW
    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW)


def main():
    wipe()
    bpy.ops.import_scene.gltf(filepath=BODY)
    nuke_junk()
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    head = bpy.data.objects["Suit_Head"]
    face_img = crop_face(PHOTO, FACE_PNG)
    make_face_card(face_img, arm, head)
    tint_meshes()
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("saved", BLEND)
    bpy.ops.export_scene.gltf(
        filepath=GLB,
        export_format="GLB",
        export_animations=True,
        export_skins=True,
        export_apply=False,
    )
    print("exported", GLB)
    render_previews()
    print("meshes", [o.name for o in bpy.data.objects if o.type == "MESH"])


main()
