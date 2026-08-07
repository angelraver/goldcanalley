extends Control

@onready var button_options: TextureButton = $Options
const ESCENA_FLOR_LUZ_UI = preload("res://scenes/EfectoFlorLuzUI.tscn")

func _on_boton_start_pressed() -> void:
	AudioManager.play_start()
	get_tree().change_scene_to_file("res://scenes/SeleccionNiveles.tscn")

func _on_boton_prizes_pressed() -> void:
	AudioManager.play_start()
	get_tree().change_scene_to_file("res://scenes/Premios.tscn")
	
func _on_boton_options_pressed() -> void:
	AudioManager.play_start()
	mostrar_con_efecto_2d(button_options)

func mostrar_con_efecto_2d(elemento_ui: Control) -> void:
	elemento_ui.visible = true
	var efecto = ESCENA_FLOR_LUZ_UI.instantiate() as Control
	elemento_ui.get_parent().add_child(efecto)
	await get_tree().process_frame
	#var centro_objetivo = elemento_ui.global_position + (elemento_ui.size / -100)
	var centro_objetivo = elemento_ui.global_position - Vector2(33.0, 50)
	print(centro_objetivo)
	# - (elemento_ui.size / 500)
	# + (elemento_ui.size / -100)
	#print(elemento_ui.global_position)
	efecto.global_position = centro_objetivo
	# - (efecto.size / 2.0)
	efecto.arrancar_efecto()
