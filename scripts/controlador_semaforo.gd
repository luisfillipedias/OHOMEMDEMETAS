extends Node
class_name ControladorSemaforo

# ============================================================
# CONTROLADOR DE SEMÁFORO - HOMEM DE METAS
# Gerencia o ciclo de sinalização e sincroniza múltiplos postes
# ============================================================

enum EstadoSemaforo { VERMELHO, AMARELO, VERDE }

@export var tempo_vermelho: float = 35.0
@export var tempo_verde: float = 35.0
@export var tempo_amarelo: float = 4.0

var estado_atual: EstadoSemaforo = EstadoSemaforo.VERMELHO

signal mudou_estado(novo_estado: EstadoSemaforo)

func _ready() -> void:
	add_to_group("controladores_semaforo")
	_iniciar_ciclo()

func _iniciar_ciclo() -> void:
	while true:
		_definir_estado(EstadoSemaforo.VERMELHO)
		await get_tree().create_timer(tempo_vermelho).timeout
		
		_definir_estado(EstadoSemaforo.VERDE)
		await get_tree().create_timer(tempo_verde).timeout
		
		_definir_estado(EstadoSemaforo.AMARELO)
		await get_tree().create_timer(tempo_amarelo).timeout

func _definir_estado(novo_estado: EstadoSemaforo) -> void:
	estado_atual = novo_estado
	mudou_estado.emit(estado_atual)

func is_vermelho() -> bool:
	return estado_atual == EstadoSemaforo.VERMELHO or estado_atual == EstadoSemaforo.AMARELO
