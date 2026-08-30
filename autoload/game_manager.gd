extends Node

# =============================================
# GAME MANAGER – O Homem De Metas
# Singleton global para salvar/carregar estado,
# gerenciar flags de historia e transicoes.
# =============================================

var story_flags: Dictionary = {}
var current_chapter: int = 0

# ---- Configuracoes do jogador ----
# Brilho: 0.5 = minimo, 2.0 = maximo. Padrao 1.25 (ja um pouco mais claro)
var brightness: float = 1.25

func _ready() -> void:
	load_settings()
	load_game()

# ─── Persistencia de settings ──────────────────
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "brightness", brightness)
	cfg.save("user://settings.cfg")

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		brightness = cfg.get_value("video", "brightness", 1.25)

# ─── Aplica brilho no WorldEnvironment da cena ─
func apply_brightness(world_env: WorldEnvironment) -> void:
	if not world_env or not world_env.environment:
		return
	world_env.environment.tonemap_exposure = brightness

# ─── Story flags ───────────────────────────────
func set_flag(flag_name: String, value) -> void:
	story_flags[flag_name] = value

func get_flag(flag_name: String, default = false):
	return story_flags.get(flag_name, default)

func save_game() -> void:
	var file = FileAccess.open("user://save.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"story_flags": story_flags,
			"current_chapter": current_chapter
		}))

func load_game() -> void:
	if not FileAccess.file_exists("user://save.json"):
		return
	var file = FileAccess.open("user://save.json", FileAccess.READ)
	if file:
		var result = JSON.parse_string(file.get_as_text())
		if result and result is Dictionary:
			story_flags = result.get("story_flags", {})
			current_chapter = result.get("current_chapter", 0)

func change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
