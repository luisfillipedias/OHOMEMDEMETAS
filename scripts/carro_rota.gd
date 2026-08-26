extends Path3D

# ============================================================
# CARRO ROTA - CONTROLADOR DEFINITIVO DE TRÂNSITO ORGÂNICO
# - Sinal Verde: fluxo 100% livre em velocidade total
# - Filtro lateral preciso de pedestres (ignora quem está na calçada)
# - No Vermelho: parada limpa e travada na faixa
# - No Amarelo: decisão dinâmica de passagem ou frenagem
# ============================================================

## Índice 1-based do ponto de parada na curva (1 = primeiro ponto verde)
## Rota 1 = 7 | Rota 2 = 6 | Rota Inversa 1 = 5 | Rota Inversa 2 = 5
@export var numero_ponto_parada: int = 0

@export_group("Velocidade & Movimento")
@export var vel_min: float = 8.5      # ~30 km/h
@export var vel_max: float = 13.8     # ~50 km/h
@export var aceleracao_base: float = 8.5
@export var frenagem_base: float = 24.0

@export_group("Fila & Segurança")
## Distância de centro a centro para parada na fila (~6.2m carro + ~2.2m folga)
@export var gap_parada_base: float = 8.4
@export var gap_frenagem_base: float = 18.0

@export_group("Spawn Esporádico")
@export var intervalo_min: float = 10.0
@export var intervalo_max: float = 24.0
@export var chance_pular_spawn: float = 0.25
@export var max_carros: int = 3

@export_group("Visual")
@export var altura_suspensao: float = 0.22

var _carros: Array[Dictionary] = []
var _timer_spawn: Timer
var _length: float = 0.0
var _ponto_parada_m: float = -1.0
var _eh_inversa: bool = false

func _ready() -> void:
	await get_tree().process_frame
	if curve:
		_length = curve.get_baked_length()
	
	_eh_inversa = "inversa" in name.to_lower()
	_configurar_ponto_parada()
	
	_timer_spawn = Timer.new()
	_timer_spawn.one_shot = true
	_timer_spawn.timeout.connect(_on_spawn_timeout)
	add_child(_timer_spawn)
	_agendar_spawn(randf_range(1.0, 4.5))

func _configurar_ponto_parada() -> void:
	if numero_ponto_parada <= 0:
		var n = name.to_lower()
		if   "inversa1" in n: numero_ponto_parada = 5
		elif "inversa2" in n: numero_ponto_parada = 5
		elif "carro2"   in n: numero_ponto_parada = 6
		elif "carro1"   in n: numero_ponto_parada = 7
	
	if not curve or numero_ponto_parada <= 0:
		return
	
	var idx = numero_ponto_parada - 1
	if idx < curve.point_count:
		var pt = curve.get_point_position(idx)
		_ponto_parada_m = curve.get_closest_offset(pt)
		print("[%s] Ponto de parada: Ponto %d -> %.2fm na curva" % [name, numero_ponto_parada, _ponto_parada_m])

func _agendar_spawn(delay: float = -1.0) -> void:
	if delay < 0.0:
		delay = randf_range(intervalo_min, intervalo_max)
	_timer_spawn.start(delay)

func _on_spawn_timeout() -> void:
	var chapter = get_tree().get_first_node_in_group("chapter")
	if chapter and chapter.get("_intro_lock") == true:
		_agendar_spawn(2.5)
		return
	if randf() >= chance_pular_spawn:
		_tentar_spawnar()
	_agendar_spawn()

