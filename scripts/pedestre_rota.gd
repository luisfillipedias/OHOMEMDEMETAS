extends Path3D

# ============================================================
# SISTEMA DE PEDESTRES -- ROTAS VIVAS & REALISTAS COM ÁUDIO 3D
# ============================================================

@export var tempo_min_espera: float = 12.0
@export var tempo_max_espera: float = 28.0
@export var velocidade_base: float = 1.35
@export var altura_offset: float = 0.0

@export_group("Comportamento de Olhar")
@export var permitir_olhar_jogador: bool = true
@export var distancia_max_olhar: float = 7.5
@export var angulo_max_olhar_graus: float = 90.0
@export var angulo_max_cabeca_graus: float = 55.0
@export var velocidade_giro_cabeca: float = 4.0

var timer: Timer
var pedestres_ativos: Array = []

const AMOSTRA_FRENTE_METROS := 0.4
const CALIBRACAO_FRENTE_GRAUS := {
	"executivo.tscn": 180.0,
	"gordola.tscn": 180.0,
	"mendigo.tscn": 180.0,
	"redneck.tscn": 180.0,
	"velhinha.tscn": 180.0,
}

var _snd_step_pedestre: AudioStream = null

func _ready() -> void:
	randomize()
	if ResourceLoader.exists("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/footsteps/tunnel steps.wav"):
		_snd_step_pedestre = load("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/footsteps/tunnel steps.wav")
	elif ResourceLoader.exists("res://assets/audio/footstep.wav"):
		_snd_step_pedestre = load("res://assets/audio/footstep.wav")

	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_spawn_pedestre)
	add_child(timer)
	# Primeiro pedestre: 3-8 segundos após o jogo iniciar
	timer.start(randf_range(3.0, 8.0))

func _agendar_proximo() -> void:
	timer.start(randf_range(tempo_min_espera, tempo_max_espera))

func _spawn_pedestre() -> void:
	if not is_instance_valid(PedestreManager):
		_agendar_proximo()
		return

	var escolha = PedestreManager.pick_pedestre()
	if escolha.is_empty():
		# Pool lotado: tenta de novo em 15-30 segundos
		timer.start(randf_range(15.0, 30.0))
		return

	var index: int = escolha["index"]
	var cena: PackedScene = escolha["cena"]
	if cena == null:
		push_warning("Pedestre: cena inválida. Pulando.")
		_agendar_proximo()
		return

	var modelo_inst = cena.instantiate()
	if modelo_inst == null:
		push_warning("Pedestre: falha ao instanciar %s" % [cena.resource_path])
		if is_instance_valid(PedestreManager):
			PedestreManager.liberar_pedestre(index)
		_agendar_proximo()
		return

	_converter_animacao_para_in_place(modelo_inst)

	var follow := PathFollow3D.new()
	follow.loop = false
	follow.rotation_mode = PathFollow3D.ROTATION_NONE
	add_child(follow)
	follow.progress_ratio = 0.0

	var holder := Node3D.new()
	holder.name = "ModelHolder"
	holder.position.y = altura_offset
	holder.add_child(modelo_inst)
	follow.add_child(holder)

	# Áudio 3D posicional de passos para o pedestre
	var audio_3d := AudioStreamPlayer3D.new()
	audio_3d.name = "FootstepAudio3D"
	audio_3d.unit_size = 2.5
	audio_3d.max_distance = 18.0
	audio_3d.volume_db = -12.0
	audio_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	if _snd_step_pedestre:
		audio_3d.stream = _snd_step_pedestre
	holder.add_child(audio_3d)

	# Calibração de frente: 180Â° padrão para todos os modelos Mixamo
	var nome_arquivo := cena.resource_path.get_file()
	var correcao_graus: float = CALIBRACAO_FRENTE_GRAUS.get(nome_arquivo, 180.0)
	modelo_inst.rotation_degrees.y = correcao_graus

	# Alinha orientação inicial imediatamente
	_orientar_para_frente(follow, holder)

	# Localiza bone de cabeça/pescoço para girar e encarar o jogador
	var skeleton: Skeleton3D = modelo_inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var head_bone_idx := -1
	if skeleton:
		for nome_possivel in ["mixamorig_Head", "Head", "head", "mixamorig_Neck", "Neck"]:
			var idx := skeleton.find_bone(nome_possivel)
			if idx != -1:
				head_bone_idx = idx
				break

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

	var path_len = curve.get_baked_length() if curve else 50.0
	if path_len <= 1.0:
		path_len = 50.0
	var duracao = path_len / velocidade_base

	var pedestre_data := {
		"follow": follow,
		"holder": holder,
		"audio_3d": audio_3d,
		"step_timer": 0.0,
		"skeleton": skeleton,
		"head_bone_idx": head_bone_idx,
		"rest_bone_pose": Transform3D() if skeleton == null or head_bone_idx == -1 else skeleton.get_bone_pose(head_bone_idx),
		"olhando_atual": 0.0,
	}
	pedestres_ativos.append(pedestre_data)

	var tw = create_tween()
	tw.tween_property(follow, "progress_ratio", 0.998, duracao)
	tw.finished.connect(func():
		pedestres_ativos.erase(pedestre_data)
		if is_instance_valid(PedestreManager):
			PedestreManager.liberar_pedestre(index)
		follow.queue_free()
	)

	_agendar_proximo()

