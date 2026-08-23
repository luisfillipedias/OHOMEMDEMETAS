extends Node

# ============================================================
# GERENCIADOR GLOBAL DE PEDESTRES - O HOMEM DE METAS
# ============================================================
# Carrega automaticamente todas as cenas (.tscn, .fbx, .glb)
# de pedestres e sorteia para as 3 rotas sem repetições simultâneas.

var modelos_pedestres: Array[PackedScene] = []
var em_uso: Dictionary = {}
var ultimo_usado_global: int = -1

func _ready() -> void:
	carregar_modelos()

func carregar_modelos() -> void:
	modelos_pedestres.clear()
	
	# Pastas onde o usuário pode guardar os personagens
	var pastas_busca = [
		"res://scenes/characters/pedestres",
		"res://scenes/characters",
		"res://assets/models/_caracters/pedestres"
	]
	
	for pasta in pastas_busca:
		_varrer_pasta(pasta)

func _varrer_pasta(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext = file_name.get_extension().to_lower()
			if ext == "tscn" or ext == "scn":
				var full_path = dir_path + "/" + file_name
				var scn = load(full_path) as PackedScene
				if scn and not modelos_pedestres.has(scn):
					modelos_pedestres.append(scn)
		file_name = dir.get_next()
	dir.list_dir_end()

func pick_pedestre() -> Dictionary:
	if modelos_pedestres.is_empty():
		carregar_modelos()
	if modelos_pedestres.is_empty():
		return {}
	
	var candidatos: Array[int] = []
	for i in range(modelos_pedestres.size()):
		if not em_uso.get(i, false) and i != ultimo_usado_global:
			candidatos.append(i)
	
	# Se todos estiverem ocupados ou só restar o último usado
	if candidatos.is_empty():
		for i in range(modelos_pedestres.size()):
			if not em_uso.get(i, false):
				candidatos.append(i)
	
	if candidatos.is_empty():
		return {} # Todos estão andando na rua neste momento
	
	var escolhido = candidatos.pick_random()
	em_uso[escolhido] = true
	ultimo_usado_global = escolhido
	return {"index": escolhido, "cena": modelos_pedestres[escolhido]}

func liberar_pedestre(index: int) -> void:
	em_uso[index] = false