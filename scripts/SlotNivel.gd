extends Control

signal nivel_seleccionado(numero_nivel: int)

@onready var boton_nivel: TextureButton = $BotonNivel
@onready var label_numero: Label = $BotonNivel/LabelNumero
@onready var ribbon_amarilla: TextureRect = $ContenedorRibbons/RibbonAmarilla
@onready var ribbon_roja: TextureRect = $ContenedorRibbons/RibbonRoja
@onready var ribbon_azul: TextureRect = $ContenedorRibbons/RibbonAzul

var nivel_id: int = 1


func _ready() -> void:
	if boton_nivel:
		boton_nivel.pressed.connect(func(): nivel_seleccionado.emit(nivel_id))


func configurar(numero_nivel: int) -> void:
	nivel_id = numero_nivel
	var desbloqueado = SaveManager.es_nivel_desbloqueado(numero_nivel)

	if not desbloqueado:
		# Si está bloqueado: ocultamos el botón y los ribbons
		visible = true
		boton_nivel.visible = false
		ocultar_ribbons()
		return

	# Si está desbloqueado: mostramos botón y texto
	boton_nivel.visible = true
	label_numero.text = str(numero_nivel)

	# Leer los datos de guardado para este nivel
	var puntaje = SaveManager.obtener_puntaje_nivel(numero_nivel)
	var maximo = SaveManager.obtener_maximo_nivel(numero_nivel)

	if maximo > 0 and puntaje > 0:
		var umbral_1 = maximo * (1.0 / 3.0)
		var umbral_2 = maximo * (2.0 / 3.0)
		var umbral_3 = float(maximo)

		ribbon_amarilla.visible = (puntaje >= umbral_1)
		ribbon_roja.visible = (puntaje >= umbral_2)
		ribbon_azul.visible = (puntaje >= umbral_3)
	else:
		ocultar_ribbons()


func ocultar_ribbons() -> void:
	if ribbon_amarilla: ribbon_amarilla.visible = false
	if ribbon_roja: ribbon_roja.visible = false
	if ribbon_azul: ribbon_azul.visible = false
