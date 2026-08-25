extends Path3D

# ============================================================
# CARRO ROTA - VERSÃO FINAL
# - Ponto de parada exato por índice do ponto da curva
# - Rotas diretas: chama diretas_devem_parar()
# - Rotas inversas: chama inversas_devem_parar()
# - Anti-colisão APENAS dentro da mesma rota (sem deadlock global)
# - Velocidades orgânicas variadas por carro
# ============================================================

## Índice 1-based do ponto de parada (1=primeiro ponto verde da curva)
## Rota1=7, Rota2=6, RotaInversa1=5, RotaInversa2=5
@export var numero_ponto_parada: int = 0

@export_group("Velocidade")
@export var vel_min: float = 8.5      # ~30 km/h
@export var vel_max: float = 13.5     # ~49 km/h
@export var aceleracao: float = 7.0
@export var frenagem: float = 22.0

@export_group("Fila")
## Distância de centro a centro para parada completa (carros ~6.2m → 2m de folga)
@export var gap_parada: float = 8.5
## Distância onde começa a desacelerar atrás do carro da frente
@export var gap_frenagem: float = 20.0

@export_group("Spawn")
@export var intervalo_min: float = 6.0
@export var intervalo_max: float = 13.0
@export var max_carros: int = 3

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
	_timer_spawn.timeout.connect(_spawn_timeout)
	add_child(_timer_spawn)
	_agendar_spawn(randf_range(1.0, 4.0))

func _configurar_ponto_parada() -> void:
	# Assign default if not set in Inspector
	if numero_ponto_parada <= 0:
		var n = name.to_lower()
		if   "inversa1" in n: numero_ponto_parada = 5
		elif "inversa2" in n: numero_ponto_parada = 5
		elif "carro2"   in n: numero_ponto_parada = 6
		elif "carro1"   in n: numero_ponto_parada = 7
	
	if not curve or numero_ponto_parada <= 0:
		return
	
	var idx = numero_ponto_parada - 1  # 0-based
	if idx < curve.point_count:
		var pt = curve.get_point_position(idx)
		_ponto_parada_m = curve.get_closest_offset(pt)
		print("[%s] Ponto de parada: ponto %d -> %.2fm na curva" % [name, numero_ponto_parada, _ponto_parada_m])

func _agendar_spawn(delay: float = -1.0) -> void:
	_timer_spawn.start(delay if delay >= 0.0 else randf_range(intervalo_min, intervalo_max))

func _spawn_timeout() -> void:
	_tentar_spawnar()
	_agendar_spawn()

func _tentar_spawnar() -> void:
	if _carros.size() >= max_carros:
		return
	
	# Não spawna se houver carro perto do início da rota
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
	
	var inst: Node3D = (info["cena"] as PackedScene).instantiate()
	holder.add_child(inst)
	
	var eng = inst.get_node_or_null("EngineAudio") as AudioStreamPlayer3D
	var horn = inst.get_node_or_null("HornAudio") as AudioStreamPlayer3D
	
	if is_instance_valid(eng):
		eng.pitch_scale = randf_range(0.88, 1.12)
		if not eng.playing: eng.play()
	
	# ── Personalidade única por carro (variações orgânicas) ──────────────
	# Cada carro tem comportamento ligeiramente diferente, como na vida real
	var p_vel       = randf_range(vel_min, vel_max)          # velocidade de cruzeiro pessoal
	var p_acel      = aceleracao  * randf_range(0.78, 1.22)  # motoristas mais/menos apressados
	var p_freio     = frenagem    * randf_range(0.75, 1.25)  # freios mais/menos sensíveis
	var p_gap_stop  = gap_parada  * randf_range(0.85, 1.20)  # distância pessoal de segurança
	var p_gap_slow  = gap_frenagem* randf_range(0.80, 1.20)  # onde começa a desacelerar
	# Offset lateral leve: o carro não fica perfeitamente no centro da faixa
	var p_lat_drift = randf_range(-0.18, 0.18)               # metros de desvio lateral
	# Pequeno ruído de velocidade (motor pulsa levemente, não é constante)
	var p_vel_noise_freq = randf_range(0.4, 1.1)             # frequência do pulso
	var p_vel_noise_amp  = randf_range(0.0, 0.6)             # amplitude (m/s) do pulso
	var p_noise_phase    = randf_range(0.0, TAU)             # fase inicial aleatória
	
	var dados := {
		"follow": follow,
		"holder": holder,
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
		"tempo_parado": 0.0,
		"ja_buzinou": false,
		"eng": eng,
		"horn": horn,
		"dir_frente": Vector3.FORWARD,
		"ultimo_yaw": 0.0,
		"tempo_total": 0.0,
	}
	
	_orientar(dados, 0.0)
	_carros.append(dados)
	cm.registrar_carro_ativo(dados)

