extends Node3D

enum EstadoSemaforo { VERMELHO, AMARELO, VERDE }

@onready var luz_vermelha: OmniLight3D = $street_light2/OmniLight3D if has_node("street_light2/OmniLight3D") else null
@onready var luz_amarela: OmniLight3D = $street_light2/OmniLight3D2 if has_node("street_light2/OmniLight3D2") else null
@onready var luz_verde: OmniLight3D = $street_light2/OmniLight3D3 if has_node("street_light2/OmniLight3D3") else null

var estado_atual: EstadoSemaforo = EstadoSemaforo.VERMELHO
signal mudou_estado(novo_estado: EstadoSemaforo)

func _ready() -> void:
	# IMPORTANTE: So entra no grupo de semaforos se REALMENTE tiver as 3 luzes do semaforo!
	# Os outros 20 postes comuns da rua sao apenas lampadas e NAO param o transito.
	if luz_vermelha and luz_amarela and luz_verde:
		add_to_group("semaforos_poste_completo")
		luz_vermelha.light_color = Color(1.0, 0.0, 0.0)
		luz_amarela.light_color = Color(1.0, 0.7, 0.0)
		luz_verde.light_color = Color(0.0, 1.0, 0.0)
		_ciclo_semaforo()

func _ciclo_semaforo() -> void:
	while true:
		_definir_estado(EstadoSemaforo.VERMELHO)
		ativar_luz(true, false, false)
		await get_tree().create_timer(35.0).timeout
		
		_definir_estado(EstadoSemaforo.VERDE)
		ativar_luz(false, false, true)
		await get_tree().create_timer(35.0).timeout
		
		_definir_estado(EstadoSemaforo.AMARELO)
		ativar_luz(false, true, false)
		await get_tree().create_timer(4.0).timeout

func _definir_estado(novo_estado: EstadoSemaforo) -> void:
	estado_atual = novo_estado
	mudou_estado.emit(estado_atual)

func is_vermelho() -> bool:
	return estado_atual == EstadoSemaforo.VERMELHO or estado_atual == EstadoSemaforo.AMARELO

func ativar_luz(vermelho: bool, amarelo: bool, verde: bool) -> void:
	if luz_vermelha: luz_vermelha.visible = vermelho
	if luz_amarela: luz_amarela.visible = amarelo
	if luz_verde: luz_verde.visible = verde
