# ========================================================
# PLAN B - TESTE SEGURO DE DECIMAÇÃO PLANAR: PREDIO_ADM.GLB
# Executar este script no Blender (Aba Scripting -> Run Script)
# ========================================================
import bpy, os

campus_dir = r"C:\Users\Usuário\Pictures\MEUJOGOTERROR\!#%JOGOPSX\assets\models\campus1"
model_name = "predio_adm.glb"
output_name = "predio_adm_teste_preview.glb"

input_path = os.path.join(campus_dir, model_name)
output_path = os.path.join(campus_dir, output_name)

print("="*60)
print(f"Iniciando Teste Planar Seguro em: {model_name}")
print("="*60)

# 1. Limpa a cena atual do Blender
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()

# 2. Importa o modelo original
print(f"Importando {input_path}...")
bpy.ops.import_scene.gltf(filepath=input_path)

# 3. Contagem original de vértices e faces
total_verts_before = sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type == "MESH")
total_faces_before = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
print(f"  [ORIGINAL] Vértices: {total_verts_before:,} | Faces: {total_faces_before:,}")

# 4. Aplica DECIMAÇÃO PLANAR segura (preservando silhuetas, UVs, materiais e normais)
for obj in bpy.context.scene.objects:
    if obj.type != "MESH":
        continue
    
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    
    # Adiciona o modificador PLANAR
    mod = obj.modifiers.new(name="Planar_Opt", type="DECIMATE")
    mod.decimate_type = "DISSOLVE" # Modo Planar
    mod.angle_limit = 0.035 # ~2.0 graus de tolerância coplanar
    mod.delimit = {'NORMAL', 'MATERIAL', 'UV'} # Protege texturas, costuras UV e normais
    
    # Aplica o modificador
    bpy.ops.object.modifier_apply(modifier="Planar_Opt")
    obj.select_set(False)

# 5. Contagem final
total_verts_after = sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type == "MESH")
total_faces_after = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
red_verts = 100.0 * (1.0 - total_verts_after / max(total_verts_before, 1))

print(f"  [OTIMIZADO] Vértices: {total_verts_after:,} | Faces: {total_faces_after:,}")
print(f"  [REDUÇÃO] -{red_verts:.1f}% de vértices eliminados com segurança!")

# 6. Exporta como arquivo de TESTE (o original predio_adm.glb continua intacto!)
print(f"\nExportando arquivo de prévia para: {output_path}")
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
