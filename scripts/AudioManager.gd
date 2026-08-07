extends Node

@onready var start = $Start
@onready var shot = $Shot
@onready var welldone = $Welldone

var sonidos_lata: Array = []

func _ready() -> void:
	# Recorremos los nodos hijos y agrupamos automáticamente todos los "LataX"
	for hijo in get_children():
		if hijo.name.begins_with("Lata"):
			sonidos_lata.append(hijo)

func play_start() -> void:
	start.play()

func play_shot() -> void:
	shot.play()

func play_welldone() -> void:
	welldone.play()

# Una sola función limpia para reproducir una lata al azar
func play_lata() -> void:
	if not sonidos_lata.is_empty():
		sonidos_lata.pick_random().play()
