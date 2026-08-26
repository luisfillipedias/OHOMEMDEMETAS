extends CanvasLayer

# ============================================================
# INVENTÁRIO UI – Estilo PSX / VHS / Fears to Fathom
# - Rotação lenta automática
# - Arraste com Botão Esquerdo do Mouse para inspecionar/girar o item
# ============================================================

signal fechou

@onready var root_control: Control         = $RootControl
@onready var nome_label: Label             = $RootControl/InfoContainer/NomeItem
@onready var descricao_label: Label        = $RootControl/InfoContainer/DescricaoItem
@onready var counter_label: Label          = $RootControl/InfoContainer/ItemCounter
@onready var btn_esq: Button               = $RootControl/BtnEsq
@onready var btn_dir: Button               = $RootControl/BtnDir
@onready var viewport_cont: Control        = $RootControl/ViewportContainer
@onready var item_pivot: Node3D            = $RootControl/ViewportContainer/SubViewport/ItemPivot
@onready var vazio_label: Label            = $RootControl/VazioLabel

var _indice: int = 0
var _itens: Array[Dictionary] = []
var _aberto: bool = false

# Rotação suave e inspeção por mouse
var _rot_speed: float = 16.0 # Bem mais devagar e suave
var _arrastando_mouse: bool = false
var _rot_manual: Vector3 = Vector3(12.0, 25.0, 0.0)

func _ready() -> void:
	layer = 15
	root_control.hide()
	set_process_unhandled_input(false)
	
	if is_instance_valid(btn_esq):
		btn_esq.pressed.connect(func(): _navegar(-1))
	if is_instance_valid(btn_dir):
		btn_dir.pressed.connect(func(): _navegar(1))

func abrir() -> void:
	if _aberto:
		return
	_aberto = true
	set_process_unhandled_input(true)
	_itens = Inventario.get_itens()
	_indice = clamp(_indice, 0, max(0, _itens.size() - 1))
	
	_arrastando_mouse = false
	_rot_manual = Vector3(12.0, 25.0, 0.0)
	
	root_control.modulate.a = 0.0
	root_control.show()
	
	var tw = create_tween()
	tw.tween_property(root_control, "modulate:a", 1.0, 0.25)
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_atualizar_display()

func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	_arrastando_mouse = false
	set_process_unhandled_input(false)
	
	var tw = create_tween()
	tw.tween_property(root_control, "modulate:a", 0.0, 0.20)
	await tw.finished
	
	root_control.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	fechou.emit()

func _process(delta: float) -> void:
	if not _aberto:
		return
	if is_instance_valid(item_pivot):
		if not _arrastando_mouse:
			_rot_manual.y += _rot_speed * delta
		item_pivot.rotation_degrees = _rot_manual

func _unhandled_input(event: InputEvent) -> void:
	if not _aberto:
		return
	
	# ── 1. Interação do Mouse: Arrastar para girar o item 3D ──────────
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_arrastando_mouse = event.pressed
			get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and _arrastando_mouse:
		# Girar em X (inclinação) e Y (rotação horizontal)
		_rot_manual.y += event.relative.x * 0.45
		_rot_manual.x += event.relative.y * 0.45
		_rot_manual.x = clamp(_rot_manual.x, -65.0, 65.0)
		if is_instance_valid(item_pivot):
			item_pivot.rotation_degrees = _rot_manual
		get_viewport().set_input_as_handled()
	
	# ── 2. Teclas: Navegação e Fechar ──────────────────────────────────
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_TAB:
				fechar()
				get_viewport().set_input_as_handled()
			KEY_LEFT, KEY_A:
				_navegar(-1)
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_D:
				_navegar(1)
				get_viewport().set_input_as_handled()

func _navegar(dir: int) -> void:
	if _itens.is_empty():
		return
	_indice = wrapi(_indice + dir, 0, _itens.size())
	_atualizar_display()

func _atualizar_display() -> void:
	_itens = Inventario.get_itens()
	
	if _itens.is_empty():
		nome_label.text = ""
		descricao_label.text = ""
		counter_label.text = ""
		vazio_label.show()
		viewport_cont.hide()
		btn_esq.hide()
		btn_dir.hide()
		return
	
	vazio_label.hide()
	viewport_cont.show()
	
	var tem_multiplos = _itens.size() > 1
	btn_esq.visible = tem_multiplos
	btn_dir.visible = tem_multiplos
	
	var item: Dictionary = _itens[_indice]
	nome_label.text = item.get("nome", "").to_upper()
	descricao_label.text = item.get("descricao", "")
	counter_label.text = "[ %d / %d ]" % [_indice + 1, _itens.size()]
	
	for child in item_pivot.get_children():
		child.queue_free()
	
	_rot_manual = Vector3(12.0, 25.0, 0.0)
	item_pivot.rotation_degrees = _rot_manual
	
	var mesh_path: String = item.get("mesh_path", "")
	if mesh_path != "" and ResourceLoader.exists(mesh_path):
		var scene: PackedScene = load(mesh_path)
		if scene:
			var inst: Node3D = scene.instantiate()
			item_pivot.add_child(inst)
			_auto_centralizar_e_escalar(inst, 1.4)

func _auto_centralizar_e_escalar(root: Node3D, target_size: float = 1.4) -> void:
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
	root.position = -total_aabb.get_center() * scale_factor

func _coletar_meshes(node: Node, lista: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		lista.append(node)
	for child in node.get_children():
		_coletar_meshes(child, lista)
