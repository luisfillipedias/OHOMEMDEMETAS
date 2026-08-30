extends Node3D

# ============================================================
# NPC_LOOK_AT.GD — Sistema Universal de Olhar para NPCs do CEFET
# Faz os NPCs encararem a Alice suavemente quando ela entra
# no campo de visão (FOV) e alcance deles, sem quebrar as animações.
# ============================================================

@export_group("Comportamento de Olhar")
@export var permitir_olhar_jogador: bool = true
## Distância máxima para começar a olhar o jogador (em metros)
@export var distancia_max_olhar: float = 8.0
## Campo de visão frontal (em graus da frente: 85° = cone frontal de 170°)
@export var angulo_max_olhar_graus: float = 85.0
## Limite anatômico máximo de giro da cabeça/pescoço (em graus)
@export var angulo_max_cabeca_graus: float = 55.0
## Limite de inclinação para cima (graus)
@export var angulo_max_pitch_cima: float = 24.0
## Limite de inclinação para baixo (graus)
@export var angulo_max_pitch_baixo: float = 38.0
## Velocidade de transição suave da cabeça
@export var velocidade_giro_cabeca: float = 4.5
## Calibração do eixo frontal do modelo (Mixamo padrão = 180°)
@export var correcao_frente_graus: float = 180.0

@export_group("Animação")
@export var tocar_animacao_idle: bool = true
@export var nome_animacao_idle: String = "mixamo_com"

var _skeleton: Skeleton3D
var _head_bone_idx: int = -1
var _olhando_atual: float = 0.0
var _esta_olhando: bool = false
var _anim_player: AnimationPlayer


func _ready() -> void:
	# Prioridade 100 garante execução APÓS o AnimationPlayer atualizar a pose do esqueleto
	process_priority = 100

	_inicializar_skeleton()
	_inicializar_animacao()


func _inicializar_skeleton() -> void:
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton:
		var nomes_possiveis := [
			"mixamorig_Head", "Head", "head",
			"mixamorig_Neck", "Neck", "neck",
			"mixamorig:Head", "mixamorig:Neck",
			"Cabeça", "cabeca"
		]
		for nome in nomes_possiveis:
			var idx := _skeleton.find_bone(nome)
			if idx != -1:
				_head_bone_idx = idx
				break


func _inicializar_animacao() -> void:
	_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player and tocar_animacao_idle:
		# Garante modo de loop contínuo nas animações do modelo
		var anim_list := _anim_player.get_animation_list()
		for anim_name in anim_list:
			var a = _anim_player.get_animation(anim_name)
			if a:
				a.loop_mode = Animation.LOOP_LINEAR

		if not _anim_player.is_playing():
			if _anim_player.has_animation(nome_animacao_idle):
				_anim_player.play(nome_animacao_idle)
			elif not anim_list.is_empty():
				_anim_player.play(anim_list[0])


func _eixo_frente() -> Vector3:
	var q := Quaternion(Vector3.UP, deg_to_rad(correcao_frente_graus))
	var fwd: Vector3 = q * (-global_transform.basis.z)
	fwd.y = 0.0
	return fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3(0, 0, -1)


func _eixo_direita() -> Vector3:
	var q := Quaternion(Vector3.UP, deg_to_rad(correcao_frente_graus))
	var right: Vector3 = q * global_transform.basis.x
	right.y = 0.0
	return right.normalized() if right.length_squared() > 0.0001 else Vector3(1, 0, 0)


func _process(delta: float) -> void:
	if not permitir_olhar_jogador or _skeleton == null or _head_bone_idx == -1:
		return

	var jogador: Node3D = null
	var grupo = get_tree().get_nodes_in_group("player")
	if not grupo.is_empty():
		jogador = grupo[0]

	if jogador == null or not is_instance_valid(jogador):
		if _olhando_atual > 0.001:
			_olhando_atual = lerp(_olhando_atual, 0.0, delta * 4.0)
		return

	var jog_pos: Vector3 = jogador.global_position
	var dist_sq: float = global_position.distance_squared_to(jog_pos)

	# Se estiver dentro de um raio de verificação razoável (12m), atualiza o olhar
	if dist_sq <= 144.0:
		_atualizar_olhar_cabeca(jogador, delta)
	elif _olhando_atual > 0.001:
		_olhando_atual = lerp(_olhando_atual, 0.0, delta * 4.0)


