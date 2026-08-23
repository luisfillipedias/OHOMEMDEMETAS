extends Node

# ============================================================
# GAME STATE — Singleton autoload
# Persist entre cenas: fase, horário, itens, estados
# ============================================================

# Tempo do jogo (ex: 20:35 => chapter 1)
var current_hour: int = 20
var current_minute: int = 35

var mouse_sensitivity: float = 0.0018

# Item na mão do player
var held_item: String = ""

# Progresso
var chapter: int = 1
var flags: Dictionary = {}

# UI / Celular
var phone_unlocked: bool = false
var messages: Dictionary = {}

func set_time(h: int, m: int) -> void:
	current_hour = h
	current_minute = m

func get_time_string() -> String:
	return "%02d:%02d" % [current_hour, current_minute]

func pick_up_item(item_name: String) -> void:
	held_item = item_name

func drop_item() -> void:
	held_item = ""

func has_item(item_name: String) -> bool:
	return held_item == item_name

func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value

func get_flag(key: String, default: Variant = false) -> Variant:
	return flags.get(key, default)

func add_message(contact: String, msg_data: Dictionary) -> void:
	if not messages.has(contact):
		messages[contact] = []
	messages[contact].append(msg_data)
