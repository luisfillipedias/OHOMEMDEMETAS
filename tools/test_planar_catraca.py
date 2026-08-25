# ========================================================
# PLAN B - TESTE SEGURO DE DECIMAÇÃO PLANAR: CATRACA.GLB
# Executar este script no Blender (Aba Scripting -> Run Script)
# ========================================================
import bpy, os

campus_dir = r"C:\Users\Usuário\Pictures\MEUJOGOTERROR\!#%JOGOPSX\assets\models\campus1"
model_name = "catraca.glb"
output_name = "catraca_teste_preview.glb"

input_path = os.path.join(campus_dir, model_name)
output_path = os.path.join(campus_dir, output_name)

print("="*60)
print(f"Iniciando Teste Planar Seguro em: {model_name}")
print("="*60)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()

print(f"Importando {input_path}...")
bpy.ops.import_scene.gltf(filepath=input_path)

total_verts_before = sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type == "MESH")
total_faces_before = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
print(f"  [ORIGINAL] Vértices: {total_verts_before:,} | Faces: {total_faces_before:,}")

for obj in bpy.context.scene.objects:
    if obj.type != "MESH":
        continue
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    
    mod = obj.modifiers.new(name="Planar_Opt", type="DECIMATE")
    mod.decimate_type = "DISSOLVE"
    mod.angle_limit = 0.035 # ~2 graus
    mod.delimit = {'NORMAL', 'MATERIAL', 'UV'}
    
    bpy.ops.object.modifier_apply(modifier="Planar_Opt")
    obj.select_set(False)

total_verts_after = sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type == "MESH")
total_faces_after = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
red_verts = 100.0 * (1.0 - total_verts_after / max(total_verts_before, 1))

print(f"  [OTIMIZADO] Vértices: {total_verts_after:,} | Faces: {total_faces_after:,}")
print(f"  [REDUÇÃO] -{red_verts:.1f}% de vértices eliminados com segurança!")

print(f"\nExportando para: {output_path}")
bpy.ops.export_scene.gltf(
    filepath=output_path,
    export_format="GLB",
    export_texcoords=True,
    export_normals=True,
    export_materials="EXPORT",
    export_apply=True,
)
print("TESTE CONCLUÍDO COM SUCESSO!")
