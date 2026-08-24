extends Path3D

# ============================================================
# SISTEMA DE PEDESTRES -- ROTAS VIVAS & REALISTAS COM ÁUDIO 3D
# ============================================================

@export var tempo_min_espera: float = 12.0
@export var tempo_max_espera: float = 28.0
@export var velocidade_base: float = 1.35
@export var altura_offset: float = 0.055

@export_group("Comportamento de Olhar")
@export var permitir_olhar_jogador: bool = false
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

var _snds_pedestre: Array[AudioStream] = []

func _ready() -> void:
	randomize()
	# Carrega amostras de passos de alta qualidade (.ogg)
	for i in range(1, 22):
		var num_str = "%03d" % i
		var p = "res://assets/audio/pegadas/Floor/Steps_floor-%s.ogg" % num_str
		if ResourceLoader.exists(p):
			var st = load(p) as AudioStream
			if st:
				_snds_pedestre.append(st)

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

	var escolha: Dictionary = PedestreManager.pick_pedestre()
	if escolha.is_empty():
		_agendar_proximo()
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
	holder.position.y = altura_offset + 0.045 # Elevação para a sola do sapato não afundar no chão
	holder.add_child(modelo_inst)
	follow.add_child(holder)

	# Áudio 3D posicional de passos com atenuação espacial audível
	var audio_3d := AudioStreamPlayer3D.new()
	audio_3d.name = "FootstepAudio3D"
	audio_3d.unit_size = 8.0
	audio_3d.max_distance = 32.0
	audio_3d.volume_db = 0.0
	audio_3d.panning_strength = 1.0
	audio_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	holder.add_child(audio_3d)

	# Calibração de frente: 180° padrão para todos os modelos Mixamo
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
	var anim_speed: float = randf_range(1.1, 1.25)
	if anim_player:
		var anim_list = anim_player.get_animation_list()
		if not anim_list.is_empty():
			var anim_name = "mixamo_com" if anim_player.has_animation("mixamo_com") else anim_list[0]
			var anim = anim_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play(anim_name)
			anim_player.speed_scale = anim_speed

	var path_len = curve.get_baked_length() if curve else 50.0
	if path_len <= 1.0:
		path_len = 50.0
	var duracao = path_len / velocidade_base

	# Intervalo de passos sincronizado com a velocidade real de caminhada (metros/passo)
	# Um passo a cada ~0.62m caminhado; divide pelo ritmo real de deslocamento
	var step_interval: float = 0.62 / velocidade_base

	var pedestre_data := {
		"follow": follow,
		"holder": holder,
		"audio_3d": audio_3d,
		"step_timer": 0.0,
		"step_interval": step_interval,
		"skeleton": skeleton,
		"head_bone_idx": head_bone_idx,
		"rest_bone_pose": Transform3D() if skeleton == null or head_bone_idx == -1 else skeleton.get_bone_pose(head_bone_idx),
		"olhando_atual": 0.0,
		"esta_olhando": false,
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
		
		# Processa som de passos 3D espacial do pedestre
		p["step_timer"] += delta
		if p["step_timer"] >= p["step_interval"]:
			p["step_timer"] -= p["step_interval"]  # subtrai para manter cadencia sem drift
			var a3d: AudioStreamPlayer3D = p["audio_3d"]
			if is_instance_valid(a3d) and not _snds_pedestre.is_empty():
				var snd = _snds_pedestre[randi() % _snds_pedestre.size()]
				a3d.stream = snd
				a3d.pitch_scale = randf_range(0.92, 1.08)
				a3d.volume_db = randf_range(-2.0, +1.0)
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
	var para_jogador: Vector3 = (jogador.global_position + Vector3(0, 1.4, 0)) - (holder.global_position + Vector3(0, 1.4, 0))
	var distancia: float = para_jogador.length()

	var fwd: Vector3 = -holder.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	
	var right: Vector3 = holder.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var dir_horiz: Vector3 = Vector3(para_jogador.x, 0.0, para_jogador.z).normalized()
	var dot_fwd: float = fwd.dot(dir_horiz)
	var dot_right: float = right.dot(dir_horiz)
	var yaw_rad: float = atan2(dot_right, dot_fwd)
	var angulo_abs_graus: float = rad_to_deg(abs(yaw_rad))

	# HISTERESE: Zona de atenção estável sem oscilação/flicker na borda
	var esta_olhando: bool = p.get("esta_olhando", false)
	if not esta_olhando:
		if distancia <= 6.0 and angulo_abs_graus <= 75.0:
			esta_olhando = true
	else:
		if distancia > 8.5 or angulo_abs_graus > 110.0:
			esta_olhando = false
	p["esta_olhando"] = esta_olhando

	var alvo_peso: float = 1.0 if esta_olhando else 0.0
	p["olhando_atual"] = lerp(p["olhando_atual"], alvo_peso, delta * 4.5)
	var peso: float = p["olhando_atual"]

	var pose_repouso: Transform3D = p["rest_bone_pose"]
	var rot_repouso: Quaternion = pose_repouso.basis.get_rotation_quaternion()

	if peso < 0.005:
		skeleton.set_bone_pose_rotation(head_idx, rot_repouso)
		return

	# Limita o ângulo de rotação da cabeça (humano natural: até 65° yaw, 20° pitch)
	var yaw_clamped: float = clamp(yaw_rad, deg_to_rad(-65.0), deg_to_rad(65.0))
	var dist_xz: float = max(0.5, Vector2(para_jogador.x, para_jogador.z).length())
	var pitch_rad: float = clamp(atan2(para_jogador.y, dist_xz), deg_to_rad(-22.0), deg_to_rad(18.0))

	# PROJEÇÃO LOCAL DO EIXO VERTICAL DO OSSO (Corrige o pescoço quebrado e funciona em qualquer Rig)
	var bone_global: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(head_idx)
	var inv_basis: Basis = bone_global.basis.inverse()
	var local_up: Vector3 = (inv_basis * Vector3.UP).normalized()
	var local_right: Vector3 = (inv_basis * right).normalized()

	var rot_yaw := Quaternion(local_up, yaw_clamped)
	var rot_pitch := Quaternion(local_right, -pitch_rad)
	var rot_olhando: Quaternion = rot_repouso * (rot_pitch * rot_yaw)

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
