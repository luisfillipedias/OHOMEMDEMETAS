extends PathFollow3D

@export var velocidade_base: float = 1.6
@export var raio_visao_player: float = 6.0
@export var desvio_maximo_graus: float = 20.0
@export var offset_orientacao_graus: float = 180.0

var velocidade_atual: float = 1.6
var tempo_variacao: float = 0.0
var player: Node3D = null

var modelo_mesh: Node3D = null
var anim_player: AnimationPlayer = null
var angulo_atual: float = 0.0

func _ready() -> void:
	for child in get_children():
		if child is Node3D:
			modelo_mesh = child
			break

	if modelo_mesh:
		anim_player = modelo_mesh.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player:
			var anims = anim_player.get_animation_list()
			if anims.size() > 0:
				anim_player.play(anims[0])
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
	if not modelo_mesh:
		for child in get_children():
			if child is Node3D:
				modelo_mesh = child
				break
	
	tempo_variacao += delta * 2.0
	velocidade_atual = velocidade_base + sin(tempo_variacao) * 0.64
	progress += velocidade_atual * delta

	_checar_olhar_player()

func _checar_olhar_player() -> void:
	if not is_instance_valid(modelo_mesh):
		return
		
	var offset_base = deg_to_rad(offset_orientacao_graus)

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		angulo_atual = lerp_angle(angulo_atual, 0.0, 0.05)
		modelo_mesh.rotation.y = offset_base + angulo_atual
		return

	var distancia = global_position.distance_to(player.global_position)
	var desvio_alvo: float = 0.0

	if distancia < raio_visao_player:
		var pos_alvo = player.global_position
		pos_alvo.y = global_position.y
		var direcao_player = global_position.direction_to(pos_alvo)

		if direcao_player.length_squared() > 0.001:
			var angulo_player = atan2(direcao_player.x, direcao_player.z)
			var diferenca = wrapf(angulo_player - offset_base, -PI, PI)
			var limite_rad = deg_to_rad(desvio_maximo_graus)
			desvio_alvo = clamp(diferenca, -limite_rad, limite_rad)

	angulo_atual = lerp_angle(angulo_atual, desvio_alvo, 0.04)
	modelo_mesh.rotation.y = offset_base + angulo_atual
