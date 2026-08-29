extends Node3D

# ============================================================
# PENSAMENTO_ESTATUA.GD
# Mostra hint [E] Examinar quando Alice se aproxima da estatua.
# Ao pressionar E, exibe o pensamento de Alice.
#
# ESTRUTURA ESPERADA na cena:
#   Node3D  <- este script   (ex: "PensamentoEstatua")
#     Area3D
#       CollisionShape3D  (SphereShape3D, raio ~2.5m)
# ============================================================

@export_multiline var mensagem: String = "(JK? Quem era esse?)"
@export var hint_text: String = "Examinar"
@export var cooldown: float = 0.0
@export var interaction_radius: float = 1.0
@export var debug_mode: bool = true

var _player_inside: bool = false
var _last_trigger_msec: int = -999999
var _player_ref: CharacterBody3D = null
var _hint_was_shown: bool = false
var _cached_chapter: Node = null

func _ready() -> void:
	if debug_mode:
		print("[PensamentoEstatua] _ready() iniciado — nó: ", name, " | caminho: ", get_path())
	var found_area: bool = false
	for child in get_children():
		if child is Area3D:
			found_area = true
			# ===== CONFIGURAÇÃO PROVADA — IGUAL AO invisible_wall.gd =====
			# PlayerController está na collision_layer = 2 (verificado em chapter_01.tscn linha 2909)
			# mask = 3 em binário = 0b11 → cobre layers 1 E 2, então DETECTA o jogador!
			child.collision_layer = 0
			child.collision_mask = 3
			child.monitoring = true
			child.monitorable = true
			if not child.body_entered.is_connected(_on_body_entered):
				child.body_entered.connect(_on_body_entered)
			if not child.body_exited.is_connected(_on_body_exited):
				child.body_exited.connect(_on_body_exited)
			if debug_mode:
				var cm := int(child.collision_mask)
				var cl := int(child.collision_layer)
				print("[PensamentoEstatua] Area3D encontrado: '", child.name,
					  "' | collision_layer=", cl,
					  " | collision_mask=", cm,
					  " (camadas detectadas: ", _descrever_layers(cm), ")")
			# ====== CORREÇÃO DO COLLISION SHAPE ======
			# No .tscn, o CollisionShape3D da área tem:
			#   - raio = 0.40m (MUITO pequeno)
			#   - offset X=0.49m (deslocado para a direita)
			# Isso faz a área ficar DENTRO do próprio collider físico da estátua!
			# Corrigimos em runtime: substituímos por uma esfera de raio 2.2m, CENTRALIZADA.
			var shape_node: CollisionShape3D = child.get_node_or_null("CollisionShape3D")
			if shape_node == null:
				for nested in child.get_children():
					if nested is CollisionShape3D:
						shape_node = nested
						break
			if shape_node:
				var old_shape := shape_node.shape
				var old_radius: float = 0.0
				var old_name: String = "ShapeDesconhecido"
				if old_shape is SphereShape3D:
					old_radius = (old_shape as SphereShape3D).radius
					old_name = "SphereShape3D"
				elif old_shape is CapsuleShape3D:
					old_radius = (old_shape as CapsuleShape3D).radius
					old_name = "CapsuleShape3D"
				elif old_shape is BoxShape3D:
					old_name = "BoxShape3D"
				# Centraliza (remove deslocamento 0.49m em X do arquivo .tscn)
				if shape_node.transform.origin != Vector3.ZERO:
					if debug_mode:
						print("[PensamentoEstatua] CollisionShape3D deslocado: ",
							  shape_node.transform.origin, " → resetando para Vector3.ZERO")
					shape_node.transform = Transform3D.IDENTITY
				# Força um SphereShape3D de raio = interaction_radius (configurável no Inspector)
				var RAIO_ALVO: float = max(0.5, interaction_radius)
				if old_shape == null or not (old_shape is SphereShape3D) or old_radius < 0.5:
					var nova_esfera := SphereShape3D.new()
					nova_esfera.radius = RAIO_ALVO
					shape_node.shape = nova_esfera
					if debug_mode:
						print("[PensamentoEstatua] Shape TROCADO: ", old_name,
							  " (r=", old_radius, ") → SphereShape3D (r=", RAIO_ALVO, "m)")
				else:
					var sph = old_shape as SphereShape3D
					if abs(sph.radius - RAIO_ALVO) > 0.01:
						sph.radius = RAIO_ALVO
						if debug_mode:
							print("[PensamentoEstatua] SphereShape3D ajustado: r=", old_radius,
								  " → r=", sph.radius, "m")
			elif debug_mode:
				push_warning("[PensamentoEstatua] Area3D '", child.name,
							 "' não tem CollisionShape3D filho! Adicione um no editor.")
	if not found_area and debug_mode:
		push_warning("[PensamentoEstatua] ERRO: Nenhum filho Area3D encontrado em '", name,
					 "'. A cena deve ter: Node3D > Area3D > CollisionShape3D")

