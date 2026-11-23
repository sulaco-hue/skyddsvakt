class_name Scenarioval
extends Control
## Startskärm: välj scenario (listan kommer från data/scenarier/index.json).

signal valt(sokvag: String)


func bygg(scenarier: Array) -> void:
	UiKit.helskarm(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := UiKit.ruta_farg(UiKit.BG, Vector2.ZERO)
	UiKit.helskarm(bg)
	add_child(bg)

	var mitt := CenterContainer.new()
	UiKit.helskarm(mitt)
	mitt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mitt)
	var kol := UiKit.vbox(16)
	kol.custom_minimum_size = Vector2(720, 0)
	mitt.add_child(kol)

	kol.add_child(UiKit.titel("SKYDDSVAKT", 40, UiKit.GRON))
	kol.add_child(UiKit.etikett("Utbildningsspel för militära skyddsvakter · prototyp", 22, UiKit.DAMPAD))
	kol.add_child(UiKit.rubrik("VÄLJ SCENARIO", 14, UiKit.DAMPAD))

	for i in scenarier.size():
		var sc: Dictionary = scenarier[i]
		var ruta := UiKit.klickruta()
		var h := UiKit.hbox(18)
		ruta.add_child(h)
		var nr := UiKit.panel(UiKit.BARNSTEN, UiKit.BARNSTEN, 0, 0)
		nr.custom_minimum_size = Vector2(44, 44)
		nr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nl := UiKit.titel(str(i + 1), 20, UiKit.MORK)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nr.add_child(nl)
		h.add_child(nr)
		var v := UiKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiKit.titel(str(sc.get("namn", "")), 20))
		var ing := UiKit.etikett(str(sc.get("ingress", "")), 21, UiKit.LJUS, true)
		v.add_child(ing)
		h.add_child(v)
		ruta.gui_input.connect(_pa_klick.bind(str(sc.get("sokvag", ""))))
		kol.add_child(ruta)

	kol.add_child(UiKit.etikett("Välj med musen eller med siffertangenterna. Lagstödet är inte juridiskt granskat.", 18,
		UiKit.DAMPAD, true))
	set_meta("scenarier", scenarier)


func _pa_klick(ev: InputEvent, sokvag: String) -> void:
	if UiKit.ar_klick(ev):
		valt.emit(sokvag)


func _unhandled_input(event: InputEvent) -> void:
	var tangent := event as InputEventKey
	if tangent == null or not tangent.pressed or tangent.echo:
		return
	var lista: Array = get_meta("scenarier", [])
	var i := tangent.keycode - KEY_1
	if i >= 0 and i < lista.size():
		valt.emit(str(lista[i].get("sokvag", "")))
		get_viewport().set_input_as_handled()
