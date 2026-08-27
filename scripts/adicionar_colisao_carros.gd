@tool
extends EditorScript

# ============================================================
# ADICIONAR COLISAO NOS CARROS ESTACIONADOS E FAXINEIRO
# Execute: Editor > File > Run Script (Ctrl+Shift+X)
# ============================================================

# Configuracoes dos carros estacionados (PSX car dimensions in world units)
# Os modelos .blend de carros tem escala propria - a caixa é local ao nó do carro
const CAR_BOX_SIZE = Vector3(1.8, 1.4, 4.2)   # largura, altura, comprimento
const CAR_BOX_OFFSET = Vector3(0, 0.7, 0)      # sobe metade da altura (fundo no Y=0)

# Faxineiro: CapsuleShape (humano em pé, aproximação simples)
const FAX_CAPSULE_HEIGHT = 1.7
const FAX_CAPSULE_RADIUS = 0.35

func _run():
    var scene_root = get_scene()
    if not scene_root:
        printerr("[ColisaoAuto] Nenhuma cena aberta!")
        return
    
    var added = 0
    
    # === 1. CARROS ESTACIONADOS ===
    # Grupos de nomes de carros estáticos (os que são .blend instanciados diretamente)
    var car_parent_names = ["Car2", "Car3", "Car4", "Car5", "Car6", "Car7", "Car22", 
                            "Car23", "Car24", "Car32", "Car42", "Car52", "Car62", "Car82",
                            "Car12", "Suspicious Car", "Suspicious Car2"]
    
    for node in _get_all_nodes(scene_root):
        # Identificar nós de carros estáticos (Node3D sem script de movimento)
        if node.name in car_parent_names and node is Node3D:
            # Verificar se já tem colisão
            if _has_collision(node):
                continue
            
            # Criar StaticBody3D com BoxShape3D
            var sb = StaticBody3D.new()
            sb.name = "_CarColisao"
            node.add_child(sb)
            sb.set_owner(scene_root)
            sb.position = CAR_BOX_OFFSET
            
            var cs = CollisionShape3D.new()
            cs.name = "BoxShape"
            sb.add_child(cs)
            cs.set_owner(scene_root)
            
            var box = BoxShape3D.new()
            box.size = CAR_BOX_SIZE
            cs.shape = box
            
            added += 1
            print(f"[ColisaoAuto] Carro colisao adicionada: {node.get_path()}")
    
    # === 2. FAXINEIRO NPC ===
    var faxineiro = scene_root.find_child("faxineiro", true, false)
    if faxineiro and not _has_collision(faxineiro):
        var sb = StaticBody3D.new()
        sb.name = "_FaxineiroColisao"
        faxineiro.add_child(sb)
        sb.set_owner(scene_root)
        sb.position = Vector3(0, 0.85, 0)  # metade da altura da cápsula
        
        var cs = CollisionShape3D.new()
        cs.name = "CapsuleShape"
        sb.add_child(cs)
        cs.set_owner(scene_root)
        
        var cap = CapsuleShape3D.new()
        cap.height = FAX_CAPSULE_HEIGHT
        cap.radius = FAX_CAPSULE_RADIUS
        cs.shape = cap
        
        added += 1
        print("[ColisaoAuto] Faxineiro: colisao CapsuleShape3D adicionada!")
    
    print(f"[ColisaoAuto] CONCLUIDO - {added} colisoes adicionadas!")
    print("[ColisaoAuto] Salve a cena: Ctrl+S")

func _get_all_nodes(node: Node) -> Array:
    var result = [node]
    for child in node.get_children():
        result.append_array(_get_all_nodes(child))
    return result

func _has_collision(node: Node) -> bool:
    for child in node.get_children():
        if child is StaticBody3D or child is CollisionShape3D:
            return true
        if "_Col" in child.name or "_Colisao" in child.name:
            return true
    return false
