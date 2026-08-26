extends Node3D

# ============================================================
# INVISIBLE WALL — bloqueia fisicamente a Alice (via um
# StaticBody3D filho) e dispara um pensamento contextual dela
# quando se aproxima (via um Area3D filho), sem empurrar ela
# pra trás — ela só para de andar, exatamente como bater numa
# parede de verdade.
#
# ESTRUTURA ESPERADA (montar na cena, no editor):
#   Node3D  <- este script aqui
#     StaticBody3D          (bloqueio físico de verdade)
#       CollisionShape3D    (BoxShape3D cobrindo o limite)
#     Area3D                (só detecta a aproximação p/ falar)
#       CollisionShape3D    (mesmo tamanho, ou ~0.3m maior)
# ============================================================

@export_multiline var mensagem: String = "(não posso ir por aí.)"
@export var cooldown: float = 4.0
@export var debug_mode: bool = false

var _last_trigger_msec: int = -999999

func _ready() -> void:
	for child in get_children():
		if child is Area3D:
			# Configura o Area3D para detectar o jogador
			child.collision_layer = 0
			child.collision_mask = 1  # Detecta qualquer coisa na layer 1 (padrão)
			child.body_entered.connect(_on_body_entered)
			if debug_mode:
				print("[InvisibleWall] Area3D configurado para detectar colisões. Collision mask: ", child.collision_mask)

func _on_body_entered(body: Node3D) -> void:
	if debug_mode:
		print("[InvisibleWall] Body entrou: ", body.name, " - É player? ", body.is_in_group("player"))
	
	if not body.is_in_group("player"):
		return
	var now := Time.get_ticks_msec()
	if now - _last_trigger_msec < int(cooldown * 1000.0):
		if debug_mode:
			print("[InvisibleWall] Cooldown ativo, ignorando")
		return
	_last_trigger_msec = now

	if debug_mode:
		print("[InvisibleWall] Disparando mensagem: ", mensagem)

	var chapter := get_tree().get_first_node_in_group("chapter")
	if chapter and chapter.has_method("show_boundary_thought"):
		chapter.show_boundary_thought(mensagem)