func _tentar_spawnar() -> void:
	if _carros.size() >= max_carros:
		return
	
	# Não spawna se houver carro perto do início da rota (mínimo 18m)
	for c in _carros:
		var fol = c.get("follow") as PathFollow3D
		if is_instance_valid(fol) and fol.progress < 18.0:
			return
	
	var cm = get_node_or_null("/root/CarroManager")
	if not cm:
		return
	var info = cm.pick_carro()
	if info.is_empty():
		return
	
	var follow := PathFollow3D.new()
	follow.loop = false
	follow.rotation_mode = PathFollow3D.ROTATION_NONE
	follow.use_model_front = false
	follow.progress = 0.0
	add_child(follow)
	
	var holder := Node3D.new()
	holder.position.y = altura_suspensao
	follow.add_child(holder)

	# Instancia o modelo do carro primeiro — precisamos medir o tamanho real
	# dele (cada um dos 21 modelos tem dimensões e "pivot" diferentes) antes
	# de montar a caixa de colisão, senão ela fica errada pra maioria deles.
	var inst: Node3D = (info["cena"] as PackedScene).instantiate()
	holder.add_child(inst)

	# Corpo físico para colisão com o player
	var corpo := AnimatableBody3D.new()
	corpo.sync_to_physics = false
	corpo.collision_layer = 1  # layer 1 = a mesma que o player detecta por padrão (mask=1)
	corpo.collision_mask = 0
	holder.add_child(corpo)

	var colisor := CollisionShape3D.new()
	var caixa := BoxShape3D.new()

	# Mede o AABB real do modelo instanciado (soma de todos os MeshInstance3D
	# dele) e usa isso pra dimensionar/posicionar a caixa — em vez de um
	# tamanho fixo igual pra todos os 21 modelos de carro.
	var aabb_local: AABB = _calcular_aabb_veiculo(inst, holder)
	if aabb_local.size.length() > 0.1:
		var tamanho: Vector3 = aabb_local.size * 1.05  # ~5% de folga
		caixa.size = tamanho
		colisor.position = aabb_local.get_center()
	else:
		# Fallback: não deu pra medir (sem MeshInstance3D visível) — usa o
		# valor genérico de antes.
		caixa.size = Vector3(1.8, 1.4, 4.2)
		colisor.position.y = 0.7

	colisor.shape = caixa
	corpo.add_child(colisor)
	
	var eng = inst.get_node_or_null("EngineAudio") as AudioStreamPlayer3D
	var horn = inst.get_node_or_null("HornAudio") as AudioStreamPlayer3D
	
	if is_instance_valid(eng):
		eng.pitch_scale = randf_range(0.88, 1.12)
		if not eng.playing: eng.play()
	
	# ── Variação Orgânica dos Faróis por Veículo ──────────────────────
	var hl_energy = randf_range(2.4, 4.2)
	var hl_range = randf_range(25.0, 32.0)
	var hl_color_choice = randi() % 3
	var hl_color: Color
	match hl_color_choice:
		0: hl_color = Color(1.0, 0.93, 0.78)
		1: hl_color = Color(1.0, 0.98, 0.88)
		2: hl_color = Color(0.92, 0.96, 1.0)
	
	var hl_l = inst.get_node_or_null("HeadlightL") as SpotLight3D
	var hl_r = inst.get_node_or_null("HeadlightR") as SpotLight3D
	for hl in [hl_l, hl_r]:
		if is_instance_valid(hl):
			hl.light_energy = hl_energy
			hl.spot_range = hl_range
			hl.light_color = hl_color
	
	# ── Personalidade única do motorista/carro ────────────────────────
	var p_vel       = randf_range(vel_min, vel_max)
	var p_acel      = aceleracao_base * randf_range(0.85, 1.20)
	var p_freio     = frenagem_base   * randf_range(0.85, 1.20)
	var p_gap_stop  = gap_parada_base * randf_range(0.90, 1.15)
	var p_gap_slow  = gap_frenagem_base * randf_range(0.85, 1.15)
	var p_lat_drift = randf_range(-0.16, 0.16)
	var p_vel_noise_freq = randf_range(0.5, 1.0)
	var p_vel_noise_amp  = randf_range(0.0, 0.4)
	var p_noise_phase    = randf_range(0.0, TAU)
	var p_ousadia_amarelo = randf_range(0.85, 1.35)
	
	var dados := {
		"follow": follow,
		"holder": holder,
		"corpo": corpo,
		"inst": inst,
		"index": info["index"],
		"vel_atual": 0.0,
		"vel_cruzeiro": p_vel,
		"acel": p_acel,
		"freio": p_freio,
		"gap_parada": p_gap_stop,
		"gap_frenagem": p_gap_slow,
		"lat_drift": p_lat_drift,
		"vel_noise_freq": p_vel_noise_freq,
		"vel_noise_amp": p_vel_noise_amp,
		"noise_phase": p_noise_phase,
		"ousadia_amarelo": p_ousadia_amarelo,
		"tempo_parado": 0.0,
		"tempo_total": 0.0,
		"ja_buzinou": false,
		"cruzou_sinal": false,
		"eng": eng,
		"horn": horn,
		"dir_frente": Vector3.FORWARD,
		"ultimo_yaw": 0.0,
	}
	
	_orientar(dados, 0.0)
	_carros.append(dados)
	cm.registrar_carro_ativo(dados)