func _atualizar_olhar_cabeca(jogador: Node3D, delta: float) -> void:
	# Posição global da cabeça do NPC no mundo
	var bone_trans_global: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone_idx)
	var head_pos: Vector3 = bone_trans_global.origin

	# Posição alvo dos olhos/câmera do jogador
	var player_target_pos: Vector3
	var cam: Camera3D = jogador.find_child("Camera3D", true, false) as Camera3D
	if is_instance_valid(cam):
		player_target_pos = cam.global_position
	else:
		player_target_pos = jogador.global_position + Vector3(0.0, 0.75, 0.0)

	var para_jogador: Vector3 = player_target_pos - head_pos
	var distancia: float = para_jogador.length()

	var fwd: Vector3 = _eixo_frente()
	var right: Vector3 = _eixo_direita()

	var dir_horiz_raw := Vector3(para_jogador.x, 0.0, para_jogador.z)
	if dir_horiz_raw.length_squared() < 0.0001:
		return
	var dir_horiz: Vector3 = dir_horiz_raw.normalized()

	var dot_fwd: float = fwd.dot(dir_horiz)
	var dot_right: float = right.dot(dir_horiz)
	var yaw_rad: float = atan2(dot_right, dot_fwd)
	var angulo_abs_graus: float = rad_to_deg(abs(yaw_rad))

	# HISTERESE: evita flickers ou estalos quando o player anda na borda do campo de visão
	if not _esta_olhando:
		if distancia <= distancia_max_olhar and angulo_abs_graus <= angulo_max_olhar_graus:
			_esta_olhando = true
	else:
		if distancia > (distancia_max_olhar + 2.0) or angulo_abs_graus > (angulo_max_olhar_graus + 25.0):
			_esta_olhando = false

	var alvo_peso: float = 1.0 if _esta_olhando else 0.0
	_olhando_atual = lerp(_olhando_atual, alvo_peso, delta * velocidade_giro_cabeca)
	var peso: float = _olhando_atual

	if peso < 0.001:
		return

	# Limita yaw (giro horizontal da cabeça) e pitch (inclinação vertical)
	var yaw_clamped: float = clamp(yaw_rad, deg_to_rad(-angulo_max_cabeca_graus), deg_to_rad(angulo_max_cabeca_graus))
	var dist_xz: float = max(0.4, Vector2(para_jogador.x, para_jogador.z).length())
	var pitch_rad: float = clamp(atan2(para_jogador.y, dist_xz), deg_to_rad(-angulo_max_pitch_baixo), deg_to_rad(angulo_max_pitch_cima))

	# Transforma os eixos de rotação para o espaço local do osso da cabeça
	var parent_idx: int = _skeleton.get_bone_parent(_head_bone_idx)
	var basis_parent_inv: Basis
	if parent_idx != -1:
		basis_parent_inv = (_skeleton.global_transform * _skeleton.get_bone_global_pose(parent_idx)).basis.orthonormalized().inverse()
	else:
		basis_parent_inv = _skeleton.global_transform.basis.orthonormalized().inverse()

	var local_up: Vector3 = basis_parent_inv * Vector3.UP
	if local_up.length_squared() < 0.0001 or not local_up.is_finite():
		return
	local_up = local_up.normalized()

	var local_right: Vector3 = basis_parent_inv * right
	if local_right.length_squared() < 0.0001 or not local_right.is_finite():
		return
	local_right = local_right.normalized()

	var q_yaw := Quaternion(local_up, -yaw_clamped)
	var q_pitch := Quaternion(local_right, pitch_rad)
	var q_look := q_yaw * q_pitch

	# Aplica a rotação de olhar combinada com a pose base da animação
	var rot_anim: Quaternion = _skeleton.get_bone_pose_rotation(_head_bone_idx)
	var rot_alvo: Quaternion = q_look * rot_anim
	var rot_final: Quaternion = rot_anim.slerp(rot_alvo, peso)

	if not (rot_final.x == rot_final.x and rot_final.y == rot_final.y and rot_final.z == rot_final.z and rot_final.w == rot_final.w):
		return

	_skeleton.set_bone_pose_rotation(_head_bone_idx, rot_final)
