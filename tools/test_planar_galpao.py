# ========================================================
# PLAN B - TESTE SEGURO DE DECIMAÇÃO PLANAR: GALPAO.GLB
# Executar este script no Blender (Aba Scripting -> Run Script)
# ========================================================
import bpy, os

campus_dir = r"C:\Users\Usuário\Pictures\MEUJOGOTERROR\!#%JOGOPSX\assets\models\campus1"
model_name = "galpao.glb"
output_name = "galpao_teste_preview.glb"

input_path = os.path.join(campus_dir, model_name)
output_path = os.path.join(campus_dir, output_name)

print("="*60)
print(f"Iniciando Teste Planar Seguro em: {model_name}")
print("="*60)

# 1. Garante que está no Object Mode
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

# 2. Limpa todos os objetos da cena de forma 100% à prova de contexto
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)

# 3. Importa o modelo original
print(f"Importando {input_path}...")
bpy.ops.import_scene.gltf(filepath=input_path)

total_verts_before = sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type == "MESH")
total_faces_before = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
print(f"  [ORIGINAL] Vértices: {total_verts_before:,} | Faces: {total_faces_before:,}")

# 4. Aplica DECIMAÇÃO PLANAR segura
for obj in list(bpy.context.scene.objects):
    if obj.type != "MESH":
        continue
    
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    
    mod = obj.modifiers.new(name="Planar_Opt", type="DECIMATE")
    mod.decimate_type = "DISSOLVE"
    mod.angle_limit = 0.035 # ~2 graus
    mod.delimit = {'NORMAL', 'MATERIAL', 'UV'}
    
    try:
        with bpy.context.temp_override(active_object=obj, object=obj):
            bpy.ops.object.modifier_apply(modifier="Planar_Opt")
    except Exception:
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

print("\n" + "="*60)
print("TESTE CONCLUÍDO COM SUCESSO!")
print(f"Arquivo gerado: {output_name}")
print("Abra o arquivo gerado no Blender para inspecionar o visual!")
print("="*60)
