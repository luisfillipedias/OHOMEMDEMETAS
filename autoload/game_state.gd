extends Node

# ============================================================
# GAME STATE — Singleton autoload
# Persist entre cenas: fase, horário, itens, estados
# ============================================================

# Tempo do jogo (ex: 20:35 => chapter 1)
var current_hour: int = 20
var current_minute: int = 35

# --- Sensibilidade do mouse -----------------------------------
# Mesma unidade usada em player_controller.gd (radianos por pixel
# de movimento relativo do mouse, antes do multiplicador de FOV/zoom).
const MOUSE_SENS_MIN: float = 0.0006
const MOUSE_SENS_MAX: float = 0.0050
const MOUSE_SENS_DEFAULT: float = 0.0018

var mouse_sensitivity: float = MOUSE_SENS_DEFAULT

# Item na mão do player
var held_item: String = ""

# Progresso
var chapter: int = 1
var flags: Dictionary = {}

# UI / Celular
var phone_unlocked: bool = false
var messages: Dictionary = {}

const SETTINGS_PATH: String = "user://settings.cfg"

func _ready() -> void:
	load_settings()

func set_time(h: int, m: int) -> void:
	current_hour = h
	current_minute = m

func get_time_string() -> String:
	return "%02d:%02d" % [current_hour, current_minute]

# Define a sensibilidade (já limitada ao range válido) e persiste em disco.
func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clamp(value, MOUSE_SENS_MIN, MOUSE_SENS_MAX)
	save_settings()

# Converte a sensibilidade "crua" para uma porcentagem 0-100+ amigável pra UI.
func get_mouse_sensitivity_percent() -> int:
	return int(round((mouse_sensitivity / MOUSE_SENS_DEFAULT) * 100.0))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	# Carrega o que já existe primeiro, pra não sobrescrever outras chaves
	# (volume, fullscreen etc.) caso este método seja chamado isoladamente.
	cfg.load(SETTINGS_PATH)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err == OK:
		mouse_sensitivity = clamp(
			cfg.get_value("controls", "mouse_sensitivity", MOUSE_SENS_DEFAULT),
			MOUSE_SENS_MIN, MOUSE_SENS_MAX
		)

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
