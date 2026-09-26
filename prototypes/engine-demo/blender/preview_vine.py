# PROTOTYPE — renders a quick preview of one vine glb for visual QC.
import bpy, sys, math
a = sys.argv[sys.argv.index("--") + 1:]
src, out = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for m in bpy.data.materials:
    if m.use_nodes:
        b = m.node_tree.nodes.get("Principled BSDF")
        vc = [n for n in m.node_tree.nodes if n.type == "VERTEX_COLOR"]
        if b and m.name.startswith(("vine_leaf", "vine_berry")):
            n = m.node_tree.nodes.new("ShaderNodeVertexColor"); n.layer_name = ""
            m.node_tree.links.new(n.outputs["Color"], b.inputs["Base Color"])
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 900, 1100
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.location = (2.2, -2.2, 1.3); cam.rotation_euler = (math.radians(88), 0, math.radians(45))
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 4; sun.rotation_euler = (math.radians(55), 0, math.radians(30))
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.6, 0.8, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
