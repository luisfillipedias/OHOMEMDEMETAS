extends Node3D

# ============================================================
# PENSAMENTO_ESTATUA.GD
# Mostra hint [E] Examinar quando Alice se aproxima da estatua.
# Ao pressionar E, exibe o pensamento de Alice.
# ============================================================

@export_multiline var mensagem: String = "(JK? Quem era esse?)"
@export var hint_text: String = "Examinar"
@export var cooldown: float = 0.0

## Raio local de interação.
## Como a estátua tem escala 2.2x na cena, 0.55 local = ~1.2 metros no mundo real!
## Aumente para pegar de mais longe, diminua para ter que encostar mais perto.
@export var interaction_radius: float = 0.55

## Altura/offset do centro da esfera de interação (para alinhar com o tronco da estátua)
@export var interaction_height_offset: float = 0.5

@export var debug_mode: bool = false

var _player_inside: bool = false
var _last_trigger_msec: int = -999999
var _player_ref: CharacterBody3D = null
var _hint_was_shown: bool = false
var _cached_chapter: Node = null


func _ready() -> void:
	var found_area: bool = false
	for child in get_children():
		if child is Area3D:
			found_area = true
			child.collision_layer = 0
			child.collision_mask = 3
			child.monitoring = true
			child.monitorable = true
			if not child.body_entered.is_connected(_on_body_entered):
				child.body_entered.connect(_on_body_entered)
			if not child.body_exited.is_connected(_on_body_exited):
				child.body_exited.connect(_on_body_exited)

			var shape_node: CollisionShape3D = child.get_node_or_null("CollisionShape3D")
			if shape_node == null:
				for nested in child.get_children():
					if nested is CollisionShape3D:
						shape_node = nested
						break

			if shape_node:
				# Centraliza no eixo X e Z, ajusta Y para a altura do pedestal
				shape_node.position = Vector3(0.0, interaction_height_offset, 0.0)

				# Cria / ajusta a esfera com o raio calibrado
				var nova_esfera := SphereShape3D.new()
				nova_esfera.radius = max(0.2, interaction_radius)
				shape_node.shape = nova_esfera


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
	if not body.is_in_group("player"):
		return
	_player_inside = true
	_player_ref = body as CharacterBody3D

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


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	_player_ref = null
	_hint_was_shown = false

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

	if _player_ref and "is_frozen" in _player_ref and _player_ref.is_frozen:
		return

	var dui := _get_dialogue_ui()
	if dui and dui.has_method("is_active") and dui.is_active():
		return

	var now := Time.get_ticks_msec()
	var cd_msec := int(cooldown * 1000.0)
	if now - _last_trigger_msec < cd_msec:
		return
	_last_trigger_msec = now

	var ch := _get_chapter()
	if ch and ch.has_method("show_boundary_thought"):
		ch.show_boundary_thought(mensagem)
	elif dui and dui.has_method("start_dialogue"):
		dui.start_dialogue([
			{"speaker": "Alice", "text": mensagem, "thought": true}
		], false)


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
