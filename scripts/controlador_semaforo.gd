extends Node
class_name ControladorSemaforo

# ============================================================
# CONTROLADOR DE SEMÁFORO - CICLO REALISTA (Verde -> Amarelo -> Vermelho -> Verde)
# Não existe amarelo saindo do vermelho. O amarelo é apenas aviso de fechamento.
# ============================================================

enum Estado { VERMELHO = 0, AMARELO = 1, VERDE = 2 }

@export var tempo_verde: float = 20.0
@export var tempo_amarelo: float = 4.0

var estado_diretas: int = Estado.VERDE
var estado_inversas: int = Estado.VERMELHO

signal mudou_estado(estado_diretas: int, estado_inversas: int)

func _ready() -> void:
	add_to_group("controladores_semaforo")
	_iniciar_ciclo()

func _iniciar_ciclo() -> void:
	while true:
		# 1. DIRETAS ABERTAS (Verde), INVERSAS FECHADAS (Vermelho)
		_definir(Estado.VERDE, Estado.VERMELHO)
		await get_tree().create_timer(tempo_verde).timeout

		# 2. DIRETAS AVISO (Amarelo - vai fechar), INVERSAS CONTINUAM FECHADAS (Vermelho)
		_definir(Estado.AMARELO, Estado.VERMELHO)
		await get_tree().create_timer(tempo_amarelo).timeout

		# 3. DIRETAS FECHADAS (Vermelho), INVERSAS ABERTAS (Vai direto pro Verde!)
		_definir(Estado.VERMELHO, Estado.VERDE)
		await get_tree().create_timer(tempo_verde).timeout

		# 4. DIRETAS CONTINUAM FECHADAS (Vermelho), INVERSAS AVISO (Amarelo - vai fechar)
		_definir(Estado.VERMELHO, Estado.AMARELO)
		await get_tree().create_timer(tempo_amarelo).timeout

func _definir(d: int, inv: int) -> void:
	estado_diretas = d
	estado_inversas = inv
	mudou_estado.emit(estado_diretas, estado_inversas)

func diretas_devem_parar() -> bool:
	return estado_diretas != Estado.VERDE

func inversas_devem_parar() -> bool:
	return estado_inversas != Estado.VERDE

func is_vermelho() -> bool:
	return diretas_devem_parar()
