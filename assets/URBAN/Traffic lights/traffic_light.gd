extends Node3D

@onready var luz_vermelha: OmniLight3D = $OmniLight3D
@onready var luz_amarela: OmniLight3D = $OmniLight3D2
@onready var luz_verde: OmniLight3D = $OmniLight3D3

@export var controlador_semaforo: Node

func _ready() -> void:
	luz_vermelha.light_color = Color(1.0, 0.0, 0.0)
	luz_amarela.light_color = Color(1.0, 0.7, 0.0)
	luz_verde.light_color = Color(0.0, 1.0, 0.0)
	
	if is_instance_valid(controlador_semaforo) and controlador_semaforo.has_signal("mudou_estado"):
		controlador_semaforo.mudou_estado.connect(_on_mudou_estado)
		_atualizar_por_estado(controlador_semaforo.estado_atual)
	else:
		# Fallback autônomo
		_ciclo_autonomo()

func _on_mudou_estado(novo_estado: int) -> void:
	_atualizar_por_estado(novo_estado)

func _atualizar_por_estado(estado: int) -> void:
	match estado:
		0: # VERMELHO
			ativar_luz(true, false, false)
		1: # AMARELO
			ativar_luz(false, true, false)
		2: # VERDE
			ativar_luz(false, false, true)

func _ciclo_autonomo() -> void:
	while true:
		ativar_luz(true, false, false)
		await get_tree().create_timer(35.0).timeout
		ativar_luz(false, false, true)
		await get_tree().create_timer(35.0).timeout
		ativar_luz(false, true, false)
		await get_tree().create_timer(4.0).timeout

func ativar_luz(vermelho: bool, amarelo: bool, verde: bool) -> void:
	if is_instance_valid(luz_vermelha): luz_vermelha.visible = vermelho
	if is_instance_valid(luz_amarela): luz_amarela.visible = amarelo
	if is_instance_valid(luz_verde): luz_verde.visible = verde