func _obter_estado_semaforo() -> int:
	var grupo = "semaforo_rotas_inversas" if _eh_inversa else "semaforo_rotas_normais"
	var sem = get_tree().get_first_node_in_group(grupo)
	if is_instance_valid(sem) and sem.has_method("get_estado"):
		return sem.get_estado()
	
	var ctrl = get_tree().get_first_node_in_group("controladores_semaforo")
	if ctrl:
		return ctrl.estado_inversas if _eh_inversa else ctrl.estado_diretas
	return 2

func _physics_process(delta: float) -> void:
	if _carros.is_empty():
		return
	
	var estado_real: int = _obter_estado_semaforo()
	
	# Obstáculos (Player e Pedestres)
	var obs_pos: Array[Vector3] = []
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player is Node3D:
		obs_pos.append(player.global_position)
	for ped in get_tree().get_nodes_in_group("pedestres"):
		if is_instance_valid(ped) and ped is Node3D:
			obs_pos.append(ped.global_position)
	
	# Ordena: maior progresso primeiro (carro mais avançado na rota)
	_carros.sort_custom(func(a, b):
		var pa = (a["follow"] as PathFollow3D).progress if is_instance_valid(a.get("follow")) else 0.0
		var pb = (b["follow"] as PathFollow3D).progress if is_instance_valid(b.get("follow")) else 0.0
		return pa > pb
	)
	
	var para_remover: Array = []
	
	for i in range(_carros.size()):
		var c: Dictionary = _carros[i]
		var follow = c["follow"] as PathFollow3D
		var holder = c["holder"] as Node3D
		
		if not is_instance_valid(follow) or not is_instance_valid(holder):
			para_remover.append(c)
			continue
		
		var prog: float = follow.progress
		var vel_alvo: float = c["vel_cruzeiro"]
		var car_pos: Vector3 = holder.global_position
		var frente: Vector3 = c["dir_frente"]
		var lateral = Vector3(-frente.z, 0.0, frente.x).normalized()
		
		# ── 1. REGISTRO DE PASSAGEM LIBERADA ─────────────────────────────
		if _ponto_parada_m > 0.0 and not c["cruzou_sinal"]:
			if estado_real == 2 and prog >= (_ponto_parada_m + 0.5):
				c["cruzou_sinal"] = true
		
		# ── 2. COMPORTAMENTO DO SEMÁFORO ──────────────────────────────────
		if _ponto_parada_m > 0.0 and not c["cruzou_sinal"]:
			var dist = _ponto_parada_m - prog
			
			if estado_real == 2: # VERDE
				# No VERDE: mantém 100% da velocidade de cruzeiro sem frear!
				vel_alvo = c["vel_cruzeiro"]
			
			elif estado_real == 1: # AMARELO
				var limite_passagem = 12.0 * c.get("ousadia_amarelo", 1.0)
				if dist <= limite_passagem and c["vel_atual"] > 3.5:
					vel_alvo = c["vel_cruzeiro"] * 1.12
					if prog >= (_ponto_parada_m + 0.5):
						c["cruzou_sinal"] = true
				else:
					if dist > 0.0:
						var t = clamp(dist / 22.0, 0.0, 1.0)
						vel_alvo = min(vel_alvo, c["vel_cruzeiro"] * (t * t))
					if dist <= 0.3:
						vel_alvo = 0.0
						follow.progress = min(follow.progress, _ponto_parada_m)
						c["vel_atual"] = 0.0
			
			elif estado_real == 0: # VERMELHO
				if dist > 0.0:
					var t = clamp(dist / 22.0, 0.0, 1.0)
					vel_alvo = min(vel_alvo, c["vel_cruzeiro"] * (t * t))
				
				if dist <= 0.3 or prog >= _ponto_parada_m:
					vel_alvo = 0.0
					follow.progress = min(follow.progress, _ponto_parada_m)
					c["vel_atual"] = 0.0
		
		# ── 3. ANTI-COLISÃO EM FILA NA MESMA ROTA ────────────────────────
		if i > 0:
			var cf: Dictionary = _carros[i - 1]
			var ff = cf.get("follow") as PathFollow3D
			if is_instance_valid(ff):
				var gap = ff.progress - prog
				if gap < c["gap_frenagem"]:
					if gap <= c["gap_parada"]:
						vel_alvo = 0.0
						follow.progress = min(follow.progress, ff.progress - c["gap_parada"])
						c["vel_atual"] = 0.0
					else:
						var r = clamp((gap - c["gap_parada"]) / (c["gap_frenagem"] - c["gap_parada"]), 0.0, 1.0)
						vel_alvo = min(vel_alvo, c["vel_cruzeiro"] * r)
		
		# ── 4. PEDESTRES / PLAYER (Com Filtro Lateral de Pista) ───────────
		# Só freia para pedestres/player se estiverem DIRETAMENTE na pista em frente (< 1.75m lateral)
		# Ignora pedestres que estão andando tranquilamente na calçada!
		for op in obs_pos:
			var to_op = (op - car_pos)
			to_op.y = 0.0
			var dist_frontal = to_op.dot(frente)
			var dist_lateral = abs(to_op.dot(lateral))
			
			# Se estiver à frente (entre 0.5m e 9.5m) e dentro da largura da faixa (< 1.75m lateral)
			if dist_frontal > 0.5 and dist_frontal < 9.5 and dist_lateral < 1.75:
				if dist_frontal <= 4.2:
					vel_alvo = 0.0
					c["vel_atual"] = 0.0
				else:
					var r = clamp((dist_frontal - 4.2) / 5.3, 0.0, 1.0)
					vel_alvo = min(vel_alvo, c["vel_cruzeiro"] * r)
		
		# ── 5. APLICAÇÃO DE VELOCIDADE ───────────────────────────────────
		c["tempo_total"] += delta
		var noise_vel: float = 0.0
		if vel_alvo > 1.0:
			noise_vel = sin(c["tempo_total"] * c["vel_noise_freq"] * TAU + c["noise_phase"]) * c["vel_noise_amp"]
		var vel_alvo_final: float = max(0.0, vel_alvo + noise_vel)
		
		var vel_ant: float = c["vel_atual"]
		var taxa = c["freio"] if vel_alvo_final < vel_ant else c["acel"]
		c["vel_atual"] = move_toward(vel_ant, vel_alvo_final, taxa * delta)
		var vel: float = c["vel_atual"]
		
		# ── 6. BUZINA ────────────────────────────────────────────────────
		if vel < 0.15:
			c["tempo_parado"] += delta
			if c["tempo_parado"] > 4.5 and not c["ja_buzinou"]:
				c["ja_buzinou"] = true
				if randf() < 0.18:
					_buzinar(c)
		else:
			c["tempo_parado"] = 0.0
			c["ja_buzinou"] = false
		
		# ── 7. SOM DE MOTOR ──────────────────────────────────────────────
		var eng = c["eng"] as AudioStreamPlayer3D
		if is_instance_valid(eng):
			eng.pitch_scale = lerp(0.80, 1.35, clamp(vel / c["vel_cruzeiro"], 0.0, 1.0))
			if not eng.playing: eng.play()
		
		# ── 8. AVANÇO NA ROTA ────────────────────────────────────────────
		follow.progress += vel * delta
		
		# Trava dura garantida: no vermelho ou parada de amarelo, nunca ultrapassa o ponto
		if (estado_real == 0 or (estado_real == 1 and vel_alvo <= 0.01)) and _ponto_parada_m > 0.0 and not c["cruzou_sinal"]:
			if follow.progress > _ponto_parada_m:
				follow.progress = _ponto_parada_m
				c["vel_atual"] = 0.0
		
		# ── 9. ORIENTAÇÃO E DESVIO LATERAL ───────────────────────────────
		_orientar(c, follow.progress)
		holder.position.x = c["lat_drift"]

		# Sincroniza corpo físico manualmente
		var corpo_fisico: AnimatableBody3D = c.get("corpo")
		if is_instance_valid(corpo_fisico):
			corpo_fisico.global_transform = holder.global_transform

		# ── 10. FIM DA ROTA ──────────────────────────────────────────────
		if follow.progress >= (_length - 1.5):
			para_remover.append(c)
	
	for rem in para_remover:
		_finalizar(rem)

