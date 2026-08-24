extends Node

# ============================================================
# GERENCIADOR GLOBAL DE PEDESTRES - O HOMEM DE METAS
# Varre RECURSIVAMENTE todas as subpastas em busca de .tscn
# ============================================================

var modelos_pedestres: Array[PackedScene] = []
var em_uso: Dictionary = {}
var ultimo_usado_global: int = -1

func _ready() -> void:
	randomize()
	carregar_modelos()
	var count = modelos_pedestres.size()
	print("PedestreManager: %d modelos carregados no pool." % count)

func carregar_modelos() -> void:
	modelos_pedestres.clear()
	
	# Varre RECURSIVAMENTE a partir dessas raízes
	var raizes_busca = [
		"res://scenes/characters/pedestres",
		"res://scenes/characters"
	]
	
	for raiz in raizes_busca:
		_varrer_recursivo(raiz)
	
	modelos_pedestres.shuffle()

func _varrer_recursivo(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = dir_path + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			# Recursa nas subpastas
			_varrer_recursivo(full_path)
		else:
			var ext = file_name.get_extension().to_lower()
			if ext == "tscn" or ext == "scn":
				if not ResourceLoader.exists(full_path):
					push_warning("PedestreManager: cena não encontrada: %s" % full_path)
					file_name = dir.get_next()
					continue
				var scn = load(full_path) as PackedScene
				if scn and not modelos_pedestres.has(scn):
					modelos_pedestres.append(scn)
				elif not scn:
					push_warning("PedestreManager: falha ao carregar %s (verifique texturas/dependências)." % full_path)
		
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
	
	# Fallback: se todos estiverem ocupados ou só restar o último
	if candidatos.is_empty():
		for i in range(modelos_pedestres.size()):
			if not em_uso.get(i, false):
				candidatos.append(i)
	
	if candidatos.is_empty():
		return {}
	
	candidatos.shuffle()
	var escolhido = candidatos.pick_random()
	em_uso[escolhido] = true
	ultimo_usado_global = escolhido
	return {"index": escolhido, "cena": modelos_pedestres[escolhido]}

func liberar_pedestre(index: int) -> void:
	em_uso[index] = false