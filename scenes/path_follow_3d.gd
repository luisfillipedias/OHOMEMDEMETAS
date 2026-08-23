extends PathFollow3D

@export var velocidade_base: float = 2.0
@export var raio_visao_player: float = 6.0

var velocidade_atual: float = 2.0
var tempo_variacao: float = 0.0
var player: Node3D = null

var modelo_mesh: Node3D = null
var anim_player: AnimationPlayer = null

func _ready() -> void:
	# Encontra automaticamente o modelo do personagem dentro do PathFollow3D
	for child in get_children():
		if child is Node3D:
			modelo_mesh = child
			break
			
	if modelo_mesh:
		# Busca o AnimationPlayer dentro do modelo, não importa o nome
		anim_player = modelo_mesh.find_child("AnimationPlayer", true, false)
		if anim_player and anim_player.has_animation("mixamo_com"):
			anim_player.play("mixamo_com")
	
	player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	tempo_variacao += delta * 2.0
	velocidade_atual = velocidade_base + sin(tempo_variacao) * 0.8  
	progress += velocidade_atual * delta

	_checar_olhar_player()

func _checar_olhar_player() -> void:
	if not player or not modelo_mesh:
		return
		
	var distancia = global_position.distance_to(player.global_position)
	
	if distancia < raio_visao_player:
		var pos_alvo = player.global_position
		pos_alvo.y = global_position.y
		
		var direcao = global_position.direction_to(pos_alvo)
		if direcao.length_squared() > 0.001:
			modelo_mesh.basis = modelo_mesh.basis.slerp(Transform3D().looking_at(direcao).basis, 0.05)
	else:
		modelo_mesh.rotation.y = lerp_angle(modelo_mesh.rotation.y, 0.0, 0.05)
