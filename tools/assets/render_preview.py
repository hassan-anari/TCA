"""Offline Cycles preview of a generated GLB (for asset review only, not used at runtime).

    blender -b --factory-startup -P tools/assets/render_preview.py -- in.glb out.png [distance] [elev_deg] [azim_deg]
"""
import bpy
import math
import sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
dist = float(argv[2]) if len(argv) > 2 else 4.2
elev = math.radians(float(argv[3]) if len(argv) > 3 else 18)
azim = math.radians(float(argv[4]) if len(argv) > 4 else -90)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scn = bpy.context.scene
cam_data = bpy.data.cameras.new("cam")
cam_data.lens = 50
cam = bpy.data.objects.new("cam", cam_data)
scn.collection.objects.link(cam)
cam.location = Vector((math.cos(azim) * math.cos(elev), math.sin(azim) * math.cos(elev), math.sin(elev))) * dist
cam.rotation_euler = (-cam.location).to_track_quat("-Z", "Y").to_euler()
scn.camera = cam
sun = bpy.data.lights.new("sun", "SUN")
sun.energy = 2.2
sun.color = (1.0, 0.86, 0.74)
so = bpy.data.objects.new("sun", sun)
so.rotation_euler = (math.radians(50), math.radians(-30), math.radians(35))
scn.collection.objects.link(so)
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.012, 0.035, 0.04, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.6
scn.world = world
scn.render.engine = "CYCLES"
scn.cycles.samples = 24
scn.cycles.use_denoising = False
scn.render.resolution_x = 520
scn.render.resolution_y = 520
scn.view_settings.view_transform = "AgX" if "AgX" in [v.identifier for v in scn.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
scn.render.filepath = dst
bpy.ops.render.render(write_still=True)