func _physics_process(delta: float) -> void:
	if _carros.is_empty():
		return
	
	# Obtém estado do semáforo UMA VEZ por frame
	var ctrl = get_tree().get_first_node_in_group("controladores_semaforo")
	var deve_parar_sinal: bool = false
	if ctrl:
		if _eh_inversa:
			deve_parar_sinal = ctrl.inversas_devem_parar()
		else:
			deve_parar_sinal = ctrl.diretas_devem_parar()
	
	# Obstáculos (Player + Pedestres) - coletados uma vez por frame
	var obs_pos: Array[Vector3] = []
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player is Node3D:
		obs_pos.append(player.global_position)
	for ped in get_tree().get_nodes_in_group("pedestres"):
		if is_instance_valid(ped) and ped is Node3D:
			obs_pos.append(ped.global_position)
	
	# Ordena: maior progresso primeiro (= mais à frente na pista)
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
		
		# ── 1. SEMÁFORO: Parada no ponto exato da curva ──────────────────
		if deve_parar_sinal and _ponto_parada_m > 0.0:
			if prog <= _ponto_parada_m:
				var dist = _ponto_parada_m - prog
				if dist <= 25.0:
					# Desaceleração progressiva nos últimos 25m
					var t = clamp(dist / 24.0, 0.0, 1.0)
					vel_alvo = min(vel_alvo, c["vel_cruzeiro"] * t * t)
				if dist <= 0.5:
					# Chegou — trava duro no ponto
					vel_alvo = 0.0
					follow.progress = _ponto_parada_m
		
		# ── 2. ANTI-COLISÃO DENTRO DA MESMA ROTA ────────────────────────
		# Compara só com o carro imediatamente à frente (índice i-1)
		if i > 0:
			var cf: Dictionary = _carros[i - 1]
			var ff = cf.get("follow") as PathFollow3D
			if is_instance_valid(ff):
				var gap = ff.progress - prog
				if gap < c["gap_frenagem"]:
					if gap <= c["gap_parada"]:
						# Para completamente e impede ultrapassagem
						vel_alvo = 0.0
						follow.progress = min(follow.progress, ff.progress - c["gap_parada"])
					else:
						var r = clamp((gap - c["gap_parada"]) / (c["gap_frenagem"] - c["gap_parada"]), 0.0, 1.0)
						vel_alvo = min(vel_alvo, c["vel_cruzeiro"] * r)
		
		# ── 3. PEDESTRES / PLAYER ────────────────────────────────────────
		for op in obs_pos:
			var to_op = (op - car_pos)
			to_op.y = 0.0
			var dist_op = to_op.length()
			if dist_op < 11.0:
				var dot = frente.dot(to_op.normalized())
				if dot > 0.50:
					if dist_op <= 4.5:
						vel_alvo = 0.0
					else:
						var r = clamp((dist_op - 4.5) / 6.5, 0.0, 1.0)
						vel_alvo = min(vel_alvo, c["vel_cruzeiro"] * r)
		
		# ── 4. APLICAR VELOCIDADE ────────────────────────────────────────
		# Ruído orgânico de velocidade: o pé no acelerador nunca é perfeitamente constante
		c["tempo_total"] += delta
		var noise_vel: float = 0.0
		if vel_alvo > 1.0:
			noise_vel = sin(c["tempo_total"] * c["vel_noise_freq"] * TAU + c["noise_phase"]) * c["vel_noise_amp"]
		var vel_alvo_final: float = max(0.0, vel_alvo + noise_vel)
		
		var vel_ant: float = c["vel_atual"]
		# Freio e aceleração pessoal de cada motorista
		var taxa = c["freio"] if vel_alvo_final < vel_ant else c["acel"]
		c["vel_atual"] = move_toward(vel_ant, vel_alvo_final, taxa * delta)
		var vel: float = c["vel_atual"]
		
		# ── 5. BUZINA ────────────────────────────────────────────────────
		if vel < 0.15:
			c["tempo_parado"] += delta
			if c["tempo_parado"] > 4.0 and not c["ja_buzinou"]:
				c["ja_buzinou"] = true
				if randf() < 0.18:
					_buzinar(c)
		else:
			c["tempo_parado"] = 0.0
			c["ja_buzinou"] = false
		
		# ── 6. SOM DE MOTOR ──────────────────────────────────────────────
		var eng = c["eng"] as AudioStreamPlayer3D
		if is_instance_valid(eng):
			eng.pitch_scale = lerp(0.78, 1.38, clamp(vel / c["vel_cruzeiro"], 0.0, 1.0))
			if not eng.playing: eng.play()
		
		# ── 7. AVANÇAR NA ROTA ───────────────────────────────────────────
		follow.progress += vel * delta
		
		# Trava dura: nunca ultrapassa o ponto de parada no vermelho
		if deve_parar_sinal and _ponto_parada_m > 0.0:
			if follow.progress > _ponto_parada_m:
				follow.progress = _ponto_parada_m
		
		# ── 8. ORIENTAÇÃO + DESVIO LATERAL ORGÂNICO ─────────────────────
		_orientar(c, follow.progress)
		# Aplica leve desvio lateral (carro não fica perfeitamente centrado na faixa)
		holder.position.x = c["lat_drift"]
		
		# ── 9. FIM DA ROTA ───────────────────────────────────────────────
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

func _finalizar(c: Dictionary) -> void:
	_carros.erase(c)
	var cm = get_node_or_null("/root/CarroManager")
	if cm:
		cm.desregistrar_carro_ativo(c)
		cm.liberar_carro(c["index"])
	var fol = c.get("follow") as PathFollow3D
	if is_instance_valid(fol):
		fol.queue_free()
