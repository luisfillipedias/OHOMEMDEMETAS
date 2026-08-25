extends Node
class_name ControladorSemaforo

# ============================================================
# CONTROLADOR DE SEMÁFORO COM FASES ALTERNADAS
# FASE_A (fase=0): traffic_light = VERMELHO, traffic_light_L = VERDE
#   -> Rotas diretas (1 e 2) PARAM, Rotas inversas (1 e 2) ANDAM
# FASE_B (fase=1): traffic_light = VERDE, traffic_light_L = VERMELHO
#   -> Rotas diretas ANDAM, Rotas inversas PARAM
# ============================================================

enum EstadoSemaforo { VERMELHO, AMARELO, VERDE }

@export var tempo_fase: float = 35.0
@export var tempo_amarelo: float = 4.0

var estado_atual: int = EstadoSemaforo.VERMELHO
var fase_atual: int = 0  # 0=FASE_A (diretas param), 1=FASE_B (inversas param)

signal mudou_fase(fase: int, estado: int)

func _ready() -> void:
	add_to_group("controladores_semaforo")
	_iniciar_ciclo()

func _iniciar_ciclo() -> void:
	while true:
		# FASE A: diretas=VERMELHO, inversas=VERDE
		fase_atual = 0
		_emitir(EstadoSemaforo.VERMELHO)
		await get_tree().create_timer(tempo_fase).timeout
		_emitir(EstadoSemaforo.AMARELO)
		await get_tree().create_timer(tempo_amarelo).timeout

		# FASE B: diretas=VERDE, inversas=VERMELHO
		fase_atual = 1
		_emitir(EstadoSemaforo.VERDE)
		await get_tree().create_timer(tempo_fase).timeout
		_emitir(EstadoSemaforo.AMARELO)
		await get_tree().create_timer(tempo_amarelo).timeout

func _emitir(estado: int) -> void:
	estado_atual = estado
	mudou_fase.emit(fase_atual, estado_atual)

func diretas_devem_parar() -> bool:
	if fase_atual == 0:
		return estado_atual == EstadoSemaforo.VERMELHO or estado_atual == EstadoSemaforo.AMARELO
	return estado_atual == EstadoSemaforo.AMARELO

func inversas_devem_parar() -> bool:
	if fase_atual == 1:
		return estado_atual == EstadoSemaforo.VERMELHO or estado_atual == EstadoSemaforo.AMARELO
	return estado_atual == EstadoSemaforo.AMARELO

func is_vermelho() -> bool:
	return diretas_devem_parar()
