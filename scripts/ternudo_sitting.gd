extends Node3D

@export_group("Comportamento de Olhar")
@export var permitir_olhar_jogador: bool = true
@export var distancia_max_olhar: float = 8.0
@export var angulo_max_olhar_graus: float = 85.0
@export var angulo_max_cabeca_graus: float = 55.0
@export var velocidade_giro_cabeca: float = 4.5
## Mixamo neste projeto olha para +Z; 180 alinha com o -Z do Godot (igual aos pedestres).
@export var correcao_frente_graus: float = 180.0

@export_group("Som de Assobio")
@export var distancia_assobio: float = 12.0
@export var volume_assobio_db: float = 2.5
@export var intervalo_min_assobio: float = 2.0
@export var intervalo_max_assobio: float = 5.0
@export var caminho_assobio: String = "res://assets/audio/things/assobio.mp3"
@export var assobio_unit_size: float = 15.0
@export var assobio_max_distance: float = 40.0

var _skeleton: Skeleton3D
var _head_bone_idx: int = -1
var _olhando_atual: float = 0.0
var _esta_olhando: bool = false

var _audio_assobio: AudioStreamPlayer3D
var _timer_assobio: float = 0.0


func _ready() -> void:
	randomize()
	process_priority = 100

	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton:
		for nome_possivel in ["mixamorig_Head", "Head", "head", "mixamorig_Neck", "Neck", "neck"]:
			var idx := _skeleton.find_bone(nome_possivel)
			if idx != -1:
				_head_bone_idx = idx
				print("[Sitting] osso olhar: idx=", idx, " nome=", _skeleton.get_bone_name(idx))
				break
		if _head_bone_idx == -1:
			print("[Sitting] ERRO: nenhum osso de cabeça Mixamo encontrado")
	else:
		print("[Sitting] ERRO: Skeleton3D nao encontrado")

	_criar_audio_assobio()
	_timer_assobio = randf_range(intervalo_min_assobio * 0.3, intervalo_max_assobio * 0.5)


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


func _criar_audio_assobio() -> void:
	_audio_assobio = AudioStreamPlayer3D.new()
	_audio_assobio.name = "AssobioAudio"
	_audio_assobio.unit_size = assobio_unit_size
	_audio_assobio.max_distance = assobio_max_distance
	_audio_assobio.volume_db = volume_assobio_db
	_audio_assobio.panning_strength = 1.0
	_audio_assobio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_audio_assobio)
	if ResourceLoader.exists(caminho_assobio):
		var stream_assobio = load(caminho_assobio) as AudioStream
		if stream_assobio:
			_audio_assobio.stream = stream_assobio
			print("[Sitting] Assobio CARREGADO com sucesso")


func _process(delta: float) -> void:
	var jogador: Node3D = null
	var grupo = get_tree().get_nodes_in_group("player")
	if not grupo.is_empty():
		jogador = grupo[0]

	if jogador == null or not is_instance_valid(jogador):
		_olhando_atual = lerp(_olhando_atual, 0.0, delta * 4.0)
		return

	var jog_pos: Vector3 = jogador.global_position

	if permitir_olhar_jogador:
		if global_position.distance_squared_to(jog_pos) <= 144.0:
			_atualizar_olhar_cabeca(jogador, delta)
		elif _olhando_atual > 0.001:
			_olhando_atual = lerp(_olhando_atual, 0.0, delta * 4.0)

	var dist_para_assobio: float = global_position.distance_to(jog_pos)
	if dist_para_assobio <= distancia_assobio:
		_timer_assobio -= delta
		if _timer_assobio <= 0.0:
			_tocar_assobio()
			_timer_assobio = randf_range(intervalo_min_assobio, intervalo_max_assobio)
	elif _timer_assobio <= 0.0:
		_timer_assobio = randf_range(intervalo_min_assobio * 0.5, intervalo_max_assobio * 0.7)


func _tocar_assobio() -> void:
	if is_instance_valid(_audio_assobio) and _audio_assobio.stream:
		_audio_assobio.pitch_scale = randf_range(0.88, 1.12)
		_audio_assobio.volume_db = volume_assobio_db + randf_range(0.0, 2.5)
		_audio_assobio.play()


func _atualizar_olhar_cabeca(jogador: Node3D, delta: float) -> void:
	if _skeleton == null or _head_bone_idx == -1:
		return

	var bone_trans_global: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone_idx)
	var head_pos: Vector3 = bone_trans_global.origin

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

	var yaw_rad: float = atan2(right.dot(dir_horiz), fwd.dot(dir_horiz))
	var angulo_abs_graus: float = rad_to_deg(abs(yaw_rad))

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

	var yaw_clamped: float = clamp(yaw_rad, deg_to_rad(-angulo_max_cabeca_graus), deg_to_rad(angulo_max_cabeca_graus))
	var dist_xz: float = max(0.4, Vector2(para_jogador.x, para_jogador.z).length())
	var pitch_rad: float = clamp(atan2(para_jogador.y, dist_xz), deg_to_rad(-38.0), deg_to_rad(22.0))

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

	var rot_anim: Quaternion = _skeleton.get_bone_pose_rotation(_head_bone_idx)
	var rot_alvo: Quaternion = q_look * rot_anim
	var rot_final: Quaternion = rot_anim.slerp(rot_alvo, peso)
	if not (rot_final.x == rot_final.x and rot_final.y == rot_final.y and rot_final.z == rot_final.z and rot_final.w == rot_final.w):
		return
	_skeleton.set_bone_pose_rotation(_head_bone_idx, rot_final)
