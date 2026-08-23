extends Path3D

# ============================================================
# CONTROLADOR DE ROTA DE PEDESTRE - HOMEM DE METAS
# ============================================================

@export var tempo_min_espera: float = 15.0
@export var tempo_max_espera: float = 40.0
@export var velocidade_base: float = 2.4
@export var offset_orientacao_graus: float = 0.0
@export var altura_offset: float = 0.0

var timer: Timer = null

func _ready() -> void:
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_spawn_pedestre)
	add_child(timer)
	timer.start(randf_range(3.0, 10.0))

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
	
	# Converte a animação do Mixamo para "In Place" (remove deslocamento de Z que causava teleporte)
	_converter_animacao_para_in_place(modelo_inst)
	
	var follow := PathFollow3D.new()
	follow.loop = false
	follow.rotation_mode = PathFollow3D.ROTATION_Y
	follow.use_model_front = false
	
	var holder := Node3D.new()
	holder.name = "ModelHolder"
	holder.position.y = altura_offset
	holder.rotation_degrees.y = offset_orientacao_graus
	
	holder.add_child(modelo_inst)
	follow.add_child(holder)
	add_child(follow)
	
	# Executa animação de caminhada em loop contínuo
	var anim_player = modelo_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		var anim_list = anim_player.get_animation_list()
		if not anim_list.is_empty():
			var anim_name = "mixamo_com" if anim_player.has_animation("mixamo_com") else anim_list[0]
			var anim = anim_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play(anim_name)
			anim_player.speed_scale = randf_range(1.1, 1.3)
	
	# Deslocamento 100% suave pelo caminho via Tween
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

func _converter_animacao_para_in_place(node: Node) -> void:
	var anim_player = node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		return
	
	for anim_name in anim_player.get_animation_list():
		var anim = anim_player.get_animation(anim_name)
		if not anim:
			continue
		
		# Procura tracks de posição do osso do quadril (Hips) e zera X e Z para evitar teleporte
		for track_idx in range(anim.get_track_count()):
			var track_path = str(anim.track_get_path(track_idx))
			if ("hips" in track_path.to_lower() or "mixamorig" in track_path.to_lower()) and anim.track_get_type(track_idx) == Animation.TYPE_POSITION_3D:
				var key_count = anim.track_get_key_count(track_idx)
				for k in range(key_count):
					var pos = anim.track_get_key_value(track_idx, k) as Vector3
					pos.x = 0.0
					pos.z = 0.0
					anim.track_set_key_value(track_idx, k, pos)