extends MeshInstance3D

func _ready() -> void:
	# Opcional: desaparece solo después de 10 segundos para no saturar la memoria
	var tween = create_tween()
	tween.tween_property(self, "transparency", 1.0, 1.0).set_delay(8.0)
	tween.tween_callback(queue_free)
