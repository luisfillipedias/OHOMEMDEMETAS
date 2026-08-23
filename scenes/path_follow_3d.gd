extends PathFollow3D

@export var velocidade_base: float = 2.0
@export var raio_visao_player: float = 6.0

var velocidade_atual: float = 2.0
var tempo_variacao: float = 0.0
var player: Node3D = null

var modelo_mesh: Node3D = null
var anim_player: AnimationPlayer = null

# Guarda o ângulo Y como um número simples, não como Basis —
# isso elimina de vez o drift que causava os 258 erros
var angulo_atual: float = 0.0

func _ready() -> void:
	for child in get_children():
		if child is Node3D:
			modelo_mesh = child
			break

	if modelo_mesh:
		anim_player = modelo_mesh.find_child("AnimationPlayer", true, false)
		if anim_player:
			# Toca a primeira animação disponível, seja qual for o nome
			var anims = anim_player.get_animation_list()
			if anims.size() > 0:
				anim_player.play(anims[0])
				# ROOT MOTION: extrai a translação do quadril da animação,
				# pra ela parar de "andar sozinha" e só o Path3D mover o personagem
				var root_bone_path = _achar_root_bone(anim_player)
				if root_bone_path != NodePath():
					anim_player.root_motion_track = root_bone_path

	player = get_tree().get_first_node_in_group("player")

func _achar_root_bone(ap: AnimationPlayer) -> NodePath:
	var anims = ap.get_animation_list()
	if anims.size() == 0:
		return NodePath()
	var anim = ap.get_animation(anims[0])
	for i in anim.get_track_count():
		var path = str(anim.track_get_path(i))
		if "Hips" in path or "hip" in path.to_lower() or "mixamorig" in path.to_lower():
			return anim.track_get_path(i)
	return NodePath()

func _process(delta: float) -> void:
	tempo_variacao += delta * 2.0
	velocidade_atual = velocidade_base + sin(tempo_variacao) * 0.8
	progress += velocidade_atual * delta

	_checar_olhar_player(delta)

func _checar_olhar_player(delta: float) -> void:
	if not player or not modelo_mesh:
		return

	var distancia = global_position.distance_to(player.global_position)
	var angulo_alvo: float

	if distancia < raio_visao_player:
		var pos_alvo = player.global_position
		pos_alvo.y = global_position.y
		var direcao = global_position.direction_to(pos_alvo)
		if direcao.length_squared() > 0.001:
			angulo_alvo = atan2(direcao.x, direcao.z)
		else:
			angulo_alvo = angulo_atual
	else:
		angulo_alvo = 0.0  # olha de volta pra frente do caminho

	# lerp_angle em cima de um FLOAT nunca perde normalização — resolve os 258 erros de vez
	angulo_atual = lerp_angle(angulo_atual, angulo_alvo, 0.05)
	modelo_mesh.rotation.y = angulo_atual
