extends Node3D

@onready var luz_vermelha: OmniLight3D = $OmniLight3D
@onready var luz_amarela: OmniLight3D = $OmniLight3D2
@onready var luz_verde: OmniLight3D = $OmniLight3D3

func _ready() -> void:
	luz_vermelha.light_color = Color(1.0, 0.0, 0.0)
	luz_amarela.light_color = Color(1.0, 0.7, 0.0)
	luz_verde.light_color = Color(0.0, 1.0, 0.0)
	_set_energy(luz_vermelha, 1.2, 6.0)
	_set_energy(luz_amarela, 1.0, 5.0)
	_set_energy(luz_verde, 1.2, 6.0)
	add_to_group("semaforo_lado_direito")
	
	var ctrl = get_tree().get_first_node_in_group("controladores_semaforo")
	if ctrl and ctrl.has_signal("mudou_fase"):
		ctrl.mudou_fase.connect(_on_mudou_fase)
		_on_mudou_fase(ctrl.fase_atual, ctrl.estado_atual)
	else:
		_ciclo_autonomo()

func _set_energy(luz: OmniLight3D, e: float, r: float) -> void:
	if is_instance_valid(luz):
		luz.light_energy = e
		luz.omni_range = r

func _on_mudou_fase(fase: int, estado: int) -> void:
	# Este semáforo (direito/retas): VERMELHO na FASE_A, VERDE na FASE_B
	if fase == 0:
		match estado:
			0: ativar_luz(true, false, false)
			1: ativar_luz(false, true, false)
			_: ativar_luz(true, false, false)
	else:
		match estado:
			0: ativar_luz(false, false, true)
			1: ativar_luz(false, true, false)
			_: ativar_luz(false, false, true)

func _ciclo_autonomo() -> void:
	while true:
		ativar_luz(true, false, false)
		await get_tree().create_timer(35.0).timeout
		ativar_luz(false, false, true)
		await get_tree().create_timer(35.0).timeout
		ativar_luz(false, true, false)
		await get_tree().create_timer(4.0).timeout

func ativar_luz(v: bool, a: bool, ve: bool) -> void:
	if is_instance_valid(luz_vermelha): luz_vermelha.visible = v
	if is_instance_valid(luz_amarela): luz_amarela.visible = a
	if is_instance_valid(luz_verde): luz_verde.visible = ve
