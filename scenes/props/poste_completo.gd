extends Node3D

@export var eh_lado_inversas: bool = false

var luz_vermelha: OmniLight3D
var luz_amarela: OmniLight3D
var luz_verde: OmniLight3D

func _ready() -> void:
	var sl = get_node_or_null("street_light2")
	if not sl:
		return
	
	var luzes: Array[OmniLight3D] = []
	for child in sl.get_children():
		if child is OmniLight3D:
			luzes.append(child)
	
	# Só cadastra se tiver as 3 lâmpadas de semáforo
	if luzes.size() < 3:
		return
	
	luzes.sort_custom(func(a, b): return a.position.y > b.position.y)
	luz_vermelha = luzes[0]
	luz_amarela  = luzes[1]
	luz_verde    = luzes[2]
	
	luz_vermelha.light_color = Color(1.0, 0.05, 0.05)
	luz_amarela.light_color  = Color(1.0, 0.70, 0.05)
	luz_verde.light_color    = Color(0.05, 1.0, 0.20)
	
	add_to_group("semaforos_poste_completo")
	
	var ctrl = get_tree().get_first_node_in_group("controladores_semaforo")
	if ctrl and ctrl.has_signal("mudou_estado"):
		ctrl.mudou_estado.connect(_on_mudou_estado)
		_on_mudou_estado(ctrl.estado_diretas, ctrl.estado_inversas)
	else:
		_ciclo_autonomo()

func _on_mudou_estado(estado_diretas: int, estado_inversas: int) -> void:
	var estado = estado_inversas if eh_lado_inversas else estado_diretas
	match estado:
		0: ativar_luz(true, false, false)
		1: ativar_luz(false, true, false)
		2: ativar_luz(false, false, true)

func ativar_luz(vermelho: bool, amarelo: bool, verde: bool) -> void:
	if luz_vermelha: luz_vermelha.visible = vermelho
	if luz_amarela: luz_amarela.visible = amarelo
	if luz_verde: luz_verde.visible = verde

func _ciclo_autonomo() -> void:
	while true:
		ativar_luz(true, false, false)
		await get_tree().create_timer(20.0).timeout
		ativar_luz(false, true, false)
		await get_tree().create_timer(4.0).timeout
		ativar_luz(false, false, true)
		await get_tree().create_timer(20.0).timeout
		ativar_luz(false, true, false)
		await get_tree().create_timer(4.0).timeout
