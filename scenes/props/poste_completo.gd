extends Node3D

@onready var luz_vermelha: OmniLight3D = $OmniLight3D
@onready var luz_amarela: OmniLight3D = $OmniLight3D2
@onready var luz_verde: OmniLight3D = $OmniLight3D3

func _ready() -> void:
	luz_vermelha.light_color = Color(1.0, 0.0, 0.0)
	luz_amarela.light_color = Color(1.0, 0.7, 0.0)
	luz_verde.light_color = Color(0.0, 1.0, 0.0)
	
	ciclo_semaforo()

func ciclo_semaforo() -> void:
	while true:
		# Vermelho por 35s
		ativar_luz(true, false, false)
		await get_tree().create_timer(35.0).timeout
		
		# Verde por 35s
		ativar_luz(false, false, true)
		await get_tree().create_timer(35.0).timeout
		
		# Amarelo por 4s
		ativar_luz(false, true, false)
		await get_tree().create_timer(4.0).timeout

func ativar_luz(vermelho: bool, amarelo: bool, verde: bool) -> void:
	luz_vermelha.visible = vermelho
	luz_amarela.visible = amarelo
	luz_verde.visible = verde
