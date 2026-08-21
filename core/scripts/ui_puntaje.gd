extends Control
class_name UIPuntaje

@export var texto_prefijo: String = "SCORE\n"
@export var digitos_minimos: int = 4

@onready var label: Label = $Label

var puntaje_actual: int = 0

func _ready() -> void:
	actualizar_ui()

func establecer_puntaje(nuevo_puntaje: int) -> void:
	puntaje_actual = nuevo_puntaje
	actualizar_ui()

func actualizar_ui() -> void:
	if label:
		# Mantiene el formato con ceros a la izquierda (ej. 0005)
		label.text = str(puntaje_actual).pad_zeros(digitos_minimos)
