extends CanvasLayer

# ============================================================
# ITEM PICKUP POPUP – Fears to Fathom Style
# Canto superior direito, fade + slide, item girando
# ============================================================

@onready var container: Control        = $Container
@onready var nome_label: Label         = $Container/NomeLabel
@onready var item_pivot: Node3D        = $Container/ViewportContainer/SubViewport/ItemPivot

var _mostrando: bool = false
var _rot_speed: float = 42.0
var _current_tween: Tween = null
var _rest_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 22
	add_to_group("item_pickup_popup")
	if is_instance_valid(container):
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.hide()
		container.modulate.a = 0.0
		_rest_pos = container.position

func mostrar(dados: Dictionary) -> void:
	if _inventario_esta_aberto():
		esconder()
		return
	_mostrando = true
	if not is_instance_valid(container):
		await get_tree().process_frame
	if not is_instance_valid(container):
		return
	
	await get_tree().process_frame
	
	if is_instance_valid(nome_label):
		nome_label.text = str(dados.get("nome", "Item"))
	
	if is_instance_valid(item_pivot):
		for child in item_pivot.get_children():
			child.queue_free()
		# Pasta mais em pé, de frente pra câmera (não deitada)
		item_pivot.rotation_degrees = Vector3(-48.0, 22.0, 6.0)
		var mesh_path: String = str(dados.get("mesh_path", ""))
		if mesh_path != "" and ResourceLoader.exists(mesh_path):
			var scene: PackedScene = load(mesh_path)
			if scene:
				var inst: Node3D = scene.instantiate()
				item_pivot.add_child(inst)
				_auto_centralizar_e_escalar(inst, 0.82)
	
	if is_instance_valid(_current_tween):
		_current_tween.kill()
	
	container.pivot_offset = Vector2(container.size.x, 0.0)
	_rest_pos = container.position
	container.modulate.a = 0.0
	container.position = _rest_pos + Vector2(28.0, 0.0)
	container.scale = Vector2(0.92, 0.92)
	container.show()
	
	_current_tween = create_tween().set_parallel(true)
	_current_tween.tween_property(container, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(container, "position", _rest_pos, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func esconder() -> void:
	if not _mostrando:
		return
	_mostrando = false
	
	if not is_instance_valid(container):
		return
	
	if is_instance_valid(_current_tween):
		_current_tween.kill()
	
	_current_tween = create_tween().set_parallel(true)
	_current_tween.tween_property(container, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_current_tween.tween_property(container, "position", _rest_pos + Vector2(18.0, 0.0), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_current_tween.tween_property(container, "scale", Vector2(0.94, 0.94), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _current_tween.finished
	
	if not _mostrando and is_instance_valid(container):
		container.hide()
		container.position = _rest_pos

func esconder_imediato() -> void:
	_mostrando = false
	if is_instance_valid(_current_tween):
		_current_tween.kill()
	if is_instance_valid(container):
		container.hide()
		container.modulate.a = 0.0
		container.position = _rest_pos

func _inventario_esta_aberto() -> bool:
	for inventario in get_tree().get_nodes_in_group("inventario_ui"):
		if is_instance_valid(inventario) and inventario.has_method("esta_aberto") and inventario.esta_aberto():
			return true
	return false

func _process(delta: float) -> void:
	if _mostrando and is_instance_valid(item_pivot):
		item_pivot.rotation_degrees.y += _rot_speed * delta

func _auto_centralizar_e_escalar(root: Node3D, target_size: float = 0.95) -> void:
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
	if max_dim <= 0.0001:
		max_dim = 1.0
	
	var scale_factor = target_size / max_dim
	root.scale = Vector3.ONE * scale_factor
	# Sobe um pouco no frame (mesmo teto do objetivo) e deixa respiro acima do nome
	root.position = -total_aabb.get_center() * scale_factor
	root.position.y += 0.10

func _coletar_meshes(node: Node, lista: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		lista.append(node)
	for child in node.get_children():
		_coletar_meshes(child, lista)
