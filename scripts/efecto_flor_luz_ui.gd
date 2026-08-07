extends Control

@export var duracion: float = 0.25
@export var escala_final: Vector2 = Vector2(2.5, 2.5)

func arrancar_efecto() -> void:
	# 1. Si el Control raíz no tiene tamaño, tomar el tamaño del primer hijo (TextureRect)
	if size == Vector2.ZERO and get_child_count() > 0:
		var hijo = get_child(0) as Control
		if hijo:
			custom_minimum_size = hijo.size
			size = hijo.size

	# 2. Definir el pivote exactamente en el centro
#	pivot_offset = size / 2.0
	scale = Vector2.ZERO

	# 3. Crear las animaciones centradas
	var tween = create_tween().set_parallel(true)

	# Expansión uniforme hacia afuera desde el centro
	tween.tween_property(self, "scale", escala_final, duracion)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

	# Desvanecimiento
	tween.tween_property(self, "modulate:a", 0.0, duracion)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)

	# Auto-destrucción al terminar
	tween.chain().tween_callback(queue_free)
