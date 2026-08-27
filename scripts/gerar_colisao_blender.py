import bpy
import os

# ==============================================================================
# SCRIPT DE GERAÇÃO DE MALHA DE COLISÃO ULTRA-LEVE PARA O BLENDER
# ==============================================================================

INPUT_FILE = r"E:\Usuario\Imagens\MEUJOGOTERROR\!#%JOGOPSX\assets\models\campus1\chao.glb"
OUTPUT_FILE = r"E:\Usuario\Imagens\MEUJOGOTERROR\!#%JOGOPSX\assets\models\campus1\chao_colisao.glb"
DECIMATE_RATIO = 0.03

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    
    print(f"[1/4] Importando: {INPUT_FILE}...")
    if not os.path.exists(INPUT_FILE):
        print(f"ERRO: Arquivo {INPUT_FILE} nao encontrado!")
        return

    bpy.ops.import_scene.gltf(filepath=INPUT_FILE)
    
    print(f"[2/4] Aplicando Decimate (Ratio: {DECIMATE_RATIO})...")
    total_triangles_before = 0
    total_triangles_after = 0
    
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            total_triangles_before += len(obj.data.polygons)
            
            mod = obj.modifiers.new(name="Decimate_Collision", type='DECIMATE')
            mod.ratio = DECIMATE_RATIO
            bpy.ops.object.modifier_apply(modifier=mod.name)
            obj.data.materials.clear()
            
            total_triangles_after += len(obj.data.polygons)
            obj.select_set(False)

    print(f"[3/4] Poligonos reduzidos de {total_triangles_before} para {total_triangles_after}!")
    
    print(f"[4/4] Exportando para: {OUTPUT_FILE}...")
    bpy.ops.export_scene.gltf(
        filepath=OUTPUT_FILE,
        export_format='GLB',
        export_materials='NONE',
        export_colors=False,
        export_cameras=False,
        export_lights=False
    )
    
    print("\n[OK] CONCLUIDO COM SUCESSO!")
    print(f"Arquivo gerado: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
