extends Node3D

var tween_golpe: Tween

# Altura desde la que cae el mazo (en metros/unidades 3D)
const ALTURA_CAIDA: float = 3.0

func _ready() -> void:
	visible = false

func golpear_en(posicion_objetivo: Vector3, _pos_camara: Vector3) -> void:
	# Cancelar animación previa si se hace clic muy rápido
	if tween_golpe and tween_golpe.is_running():
		tween_golpe.kill()

	# 1. Fijar el punto de contacto exacto sobre la superficie (Y objetivo)
	var OFFSET_ALTURA_MESA: float = 0.3 # <-- ¡Ajusta este número!
	var pos_impacto: Vector3 = posicion_objetivo + Vector3(0, OFFSET_ALTURA_MESA, 0)
	
	# 2. Posición inicial: exactamente arriba del objetivo en el eje Y
	var pos_inicio: Vector3 = pos_impacto + Vector3(0, ALTURA_CAIDA, 0)
	
	global_position = pos_inicio
	visible = true

	# 3. Animar la caída con aceleración y un pequeño rebote al tocar
	tween_golpe = create_tween()
	
	# Caída rápida hacia el impacto (Aceleración / Ease In)
	tween_golpe.tween_property(self, "global_position", pos_impacto, .25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	# Pequeño rebote hacia arriba para acentuar el impacto (0.1 unidades arriba)
	tween_golpe.tween_property(self, "global_position", pos_impacto + Vector3(0, 0.2, 0), .25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Desaparecer al terminar
	tween_golpe.tween_callback(func(): visible = false)
