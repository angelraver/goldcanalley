extends ScrollContainer

@export var sensibilidad_arrastre: float = 1.0
@export var inercia_friccion: float = 0.90 

var arrastrando: bool = false
var ultima_posicion_toque: Vector2 = Vector2.ZERO
var velocidad_arrastre: Vector2 = Vector2.ZERO

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

func _gui_input(event: InputEvent) -> void:
	# 1. INICIO DEL TOQUE (Pantalla táctil de iOS/Android o Click de Ratón en Mac)
	if event is InputEventScreenTouch:
		if event.pressed:
			arrastrando = true
			ultima_posicion_toque = event.position
			velocidad_arrastre = Vector2.ZERO
		else:
			arrastrando = false

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			arrastrando = true
			ultima_posicion_toque = event.position
			velocidad_arrastre = Vector2.ZERO
		else:
			arrastrando = false

	# 2. MOVIMIENTO / ARRASTRE (Dedo en movimiento en iOS/Android o Movimiento de ratón)
	elif event is InputEventScreenDrag and arrastrando:
		_procesar_desplazamiento(event.position)

	elif event is InputEventMouseMotion and arrastrando:
		_procesar_desplazamiento(event.position)

func _procesar_desplazamiento(posicion_actual: Vector2) -> void:
	var delta_movimiento: Vector2 = posicion_actual - ultima_posicion_toque
	ultima_posicion_toque = posicion_actual
	
	# Desplazamos los scrolls
	scroll_horizontal -= int(delta_movimiento.x * sensibilidad_arrastre)
	scroll_vertical -= int(delta_movimiento.y * sensibilidad_arrastre)
	
	# Guardamos la velocidad para el efecto de inercia al soltar el dedo
	velocidad_arrastre = delta_movimiento

func _process(delta: float) -> void:
	# Inercia progresiva al soltar el dedo en el iPhone
	if not arrastrando and velocidad_arrastre.length() > 0.5:
		scroll_horizontal -= int(velocidad_arrastre.x * sensibilidad_arrastre)
		scroll_vertical -= int(velocidad_arrastre.y * sensibilidad_arrastre)
		
		velocidad_arrastre *= inercia_friccion
		
		if velocidad_arrastre.length() <= 0.5:
			velocidad_arrastre = Vector2.ZERO
