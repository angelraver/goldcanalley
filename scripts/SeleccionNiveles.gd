extends Control


func _ready() -> void:
	refrescar_pantalla_niveles()


func refrescar_pantalla_niveles() -> void:
	# Recorremos los 9 slots que ya colocaste manualmente en el árbol de escenas
	for i in range(1, 10):
		var nombre_node = "SlotNivel" + str(i)
		
		# Buscamos el nodo por su nombre (SlotNivel1, SlotNivel2, etc.)
		if has_node(nombre_node):
			var slot = get_node(nombre_node)
			slot.configurar(i)
			
			# Conectamos la señal solo si no estaba conectada antes
			if not slot.nivel_seleccionado.is_connected(_on_nivel_seleccionado):
				slot.nivel_seleccionado.connect(_on_nivel_seleccionado)


func _on_nivel_seleccionado(numero_nivel: int) -> void:
	print("Cargando Nivel: ", numero_nivel)
	SaveManager.nivel_actual_seleccionado = numero_nivel
	get_tree().change_scene_to_file("res://scenes/main.tscn")
