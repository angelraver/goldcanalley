extends Control

func _on_boton_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SeleccionNiveles.tscn")
