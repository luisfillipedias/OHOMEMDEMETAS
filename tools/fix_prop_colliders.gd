@tool
extends EditorScript

# Rodar 1x com scenes/chapter_01.tscn aberto e ativo no editor:
# Script Editor > abrir este arquivo > File > Run (Ctrl+Shift+X)
# Depois: Ctrl+S pra salvar a cena com as novas colisões.

const ALVOS := [
	"CefetExterior/busstop/busstop",
	"CefetExterior/busstop_alt2/busstop_alt",
	"busstop_graffiti/busstop_graffiti",
	"busstop_graffiti_round_roof2/busstop_graffiti_round_roof",
]

func _run() -> void:
	var scene := get_editor_interface().get_edited_scene_root()
	if not scene:
		push_error("Abra scenes/chapter_01.tscn no editor antes de rodar este script.")
		return

	for caminho in ALVOS:
		var node := scene.get_node_or_null(caminho)
		if node == null:
			push_warning("Não encontrado: %s" % caminho)
			continue

		# Remove o StaticBody3D antigo (colisão côncava/trimesh)
		var old_body := node.get_node_or_null("StaticBody3D")
		if old_body:
			old_body.queue_free()

		var mesh_inst := _achar_mesh_instance(node)
		if mesh_inst:
			mesh_inst.create_multiple_convex_collisions()
			print("[fix_prop_colliders] Colisão convexa gerada para: ", caminho)
		else:
			push_warning("MeshInstance3D não encontrado dentro de: %s" % caminho)

func _achar_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for filho in node.get_children():
		var achado := _achar_mesh_instance(filho)
		if achado:
			return achado
	return null
