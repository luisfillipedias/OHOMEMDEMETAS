extends PathFollow3D

@export var velocidade_base: float = 1.6
@export var raio_visao_player: float = 6.0
@export var desvio_maximo_graus: float = 20.0
@export var offset_orientacao_graus: float = 0.0

var velocidade_atual: float = 1.6
var tempo_variacao: float = 0.0
var player: Node3D = null
var modelo_mesh: Node3D = null
var angulo_atual: float = 0.0

func _ready() -> void:
	# Encontra o modelo 3D filho diretamente
	for child in get_children():
		if child is Node3D:
			modelo_mesh = child
			break

	# IMPORTANTE: NÃO seta root_motion_track — deixa o PathFollow3D controlar o movimento
	# root_motion_track faz o personagem mover pela animação, conflitando com o Tween do Path
	var anim_player = _achar_animation_player()
	if anim_player:
		var anims = anim_player.get_animation_list()
		if anims.size() > 0:
			var anim_name = "mixamo_com" if anim_player.has_animation("mixamo_com") else anims[0]
			anim_player.play(anim_name)
			# NÃO definir root_motion_track aqui — isso causava o teleporte!

	player = get_tree().get_first_node_in_group("player")

func _achar_animation_player() -> AnimationPlayer:
	# Busca recursivamente em todos os filhos
	for child in get_children():
		var ap = child.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			return ap
	return null

func _process(delta: float) -> void:
	if not is_instance_valid(modelo_mesh):
		for child in get_children():
			if child is Node3D:
				modelo_mesh = child
				break
	
	tempo_variacao += delta * 2.0
	velocidade_atual = velocidade_base + sin(tempo_variacao) * 0.64
	progress += velocidade_atual * delta

	_atualizar_rotacao()

func _atualizar_rotacao() -> void:
	if not is_instance_valid(modelo_mesh):
		return

	var offset_base = deg_to_rad(offset_orientacao_graus)

	# Tenta reencontrar o player se perdeu a referência
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if not is_instance_valid(player):
		angulo_atual = lerp_angle(angulo_atual, 0.0, 0.05)
		modelo_mesh.rotation.y = offset_base + angulo_atual
		return

	var distancia = global_position.distance_to(player.global_position)
	var desvio_alvo: float = 0.0

	if distancia < raio_visao_player and distancia > 0.1:
		var pos_alvo = player.global_position
		pos_alvo.y = global_position.y
		var direcao = global_position.direction_to(pos_alvo)

		# Protege contra vetor zero (jogador na mesma posição exata)
		if direcao.length_squared() > 0.001:
			var angulo_player = atan2(direcao.x, direcao.z)
			var diferenca = wrapf(angulo_player - offset_base, -PI, PI)
			var limite = deg_to_rad(desvio_maximo_graus)
			desvio_alvo = clamp(diferenca, -limite, limite)

	angulo_atual = lerp_angle(angulo_atual, desvio_alvo, 0.04)
	modelo_mesh.rotation.y = offset_base + angulo_atual