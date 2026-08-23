extends Node3D

# ============================================================
# INTERACTABLE — Homem De Metas
# Script base para qualquer objeto interagível no mundo
# Herde este script e sobrescreva on_interact()
# ============================================================

@export var interaction_hint: String = "Examinar"
@export var single_use: bool = false
@export var flag_to_set: String = ""

var used: bool = false

func interact() -> void:
	if single_use and used:
		return
	used = true
	if flag_to_set != "":
		GameManager.set_flag(flag_to_set)
	on_interact()

# Sobrescreva nas cenas específicas
func on_interact() -> void:
	pass
