extends Node3D

# Semáforo traffic_light (Poste das Rotas Normais 1 e 2)
# $OmniLight3D  = Topo (Vermelho)
# $OmniLight3D2 = Meio (Amarelo)
# $OmniLight3D3 = Base (Verde)

@onready var luz_vermelha: OmniLight3D = $OmniLight3D
@onready var luz_amarela: OmniLight3D  = $OmniLight3D2
@onready var luz_verde: OmniLight3D    = $OmniLight3D3

var estado_atual: int = 2 # 0=VERMELHO, 1=AMARELO, 2=VERDE (Começa Verde)

func _ready() -> void:
	if is_instance_valid(luz_vermelha):
		luz_vermelha.light_color = Color(1.0, 0.05, 0.05)
		luz_vermelha.light_energy = 1.6
		luz_vermelha.omni_range = 6.0
	if is_instance_valid(luz_amarela):
		luz_amarela.light_color = Color(1.0, 0.70, 0.05)
		luz_amarela.light_energy = 1.4
		luz_amarela.omni_range = 5.5
	if is_instance_valid(luz_verde):
		luz_verde.light_color = Color(0.05, 1.0, 0.20)
		luz_verde.light_energy = 1.6
		luz_verde.omni_range = 6.0
	
	add_to_group("semaforo_rotas_normais")
	
	var ctrl = get_tree().get_first_node_in_group("controladores_semaforo")
	if ctrl and ctrl.has_signal("mudou_estado"):
		ctrl.mudou_estado.connect(_on_mudou_estado)
		_on_mudou_estado(ctrl.estado_diretas, ctrl.estado_inversas)
	else:
		_ciclo_autonomo()

func _on_mudou_estado(estado_diretas: int, _estado_inversas: int) -> void:
	estado_atual = estado_diretas
	match estado_atual:
		0: # VERMELHO (Acende topo)
			ativar_luz(true, false, false)
		1: # AMARELO (Acende meio)
			ativar_luz(false, true, false)
		2: # VERDE (Acende base)
			ativar_luz(false, false, true)

func ativar_luz(vermelho: bool, amarelo: bool, verde: bool) -> void:
	if is_instance_valid(luz_vermelha): luz_vermelha.visible = vermelho
	if is_instance_valid(luz_amarela): luz_amarela.visible = amarelo
	if is_instance_valid(luz_verde): luz_verde.visible = verde

func get_estado() -> int:
	return estado_atual

func is_vermelho() -> bool:
	return estado_atual == 0

func _ciclo_autonomo() -> void:
	while true:
		_on_mudou_estado(2, 0)
		await get_tree().create_timer(20.0).timeout
		_on_mudou_estado(1, 0)
		await get_tree().create_timer(4.0).timeout
		_on_mudou_estado(0, 2)
		await get_tree().create_timer(20.0).timeout
		_on_mudou_estado(0, 1)
		await get_tree().create_timer(4.0).timeout
