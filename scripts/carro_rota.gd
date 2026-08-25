extends Path3D

# ============================================================
# CONTROLADOR DE ROTA DE CARROS - O HOMEM DE METAS
# Movimentação contínua por frame com piloto automático,
# distanciamento seguro, semáforos, áudio 3D e buzinas
# ============================================================

@export_group("Velocidade & Movimento")
@export var velocidade_maxima: float = 12.0 # ~43 km/h
@export var aceleracao: float = 5.5
@export var frenagem: float = 12.0
@export var distancia_seguranca: float = 8.0 # Metros de distância segura do carro à frente

@export_group("Spawn")
@export var intervalo_spawn_min: float = 6.0
@export var intervalo_spawn_max: float = 13.0
@export var max_carros_na_rota: int = 3

@export_group("Semáforos & Parada")
@export var ponto_parada_cruzamento1_m: float = -1.0 # -1 desativa
@export var ponto_parada_cruzamento2_m: float = -1.0
@export var distancia_frenagem_semaforo: float = 14.0

@export_group("Calibração Visual")
@export var yaw_offset_graus: float = 0.0

var carros_na_rota: Array[Dictionary] = []
var _timer_spawn: Timer

func _ready() -> void:
	_timer_spawn = Timer.new()
	_timer_spawn.one_shot = true
	_timer_spawn.timeout.connect(_on_timer_spawn_timeout)
	add_child(_timer_spawn)
	_agendar_proximo_spawn(randf_range(1.0, 4.0))

func _agendar_proximo_spawn(delay: float = -1.0) -> void:
	if delay < 0.0:
		delay = randf_range(intervalo_spawn_min, intervalo_spawn_max)
	_timer_spawn.start(delay)

func _on_timer_spawn_timeout() -> void:
	_tentar_spawnar_carro()
	_agendar_proximo_spawn()

func _tentar_spawnar_carro() -> void:
	if carros_na_rota.size() >= max_carros_na_rota:
		return
	
	# Verifica se o início da curva está livre (sem carro nos primeiros 16 metros)
	for c in carros_na_rota:
		var fol: PathFollow3D = c.get("follow")
		if is_instance_valid(fol) and fol.progress < 16.0:
			return # Início ocupado, espera o próximo ciclo
	
	if not CarroManager:
		return
	
	var carro_info = CarroManager.pick_carro()
	if carro_info.is_empty():
		return
	
	var cena_carro: PackedScene = carro_info["cena"]
	var carro_index: int = carro_info["index"]
	
	var follow := PathFollow3D.new()
	follow.loop = false
	follow.rotation_mode = PathFollow3D.ROTATION_NONE
	follow.use_model_front = false
	follow.progress = 0.0
	add_child(follow)
	
	var holder := Node3D.new()
	holder.name = "CarHolder"
	follow.add_child(holder)
	
	var inst := cena_carro.instantiate() as Node3D
	holder.add_child(inst)
	
	# Ajuste de escala e calibração
	var rot_offset = yaw_offset_graus
	# Alguns modelos .obj podem precisar de rotação de 180°
	holder.rotation.y = deg_to_rad(rot_offset)
	
	# Registra os dados do veículo
	var dados = {
		"follow": follow,
		"holder": holder,
		"inst": inst,
		"index": carro_index,
		"velocidade_atual": 0.0,
		"velocidade_desejada": velocidade_maxima * randf_range(0.92, 1.08),
		"tempo_parado": 0.0,
		"ja_buzinou_parado": false,
		"engine_audio": inst.get_node_or_null("EngineAudio") as AudioStreamPlayer3D,
		"horn_audio": inst.get_node_or_null("HornAudio") as AudioStreamPlayer3D,
		"rodas": []
	}
	
	# Localiza rodas se houver nós separados (ex: Suspicious Car)
	for child in inst.get_children():
		if "wheel" in child.name.to_lower():
			dados["rodas"].append(child)
	
	carros_na_rota.append(dados)
	CarroManager.registrar_carro_ativo(dados)