func _orientar(c: Dictionary, prog: float) -> void:
	if not curve: return
	var holder = c["holder"] as Node3D
	if not is_instance_valid(holder): return
	
	var pa = clamp(prog, 0.0, _length)
	var pb = clamp(prog + 1.5, 0.0, _length)
	if pa >= pb:
		pa = max(_length - 1.5, 0.0)
		pb = _length
	
	var pta: Vector3 = global_transform * curve.sample_baked(pa)
	var ptb: Vector3 = global_transform * curve.sample_baked(pb)
	var dir = ptb - pta
	dir.y = 0.0
	
	if dir.length_squared() > 0.0001:
		var nd = dir.normalized()
		c["dir_frente"] = nd
		var yaw = atan2(nd.x, nd.z)
		c["ultimo_yaw"] = yaw
		holder.global_rotation.y = yaw
	else:
		holder.global_rotation.y = c.get("ultimo_yaw", 0.0)

func _buzinar(c: Dictionary) -> void:
	var h = c["horn"] as AudioStreamPlayer3D
	if is_instance_valid(h) and not h.playing:
		h.pitch_scale = randf_range(0.92, 1.08)
		h.play()

## Calcula o AABB combinado de todos os MeshInstance3D dentro de "raiz",
## já convertido para o espaço local de "referencia" (normalmente o holder).
## Usado pra dimensionar a caixa de colisão de cada modelo de carro
## automaticamente, já que os 21 modelos têm tamanhos/pivots diferentes.
func _calcular_aabb_veiculo(raiz: Node3D, referencia: Node3D) -> AABB:
	var combinado := AABB()
	var tem_algo := false

	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var atual: Node = pilha.pop_back()
		if atual is MeshInstance3D:
			var vi := atual as MeshInstance3D
			var aabb_mundo: AABB = vi.global_transform * vi.get_aabb()
			if not tem_algo:
				combinado = aabb_mundo
				tem_algo = true
			else:
				combinado = combinado.merge(aabb_mundo)
		for filho in atual.get_children():
			pilha.append(filho)

	if not tem_algo:
		return AABB()

	# Converte de espaço mundial para o espaço local de "referencia"
	return referencia.global_transform.affine_inverse() * combinado

func _finalizar(c: Dictionary) -> void:
	_carros.erase(c)
	var cm = get_node_or_null("/root/CarroManager")
	if cm:
		cm.desregistrar_carro_ativo(c)
		cm.liberar_carro(c["index"])
	var fol = c.get("follow") as PathFollow3D
	if is_instance_valid(fol):
		fol.queue_free()