func _process(delta: float) -> void:
	if pedestres_ativos.is_empty():
		return

	var jogador: Node3D = null
	if permitir_olhar_jogador:
		var grupo = get_tree().get_nodes_in_group("player")
		if not grupo.is_empty():
			jogador = grupo[0]

	for p in pedestres_ativos:
		if not is_instance_valid(p["follow"]):
			continue
		_orientar_para_frente(p["follow"], p["holder"])
		
		# Processa som de passos 3D do pedestre
		p["step_timer"] += delta
		if p["step_timer"] >= 0.50:
			p["step_timer"] = 0.0
			var a3d: AudioStreamPlayer3D = p["audio_3d"]
			if is_instance_valid(a3d) and a3d.stream:
				a3d.pitch_scale = randf_range(0.90, 1.10)
				a3d.play()
		
		if permitir_olhar_jogador and jogador:
			_atualizar_olhar_cabeca(p, jogador, delta)
		elif p["skeleton"] != null and p["head_bone_idx"] != -1:
			var sk: Skeleton3D = p["skeleton"]
			var atual := sk.get_bone_pose(p["head_bone_idx"])
			var alvo: Transform3D = p["rest_bone_pose"]
			sk.set_bone_pose_rotation(p["head_bone_idx"], atual.basis.get_rotation_quaternion().slerp(alvo.basis.get_rotation_quaternion(), delta * velocidade_giro_cabeca))

func _orientar_para_frente(follow: PathFollow3D, holder: Node3D) -> void:
	if curve == null:
		return
	var comprimento := curve.get_baked_length()
	if comprimento <= 0.001:
		return

	var offset_atual: float = follow.progress
	var offset_frente: float = clamp(offset_atual + AMOSTRA_FRENTE_METROS, 0.0, comprimento)
	var offset_tras: float = clamp(offset_atual - AMOSTRA_FRENTE_METROS, 0.0, comprimento)

	if is_equal_approx(offset_frente, comprimento):
		offset_tras = clamp(comprimento - AMOSTRA_FRENTE_METROS * 2.0, 0.0, comprimento)
		offset_frente = comprimento
	if is_equal_approx(offset_tras, 0.0) and offset_frente > AMOSTRA_FRENTE_METROS:
		offset_tras = 0.0

	var pos_frente_global: Vector3 = to_global(curve.sample_baked(offset_frente))
	var pos_tras_global: Vector3 = to_global(curve.sample_baked(offset_tras))

	var direcao: Vector3 = pos_frente_global - pos_tras_global
	direcao.y = 0.0
	if direcao.length() < 0.0001:
		return

	var alvo: Vector3 = holder.global_position + direcao.normalized()
	holder.look_at(alvo, Vector3.UP)

func _atualizar_olhar_cabeca(p: Dictionary, jogador: Node3D, delta: float) -> void:
	var skeleton: Skeleton3D = p["skeleton"]
	var head_idx: int = p["head_bone_idx"]
	if skeleton == null or head_idx == -1:
		return

	var holder: Node3D = p["holder"]
	var para_jogador: Vector3 = jogador.global_position - holder.global_position
	var distancia := para_jogador.length()

	var olhar_alvo := 0.0
	if distancia <= distancia_max_olhar:
		var forward: Vector3 = -holder.global_transform.basis.z
		var angulo := rad_to_deg(forward.normalized().angle_to(para_jogador.normalized()))
		if angulo <= angulo_max_olhar_graus:
			olhar_alvo = 1.0

	p["olhando_atual"] = lerp(p["olhando_atual"], olhar_alvo, delta * velocidade_giro_cabeca)
	var peso: float = p["olhando_atual"]

	var pose_repouso: Transform3D = p["rest_bone_pose"]
	if peso < 0.01:
		skeleton.set_bone_pose_rotation(head_idx, pose_repouso.basis.get_rotation_quaternion())
		return

	var bone_global: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(head_idx)
	var dir_local: Vector3 = bone_global.basis.inverse() * (jogador.global_position - bone_global.origin)
	dir_local.y = 0.0
	if dir_local.length() < 0.0001:
		return
	var yaw_desejado := rad_to_deg(atan2(-dir_local.x, -dir_local.z))
	yaw_desejado = clamp(yaw_desejado, -angulo_max_cabeca_graus, angulo_max_cabeca_graus)

	var rot_repouso: Quaternion = pose_repouso.basis.get_rotation_quaternion()
	var rot_olhando: Quaternion = rot_repouso * Quaternion(Vector3.UP, deg_to_rad(yaw_desejado))
	var rot_final: Quaternion = rot_repouso.slerp(rot_olhando, peso)
	skeleton.set_bone_pose_rotation(head_idx, rot_final)

func _converter_animacao_para_in_place(node: Node) -> void:
	var anim_player = node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		return

	for anim_name in anim_player.get_animation_list():
		var anim = anim_player.get_animation(anim_name)
		if not anim:
			continue
		for track_idx in range(anim.get_track_count()):
			if anim.track_get_type(track_idx) == Animation.TYPE_POSITION_3D:
				var track_path: String = str(anim.track_get_path(track_idx)).to_lower()
				# Zera translação horizontal em Armature, Hips, Pelvis, Root, etc. (evita teleporte do redneck e outros)
				if "armature" in track_path or "hips" in track_path or "pelvis" in track_path or "root" in track_path or "mixamorig" in track_path or "skeleton" in track_path:
					var key_count = anim.track_get_key_count(track_idx)
					for k in range(key_count):
						var pos = anim.track_get_key_value(track_idx, k) as Vector3
						pos.x = 0.0
						pos.z = 0.0
						anim.track_set_key_value(track_idx, k, pos)