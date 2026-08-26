extends Node3D

# Semáforo do Lado Esquerdo (Controla Rotas Inversas 1 e 2)

var luz_vermelha: OmniLight3D
var luz_amarela: OmniLight3D
var luz_verde: OmniLight3D

func _ready() -> void:
	_organizar_luzes_por_altura()
	add_to_group("semaforo_lado_esquerdo")
	
	var ctrl = get_tree().get_first_node_in_group("controladores_semaforo")
	if ctrl and ctrl.has_signal("mudou_estado"):
		ctrl.mudou_estado.connect(_on_mudou_estado)
		_on_mudou_estado(ctrl.estado_diretas, ctrl.estado_inversas)
	else:
		_ciclo_autonomo()

func _organizar_luzes_por_altura() -> void:
	var luzes: Array[OmniLight3D] = []
	for child in get_children():
		if child is OmniLight3D:
			luzes.append(child)
	
	# Ordena do mais alto (Y maior = topo) para o mais baixo (Y menor = base)
	luzes.sort_custom(func(a, b): return a.position.y > b.position.y)
	
	if luzes.size() >= 3:
		luz_vermelha = luzes[0] # Topo
		luz_amarela  = luzes[1] # Meio
		luz_verde    = luzes[2] # Baixo
	elif luzes.size() > 0:
		luz_vermelha = luzes[0]
	
	if is_instance_valid(luz_vermelha):
		luz_vermelha.light_color = Color(1.0, 0.05, 0.05)
		luz_vermelha.light_energy = 1.4
		luz_vermelha.omni_range = 6.0
	if is_instance_valid(luz_amarela):
		luz_amarela.light_color = Color(1.0, 0.70, 0.05)
		luz_amarela.light_energy = 1.2
		luz_amarela.omni_range = 5.5
	if is_instance_valid(luz_verde):
		luz_verde.light_color = Color(0.05, 1.0, 0.20)
		luz_verde.light_energy = 1.4
		luz_verde.omni_range = 6.0

func _on_mudou_estado(_estado_diretas: int, estado_inversas: int) -> void:
	match estado_inversas:
		0: # VERMELHO
			ativar_luz(true, false, false)
		1: # AMARELO
			ativar_luz(false, true, false)
		2: # VERDE
			ativar_luz(false, false, true)

func ativar_luz(vermelho: bool, amarelo: bool, verde: bool) -> void:
	if is_instance_valid(luz_vermelha): luz_vermelha.visible = vermelho
	if is_instance_valid(luz_amarela): luz_amarela.visible = amarelo
	if is_instance_valid(luz_verde): luz_verde.visible = verde

func _ciclo_autonomo() -> void:
	while true:
		ativar_luz(false, false, true)
		await get_tree().create_timer(20.0).timeout
		ativar_luz(false, true, false)
		await get_tree().create_timer(4.0).timeout
		ativar_luz(true, false, false)
		await get_tree().create_timer(20.0).timeout
		ativar_luz(false, true, false)
		await get_tree().create_timer(4.0).timeout
