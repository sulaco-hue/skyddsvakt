class_name Titelskarm
extends Control
## Startskärmen: "Halt, militär skyddsvakt!" i pixelstil.

signal fortsatt

var _uppmaning: Label
var _t := 0.0


func bygg() -> void:
	UiKit.helskarm(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := UiKit.ruta_farg(UiKit.BG, Vector2.ZERO)
	UiKit.helskarm(bg)
	add_child(bg)

	# Bakgrund: objektskartan, nedtonad
	var karta := TextureRect.new()
	karta.texture = load("res://assets/gfx/titelbakgrund.png")  # kartan i full upplösning
	karta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	karta.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	karta.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	karta.modulate = Color(0.45, 0.5, 0.6)
	UiKit.helskarm(karta)
	karta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(karta)
	var slojja := UiKit.ruta_farg(Color(0.04, 0.06, 0.09, 0.55), Vector2.ZERO)
	UiKit.helskarm(slojja)
	add_child(slojja)

	var mitt := CenterContainer.new()
	UiKit.helskarm(mitt)
	mitt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mitt)
	var rad := UiKit.hbox(48)
	mitt.add_child(rad)

	var kol := UiKit.vbox(18)
	kol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rad.add_child(kol)
	var logga := TextureRect.new()
	logga.texture = load("res://assets/gfx/logga.png")
	# Loggan är ritad i 660x192; visas i den storleken (mindre på mobil).
	logga.custom_minimum_size = Vector2(660, 192) * (1.0 if not UiKit.kompakt else 0.6667)
	logga.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logga.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logga.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if UiKit.kompakt else CanvasItem.TEXTURE_FILTER_NEAREST
	kol.add_child(logga)
	kol.add_child(UiKit.ruta_farg(Color(0, 0, 0, 0), Vector2(0, 20)))
	_uppmaning = UiKit.rubrik("TRYCK FÖR ATT BÖRJA", 16, UiKit.BARNSTEN)
	_uppmaning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kol.add_child(_uppmaning)

	var fot := UiKit.etikett("Prototyp · lagstödet är inte juridiskt granskat", 18, UiKit.DAMPAD)
	fot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fot.offset_bottom = -14
	fot.offset_top = -14
	fot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(fot)


func _process(delta: float) -> void:
	_t += delta
	if _uppmaning:
		# Blinkar med genomskinlighet så att layouten står still.
		_uppmaning.modulate.a = 1.0 if fmod(_t, 1.2) < 0.8 else 0.0


func _gui_input(event: InputEvent) -> void:
	if UiKit.ar_klick(event):
		fortsatt.emit()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	var tangent := event as InputEventKey
	if visible and tangent != null and tangent.pressed and not tangent.echo:
		fortsatt.emit()
		get_viewport().set_input_as_handled()
