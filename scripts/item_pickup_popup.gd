extends CanvasLayer

# ============================================================
# ITEM PICKUP POPUP – Fears to Fathom Style (10 segundos)
# ============================================================

@onready var container: Control        = $Container
@onready var nome_label: Label         = $Container/NomeLabel
@onready var item_pivot: Node3D        = $Container/ViewportContainer/SubViewport/ItemPivot

var _mostrando: bool = false
var _rot_speed: float = 36.0 # Rotação calma e elegante

func _ready() -> void:
	layer = 20
	container.hide()

func mostrar(dados: Dictionary) -> void:
	if _mostrando:
		container.hide()
	_mostrando = true
	
	nome_label.text = dados.get("nome", "ITEM").to_upper()
	
	for child in item_pivot.get_children():
		child.queue_free()
	
	item_pivot.rotation_degrees = Vector3(15.0, 20.0, 0.0)
	
	var mesh_path: String = dados.get("mesh_path", "")
	if mesh_path != "" and ResourceLoader.exists(mesh_path):
		var scene: PackedScene = load(mesh_path)
		if scene:
			var inst: Node3D = scene.instantiate()
			item_pivot.add_child(inst)
			_auto_centralizar_e_escalar(inst, 1.2)
	
	container.modulate.a = 0.0
	container.scale = Vector2(0.8, 0.8)
	container.show()
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(container, "modulate:a", 1.0, 0.4)
	tw.tween_property(container, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	
	# Fica visível por 10 segundos girando
	await get_tree().create_timer(10.0).timeout
	
	var tw2 = create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(container, "modulate:a", 0.0, 0.6)
	tw2.tween_property(container, "scale", Vector2(0.85, 0.85), 0.6)
	await tw2.finished
	
	container.hide()
	_mostrando = false

func _process(delta: float) -> void:
	if _mostrando and is_instance_valid(item_pivot):
		item_pivot.rotation_degrees.y += _rot_speed * delta

func _auto_centralizar_e_escalar(root: Node3D, target_size: float = 1.2) -> void:
	await get_tree().process_frame
	if not is_instance_valid(root):
		return
	
	var meshes: Array[MeshInstance3D] = []
	_coletar_meshes(root, meshes)
	if meshes.is_empty():
		return
	
	var total_aabb: AABB
	var primeiro = true
	for m in meshes:
		if m.mesh:
			var m_aabb = m.mesh.get_aabb()
			var xform = root.global_transform.affine_inverse() * m.global_transform
			var local_aabb = xform * m_aabb
			if primeiro:
				total_aabb = local_aabb
				primeiro = false
			else:
				total_aabb = total_aabb.merge(local_aabb)
	
	var max_dim = max(total_aabb.size.x, max(total_aabb.size.y, total_aabb.size.z))
	if max_dim <= 0.0001: max_dim = 1.0
	
	var scale_factor = target_size / max_dim
	root.scale = Vector3.ONE * scale_factor
	root.position = -total_aabb.get_center() * scale_factor

func _coletar_meshes(node: Node, lista: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		lista.append(node)
	for child in node.get_children():
		_coletar_meshes(child, lista)
