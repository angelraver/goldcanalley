extends Control

const CARPETA_PREMIOS = "res://images/prizes/"

@onready var imagen_juguete: TextureRect = $PanelPremio/ImagenJuguete
@onready var boton_pantalla: Button = $BotonPantalla


func _ready() -> void:
	# Cargar la imagen del premio pendiente
	var nombre_premio = SaveManager.premio_recien_desbloqueado
	var ruta_imagen = CARPETA_PREMIOS + nombre_premio + ".png"

	if ResourceLoader.exists(ruta_imagen):
		imagen_juguete.texture = load(ruta_imagen)

	# Al presionar en cualquier parte de la pantalla, limpia el estado y vuelve a selección de niveles
	if boton_pantalla:
		boton_pantalla.pressed.connect(_on_pantalla_pressed)


func _on_pantalla_pressed() -> void:
	# Consumir la alerta para que no se vuelva a mostrar
	SaveManager.premio_recien_desbloqueado = ""
	# Ir a la selección de niveles
	get_tree().change_scene_to_file("res://scenes/SeleccionNiveles.tscn")
