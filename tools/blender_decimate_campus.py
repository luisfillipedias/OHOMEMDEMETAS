# ========================================================
# BLENDER SCRIPT - Decimate campus1 models
# Run this in Blender's Python Console (Scripting tab)
# Make sure you have all campus1 GLBs accessible
# ========================================================
import bpy, os

campus_dir = r"C:\Users\Usuário\Pictures\MEUJOGOTERROR\!#%JOGOPSX\assets\models\campus1"
files_to_process = [
    ("catraca.glb",   0.02),   # Target: 2% of original verts (critical: 1M -> ~20k)
    ("chao.glb",      0.04),   # 4% of original (flat ground: 1M -> ~40k)
    ("predio_adm.glb",0.08),   # 8% of original (building: 1M -> ~80k)
    ("bosquinho.glb", 0.12),   # 12% of original (foliage: 1.3M -> ~160k)
    ("hall.glb",      0.15),   # 15% (350k -> ~52k)
    ("galpao.glb",    0.20),   # 20% (272k -> ~54k)
]

for fname, ratio in files_to_process:
    filepath = os.path.join(campus_dir, fname)
    if not os.path.exists(filepath):
        print(f"SKIP: {fname} not found")
        continue
    
    # Clear scene
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    
    # Import GLB
    print(f"\nImporting {fname}...")
    bpy.ops.import_scene.gltf(filepath=filepath)
    
    # Count original verts
    total_before = sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type == "MESH")
    print(f"  Vertices before: {total_before:,}")
    
    # Remove hidden/interior geometry and apply decimate to all mesh objects
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        
        # Remove interior geometry using limited dissolve
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=0.001)  # Weld duplicate verts
        bpy.ops.object.mode_set(mode="OBJECT")
        
        # Add decimate modifier
        mod = obj.modifiers.new(name="Decimate_Opt", type="DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        bpy.ops.object.modifier_apply(modifier="Decimate_Opt")
        
        obj.select_set(False)
    
    # Count after
    total_after = sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type == "MESH")
    reduction = 100.0 * (1.0 - total_after / max(total_before, 1))
    print(f"  Vertices after: {total_after:,} (reduction: {reduction:.0f}%)")
    
    # Export back as GLB
    out_path = filepath.replace(".glb", "_optimized.glb")
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_apply=True,
    )
    print(f"  Saved: {os.path.basename(out_path)}")

print("\n=== ALL MODELS PROCESSED ===")
print("Review the _optimized.glb files in Blender before replacing originals.")
print("When satisfied, rename each _optimized.glb to replace the original .glb")
