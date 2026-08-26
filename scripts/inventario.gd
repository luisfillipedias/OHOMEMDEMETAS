extends Node

# ============================================================
# INVENTARIO - Singleton Global
# Gerencia todos os itens do jogador.
# ============================================================

signal item_adicionado(dados: Dictionary)
signal item_removido(id: String)

var itens: Array[Dictionary] = []

func _ready() -> void:
	# Item inicial: Cópias de Documentos
	_adicionar_sem_sinal({
		"id": "copias_documentos",
		"nome": "Cópias de Documentos",
		"descricao": "Cópias autenticadas dos seus documentos pessoais para matrícula no CEFET.",
		"mesh_path": "res://scenes/props/item_copias_documentos.tscn",
	})

func adicionar_item(id: String, nome: String, descricao: String = "", mesh_path: String = "") -> void:
	for item in itens:
		if item["id"] == id:
			return
	var dados := {
		"id": id,
		"nome": nome,
		"descricao": descricao,
		"mesh_path": mesh_path,
	}
	itens.append(dados)
	item_adicionado.emit(dados)

func remover_item(id: String) -> void:
	for i in range(itens.size()):
		if itens[i]["id"] == id:
			itens.remove_at(i)
			item_removido.emit(id)
			return

func get_itens() -> Array[Dictionary]:
	return itens

func tem_item(id: String) -> bool:
	for item in itens:
		if item["id"] == id:
			return true
	return false

func usar_item(id: String) -> void:
	pass

func _adicionar_sem_sinal(dados: Dictionary) -> void:
	itens.append(dados)