func _physics_process(delta: float) -> void:
	if carros_na_rota.is_empty():
		return
	
	var length_total: float = curve.get_baked_length() if curve else 100.0
	var para_remover: Array[Dictionary] = []
	
	# Ordena por progresso na rota para identificar o carro imediatamente à frente
	carros_na_rota.sort_custom(func(a, b): 
		var fa = a["follow"].progress if is_instance_valid(a.get("follow")) else 0.0
		var fb = b["follow"].progress if is_instance_valid(b.get("follow")) else 0.0
		return fa > fb
	)
	
	for i in range(carros_na_rota.size()):
		var c = carros_na_rota[i]
		var follow: PathFollow3D = c.get("follow")
		var holder: Node3D = c.get("holder")
		
		if not is_instance_valid(follow) or not is_instance_valid(holder):
			para_remover.append(c)
			continue
		
		var prog = follow.progress
		var vel_alvo = c["velocidade_desejada"]
		
		# 1. Distanciamento Seguro com o carro à frente na mesma rota
		if i > 0:
			var carro_frente = carros_na_rota[i - 1]
			var fol_frente: PathFollow3D = carro_frente.get("follow")
			if is_instance_valid(fol_frente):
				var dist_gap = fol_frente.progress - prog
				if dist_gap < distancia_seguranca:
					var ratio_espaco = clamp((dist_gap - 3.5) / (distancia_seguranca - 3.5), 0.0, 1.0)
					vel_alvo = min(vel_alvo, c["velocidade_desejada"] * ratio_espaco)
		
		# 2. Verificação de Semáforos
		vel_alvo = _checar_semaforo(prog, vel_alvo)
		
		# 3. Lógica de Buzina Ocasional
		var vel_atual: float = c["velocidade_atual"]
		if vel_atual < 0.8:
			c["tempo_parado"] += delta
			if c["tempo_parado"] > 3.5 and not c["ja_buzinou_parado"]:
				c["ja_buzinou_parado"] = true
				if randf() < 0.22: # 22% de chance de buzinar na fila
					_tocar_buzina(c)
		else:
			c["tempo_parado"] = 0.0
			c["ja_buzinou_parado"] = false
		
		# 4. Aceleração e Frenagem suave
		var taxa = frenagem if vel_alvo < vel_atual else aceleracao
		c["velocidade_atual"] = move_toward(vel_atual, vel_alvo, taxa * delta)
		vel_atual = c["velocidade_atual"]
		
		# 5. Avança o carro na curva
		follow.progress += vel_atual * delta
		
		# 6. Gira rodas se houver nós separados
		for r in c["rodas"]:
			if is_instance_valid(r):
				r.rotate_x(vel_atual / 0.35 * delta)
		
		# 7. Orientação suave pela tangente da curva
		_orientar_carro(follow, holder, prog)
		
		# 8. Chegada ao final da rota
		if follow.progress_ratio >= 0.996 or follow.progress >= (length_total - 1.0):
			para_remover.append(c)
	
	# Remove e devolve ao pool os carros que completaram o percurso
	for rem in para_remover:
		_finalizar_carro(rem)

func _checar_semaforo(prog: float, vel_alvo_atual: float) -> float:
	# Cruzamento 1
	if ponto_parada_cruzamento1_m > 0.0:
		var dist_sem1 = ponto_parada_cruzamento1_m - prog
		if dist_sem1 > 0.0 and dist_sem1 <= distancia_frenagem_semaforo:
			var sem1 = get_tree().get_first_node_in_group("controladores_semaforo")
			if sem1 and sem1.has_method("is_vermelho") and sem1.is_vermelho():
				var ratio = clamp((dist_sem1 - 2.5) / (distancia_frenagem_semaforo - 2.5), 0.0, 1.0)
				return min(vel_alvo_atual, vel_alvo_atual * ratio)
	
	# Cruzamento 2
	if ponto_parada_cruzamento2_m > 0.0:
		var dist_sem2 = ponto_parada_cruzamento2_m - prog
		if dist_sem2 > 0.0 and dist_sem2 <= distancia_frenagem_semaforo:
			var sem2 = get_tree().get_first_node_in_group("semaforos_poste_completo")
			if sem2 and sem2.has_method("is_vermelho") and sem2.is_vermelho():
				var ratio2 = clamp((dist_sem2 - 2.5) / (distancia_frenagem_semaforo - 2.5), 0.0, 1.0)
				return min(vel_alvo_atual, vel_alvo_atual * ratio2)
	
	return vel_alvo_atual

func _orientar_carro(follow: PathFollow3D, holder: Node3D, prog: float) -> void:
	if not curve:
		return
	var sample_dist = min(prog + 0.8, curve.get_baked_length())
	var pt_a = curve.sample_baked(prog)
	var pt_b = curve.sample_baked(sample_dist)
	var dir = pt_b - pt_a
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		var yaw = atan2(dir.x, dir.z)
		holder.global_rotation.y = yaw + deg_to_rad(yaw_offset_graus)

func _tocar_buzina(c: Dictionary) -> void:
	var h: AudioStreamPlayer3D = c.get("horn_audio")
	if is_instance_valid(h):
		h.pitch_scale = randf_range(0.94, 1.06)
		h.play()

func _finalizar_carro(c: Dictionary) -> void:
	carros_na_rota.erase(c)
	if CarroManager:
		CarroManager.desregistrar_carro_ativo(c)
		CarroManager.liberar_carro(c["index"])
	
	var follow: PathFollow3D = c.get("follow")
	if is_instance_valid(follow):
		follow.queue_free()
