extends OmniLight3D

# Define as cores do semáforo
var cor_vermelha: Color = Color(1, 0, 0)     # Vermelho
var cor_amarela: Color = Color(1, 0.8, 0)   # Amarelo
var cor_verde: Color = Color(0, 1, 0)     # Verde

func _ready() -> void:
	ciclo_semaforo()

func ciclo_semaforo() -> void:
	while true:
		# Vermelho por 5 segundos
		light_color = cor_vermelha
		await get_tree().create_timer(5.0).timeout
		
		# Verde por 5 segundos
		light_color = cor_verde
		await get_tree().create_timer(5.0).timeout
		
		# Amarelo por 2 segundos
		light_color = cor_amarela
		await get_tree().create_timer(2.0).timeout
