extends Node3D

func set_board_color(color_hex: String) -> void:
	if not color_hex.begins_with("#"):
		color_hex = "#" + color_hex
		
	var new_color = Color(color_hex)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = new_color
	
	# Buscar la primera MeshInstance3D dentro del nodo 'board'
	var mesh_node = _find_mesh_instance($board)
	if mesh_node:
		mesh_node.set_surface_override_material(0, mat)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found:
			return found
	return null
