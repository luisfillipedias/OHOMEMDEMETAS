extends Node

# ============================================================
# GERENCIADOR GLOBAL DE CARROS & TRÂNSITO - O HOMEM DE METAS
# Pool dinâmico de veículos e controle global de tráfego
# ============================================================

var modelos_carros: Array[PackedScene] = []
var em_uso: Dictionary = {}
var ultimo_usado_global: int = -1

# Lista de todos os veículos trafegando no momento (para cálculo de distância/anti-colisão)
var carros_ativos: Array[Dictionary] = []

func _ready() -> void:
	randomize()
	carregar_modelos()
	var count = modelos_carros.size()
	print("CarroManager: %d modelos de veículos carregados no pool." % count)

func carregar_modelos() -> void:
	modelos_carros.clear()
	var raizes_busca = [
		"res://scenes/vehicles"
	]
	for raiz in raizes_busca:
		_varrer_recursivo(raiz)
	modelos_carros.shuffle()

func _varrer_recursivo(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = dir_path + "/" + file_name
		if dir.current_is_dir() and not file_name.begins_with("."):
			_varrer_recursivo(full_path)
		else:
			var ext = file_name.get_extension().to_lower()
			if ext == "tscn" or ext == "scn":
				if not ResourceLoader.exists(full_path):
					file_name = dir.get_next()
					continue
				var scn = load(full_path) as PackedScene
				if scn and not modelos_carros.has(scn):
					modelos_carros.append(scn)
		file_name = dir.get_next()
	dir.list_dir_end()

func pick_carro() -> Dictionary:
	if modelos_carros.is_empty():
		carregar_modelos()
	if modelos_carros.is_empty():
		return {}
	
	var candidatos: Array[int] = []
	for i in range(modelos_carros.size()):
		if not em_uso.get(i, false) and i != ultimo_usado_global:
			candidatos.append(i)
	
	if candidatos.is_empty():
		for i in range(modelos_carros.size()):
			if not em_uso.get(i, false):
				candidatos.append(i)
	
	if candidatos.is_empty():
		return {}
	
	candidatos.shuffle()
	var escolhido = candidatos.pick_random()
	em_uso[escolhido] = true
	ultimo_usado_global = escolhido
	return {"index": escolhido, "cena": modelos_carros[escolhido]}

func liberar_carro(index: int) -> void:
	em_uso[index] = false

func registrar_carro_ativo(dados_carro: Dictionary) -> void:
	if not carros_ativos.has(dados_carro):
		carros_ativos.append(dados_carro)

func desregistrar_carro_ativo(dados_carro: Dictionary) -> void:
	carros_ativos.erase(dados_carro)