func _process(_delta: float) -> void:
	if _player_inside:
		var hint_full := "[E]  " + hint_text.to_upper()
		var ch := _get_chapter()
		if ch and ch.has_method("show_interact_hint"):
			ch.show_interact_hint(hint_full)
			_hint_was_shown = true
		else:
			var hud := _get_hud_direct()
			if hud and hud.has_method("show_interact_prompt"):
				hud.show_interact_prompt(hint_text)
				_hint_was_shown = true

func _on_body_entered(body: Node3D) -> void:
	if debug_mode:
		print("[PensamentoEstatua] body_entered disparado! body='", body.name,
			  "' | tipo=", body.get_class(),
			  " | groups=", body.get_groups())
	if not body.is_in_group("player"):
		if debug_mode:
			print("[PensamentoEstatua] body NÃO está no grupo 'player' — ignorando.")
		return
	_player_inside = true
	_player_ref = body as CharacterBody3D
	if debug_mode:
		print("[PensamentoEstatua] ✅ JOGADOR DETECTADO! _player_inside=true | ref=", _player_ref)
	var hint_full := "[E]  " + hint_text.to_upper()
	var ch := _get_chapter()
	if ch and ch.has_method("show_interact_hint"):
		ch.show_interact_hint(hint_full)
		_hint_was_shown = true
		if debug_mode:
			print("[PensamentoEstatua] show_interact_hint chamado via chapter: '", hint_full, "'")
	else:
		if debug_mode:
			push_warning("[PensamentoEstatua] NÃO achou chapter com show_interact_hint! " +
						 "Tentando fallback HUD...")
		var hud := _get_hud_direct()
		if hud and hud.has_method("show_interact_prompt"):
			hud.show_interact_prompt(hint_text)
			_hint_was_shown = true
			if debug_mode:
				print("[PensamentoEstatua] show_interact_prompt chamado DIRETAMENTE via HUD")

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	_player_ref = null
	_hint_was_shown = false
	if debug_mode:
		print("[PensamentoEstatua] ❌ Jogador SAIU da área.")
	var ch := _get_chapter()
	if ch and ch.has_method("hide_interact_hint"):
		ch.hide_interact_hint()
	else:
		var hud := _get_hud_direct()
		if hud and hud.has_method("hide_interact_prompt"):
			hud.hide_interact_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if not event.is_action_pressed("interact"):
		return
	if debug_mode:
		print("[PensamentoEstatua] 🔘 E pressionado! _player_inside=", _player_inside)
	if _player_ref and "is_frozen" in _player_ref and _player_ref.is_frozen:
		if debug_mode:
			print("[PensamentoEstatua] player está is_frozen — bloqueando input.")
		return
	var dui := _get_dialogue_ui()
	if dui and dui.has_method("is_active") and dui.is_active():
		if debug_mode:
			print("[PensamentoEstatua] já existe dialogue ativo — bloqueando.")
		return

	var now := Time.get_ticks_msec()
	var cd_msec := int(cooldown * 1000.0)
	if now - _last_trigger_msec < cd_msec:
		if debug_mode:
			print("[PensamentoEstatua] cooldown! faltam ",
				  (cd_msec - (now - _last_trigger_msec)) / 1000.0, "s")
		return
	_last_trigger_msec = now
	if debug_mode:
		print("[PensamentoEstatua] 📢 EXIBINDO PENSAMENTO: ", mensagem)

	var ch := _get_chapter()
	if ch and ch.has_method("show_boundary_thought"):
		ch.show_boundary_thought(mensagem)
	elif dui and dui.has_method("start_dialogue"):
		if debug_mode:
			print("[PensamentoEstatua] fallback: start_dialogue DIRETO no DialogueUI")
		dui.start_dialogue([
			{"speaker": "Alice", "text": mensagem, "thought": true}
		], false)
	else:
		if debug_mode:
			push_error("[PensamentoEstatua] NÃO consegui exibir o pensamento! " +
					   "Nem chapter.show_boundary_thought nem DialogueUI.start_dialogue existem.")

# ============================================================
# HELPERS
# ============================================================

func _get_chapter() -> Node:
	if _cached_chapter and is_instance_valid(_cached_chapter):
		return _cached_chapter
	_cached_chapter = get_tree().get_first_node_in_group("chapter")
	return _cached_chapter

func _get_hud_direct() -> CanvasLayer:
	var ch := _get_chapter()
	if ch:
		var hud = ch.get_node_or_null("HUD")
		if hud:
			return hud as CanvasLayer
	return get_tree().root.get_node_or_null("*HUD") as CanvasLayer

func _get_dialogue_ui() -> CanvasLayer:
	var ch := _get_chapter()
	if ch:
		if ch.has_method("dialogue_ui"):
			var dui_prop = ch.get("dialogue_ui")
			if dui_prop and is_instance_valid(dui_prop):
				return dui_prop as CanvasLayer
		var dui = ch.get_node_or_null("DialogueUI")
		if dui:
			return dui as CanvasLayer
	return get_tree().root.get_node_or_null("*DialogueUI") as CanvasLayer

func _descrever_layers(mask: int) -> String:
	var result: String = ""
	for i in range(32):
		if mask & (1 << i) != 0:
			if result != "":
				result += ","
			result += str(i + 1)
	return "[" + (result if result != "" else "nenhuma") + "]"
