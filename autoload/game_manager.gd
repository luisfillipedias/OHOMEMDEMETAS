extends Node

# =============================================
# GAME MANAGER — O Homem De Metas
# Singleton global para salvar/carregar estado,
# gerenciar flags de história e transições.
# =============================================

var story_flags: Dictionary = {}
var current_chapter: int = 0

func _ready() -> void:
	load_game()

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
