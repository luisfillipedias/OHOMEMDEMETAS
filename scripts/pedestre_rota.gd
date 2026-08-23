extends Path3D

# ============================================================
# CONTROLADOR DE ROTA DE PEDESTRE - HOMEM DE METAS
# ============================================================

@export var tempo_min_espera: float = 18.0
@export var tempo_max_espera: float = 45.0
@export var velocidade_base: float = 2.4
@export var offset_orientacao_graus: float = 0.0 # 0, 90, 180 dependendo da orientação do FBX
@export var altura_offset: float = 0.0 # Ajuste de altura para desnível de chão

var timer: Timer = null

func _ready() -> void:
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_spawn_pedestre)
	add_child(timer)
	
	# Primeiro pedestre surge após um pequeno atraso inicial
	timer.start(randf_range(5.0, 15.0))

func _agendar_proximo() -> void:
	timer.start(randf_range(tempo_min_espera, tempo_max_espera))

func _spawn_pedestre() -> void:
	if not is_instance_valid(PedestreManager):
		_agendar_proximo()
		return
	
	var escolha = PedestreManager.pick_pedestre()
	if escolha.is_empty():
		_agendar_proximo()
		return
	
	var index: int = escolha["index"]
	var cena: PackedScene = escolha["cena"]
	var modelo_inst = cena.instantiate()
	
	var follow := PathFollow3D.new()
	follow.loop = false
	follow.rotation_mode = PathFollow3D.ROTATION_Y
	follow.use_model_front = true
	
	# Ajuste de escala para modelos FBX que venham em centímetros (0.01) ou padrão (1.0)
	var base_holder := Node3D.new()
	base_holder.name = "ModelHolder"
	base_holder.position.y = altura_offset
	base_holder.rotation_degrees.y = offset_orientacao_graus
	
	# Verifica se o modelo precisa de correção de escala
	base_holder.add_child(modelo_inst)
	follow.add_child(base_holder)
	add_child(follow)
	
	# Garante que a animação de caminhada toque
	var anim_player = modelo_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		var anim_list = anim_player.get_animation_list()
		if not anim_list.is_empty():
			var anim_name = "mixamo_com" if anim_player.has_animation("mixamo_com") else anim_list[0]
			anim_player.play(anim_name)
			anim_player.speed_scale = randf_range(1.1, 1.3) # Passo apressado na chuva
	
	# Movimenta pelo caminho com variação natural de velocidade
	var path_len = curve.get_baked_length() if curve else 50.0
	if path_len <= 1.0:
		path_len = 50.0
	var duracao = path_len / velocidade_base
	
	var tw = create_tween()
	tw.tween_property(follow, "progress_ratio", 1.0, duracao)
	tw.finished.connect(func():
		if is_instance_valid(PedestreManager):
			PedestreManager.liberar_pedestre(index)
		follow.queue_free()
	)
	
	_agendar_proximo()