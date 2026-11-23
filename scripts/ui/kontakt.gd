class_name Kontakt
extends Control
## Kontaktläge: närbild och dialog med en person.
##
## Dialogen läses från scenariots "dialog"-nyckel. Varje alternativ har en
## "handling" som bedöms av regelmotorn. Vilket alternativ som är rätt visas
## aldrig här – det tas upp i debriefingen.

signal val_gjort(alternativ: Dictionary)
signal nod_visad(nod: Dictionary)
signal stangd

var dialog: Dictionary = {}
var stamning := 3

var _replik: Label
var _alternativ_lista: VBoxContainer
var _stamning_rutor: Array[ColorRect] = []
var _stamning_text: Label
var _namn: Label
var _beskrivning: Label
var _portratt: TextureRect
var _tid_label: Label
var _aktuella: Array = []
var _slut := false
var _tid := 0.0


func bygg(scenario: Dictionary) -> void:
	dialog = scenario.get("dialog", {})
	UiKit.helskarm(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := UiKit.ruta_farg(Color(0.04, 0.055, 0.08, 0.86), Vector2.ZERO)
	UiKit.helskarm(bg)
	add_child(bg)

	var marg := MarginContainer.new()
	UiKit.helskarm(marg)
	for s in ["margin_left", "margin_right"]:
		marg.add_theme_constant_override(s, 32)
	for s in ["margin_top", "margin_bottom"]:
		marg.add_theme_constant_override(s, 24)
	marg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marg)
	var kol := UiKit.vbox(20)
	marg.add_child(kol)

	# Lägesrad
	var chips := UiKit.hbox(10)
	var k := UiKit.panel(UiKit.BARNSTEN, UiKit.PANEL, 14, 4)
	k.add_child(UiKit.rubrik("KONTAKT", 14, UiKit.BARNSTEN))
	chips.add_child(k)
	for t in ["Motparten: utanför staketet, invid skyddsobjektet", "Skylt: Tillträdesförbud · Avbildningsförbud", "Stridsparskamrat: skyddar"]:
		var c := UiKit.panel(UiKit.KANT, UiKit.PANEL, 14, 4)
		c.add_child(UiKit.etikett(t, 20))
		chips.add_child(c)
	kol.add_child(chips)

	var mitt := UiKit.hbox(32)
	mitt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kol.add_child(mitt)

	# Motpart
	var vanster := UiKit.vbox(12)
	vanster.custom_minimum_size = Vector2(326, 0)
	mitt.add_child(vanster)
	var ram := UiKit.panel(UiKit.KANT2, Color("22303D"), 0, 0)
	_portratt = TextureRect.new()
	_portratt.custom_minimum_size = Vector2(320, 320)
	_portratt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portratt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portratt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ram.add_child(_portratt)
	vanster.add_child(ram)
	var info := UiKit.panel(UiKit.KANT, UiKit.PANEL, 16, 12)
	var iv := UiKit.vbox(8)
	info.add_child(iv)
	_namn = UiKit.titel("", 17)
	iv.add_child(_namn)
	_beskrivning = UiKit.etikett("", 19, UiKit.DAMPAD)
	iv.add_child(_beskrivning)
	var sr := UiKit.hbox(8)
	var sl := UiKit.etikett("Stämning", 19, UiKit.DAMPAD)
	sl.custom_minimum_size = Vector2(76, 0)
	sr.add_child(sl)
	var staplar := UiKit.hbox(3)
	for i in 8:
		var r := UiKit.ruta_farg(UiKit.KANT, Vector2(20, 14))
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_stamning_rutor.append(r)
		staplar.add_child(r)
	sr.add_child(staplar)
	_stamning_text = UiKit.etikett("", 20, UiKit.BARNSTEN)
	sr.add_child(_stamning_text)
	iv.add_child(sr)
	vanster.add_child(info)

	# Dialog
	var hoger := UiKit.vbox(14)
	hoger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mitt.add_child(hoger)
	var bubbla := UiKit.panel(Color("0B1016"), UiKit.TEXT, 24, 18)
	var bv := UiKit.vbox(6)
	bubbla.add_child(bv)
	bv.add_child(UiKit.rubrik("MOTPARTEN", 14, Color("5A3B12")))
	_replik = UiKit.etikett("", 30, UiKit.MORK, true)
	bv.add_child(_replik)
	hoger.add_child(bubbla)
	hoger.add_child(UiKit.rubrik("DITT SVAR", 14, UiKit.GRON))
	_alternativ_lista = UiKit.vbox(8)
	hoger.add_child(_alternativ_lista)

	# Spelaren
	var botten := UiKit.hbox(16)
	var pr := UiKit.panel(UiKit.KANT2, UiKit.BG, 0, 0)
	var pt := TextureRect.new()
	pt.texture = load("res://assets/gfx/portratt_vakt.png")
	pt.custom_minimum_size = Vector2(80, 80)
	pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pr.add_child(pt)
	botten.add_child(pr)
	var bvv := UiKit.vbox(0)
	bvv.add_child(UiKit.titel("Du · Skyddsvakt", 15))
	_tid_label = UiKit.etikett("", 19, UiKit.DAMPAD)
	bvv.add_child(_tid_label)
	botten.add_child(bvv)
	kol.add_child(botten)


func oppna(npc: Dictionary, start_nod: String) -> void:
	_namn.text = str(npc.get("namn", "Okänd person"))
	_beskrivning.text = str(npc.get("beskrivning", ""))
	_portratt.texture = load("res://assets/gfx/%s.png" % npc.get("portratt", "portratt_civil"))
	stamning = int(npc.get("stamning", 3))
	_tid = 0.0
	_uppdatera_stamning()
	visible = true
	visa_nod(start_nod)


func visa_nod(nod_id: String) -> void:
	var nod: Dictionary = dialog.get(nod_id, {})
	_replik.text = str(nod.get("replik", "…"))
	nod_visad.emit(nod)
	for c in _alternativ_lista.get_children():
		c.queue_free()
	_aktuella = nod.get("alternativ", [])
	_slut = bool(nod.get("slut", false)) or _aktuella.is_empty()
	if _slut:
		var b := UiKit.knapp("TILLBAKA TILL PASSET  [Enter]", true, UiKit.GRON)
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(_stang)
		_alternativ_lista.add_child(b)
		return
	for i in _aktuella.size():
		_alternativ_lista.add_child(_alternativrad(i, _aktuella[i]))


func _alternativrad(i: int, alt: Dictionary) -> Control:
	var ruta := UiKit.klickruta()
	var h := UiKit.hbox(16)
	ruta.add_child(h)
	var nr := UiKit.panel(UiKit.BARNSTEN, UiKit.BARNSTEN, 0, 0)
	nr.custom_minimum_size = Vector2(32, 32)
	nr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl := UiKit.rubrik(str(i + 1), 16, UiKit.MORK)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nr.add_child(nl)
	h.add_child(nr)
	var t := UiKit.etikett(str(alt.get("text", "")), 24, UiKit.TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	ruta.gui_input.connect(_pa_alternativ_input.bind(i))
	return ruta


func _pa_alternativ_input(ev: InputEvent, i: int) -> void:
	if UiKit.ar_klick(ev):
		_valj(i)


func _valj(i: int) -> void:
	if i < 0 or i >= _aktuella.size():
		return
	var alt: Dictionary = _aktuella[i]
	stamning = clampi(stamning + int(alt.get("stamning", 0)), 0, 8)
	_uppdatera_stamning()
	val_gjort.emit(alt)
	var nasta := str(alt.get("nasta", ""))
	if nasta == "" or not dialog.has(nasta):
		_stang()
	else:
		visa_nod(nasta)


func _stang() -> void:
	visible = false
	stangd.emit()


func _uppdatera_stamning() -> void:
	for i in _stamning_rutor.size():
		var farg := UiKit.KANT
		if i < stamning:
			farg = UiKit.GRON if i < 2 else (UiKit.BARNSTEN if i < 5 else UiKit.ROSA)
		_stamning_rutor[i].color = farg
	if stamning <= 2:
		_stamning_text.text = "Lugn"
		_stamning_text.add_theme_color_override("font_color", UiKit.GRON)
	elif stamning <= 5:
		_stamning_text.text = "Irriterad"
		_stamning_text.add_theme_color_override("font_color", UiKit.BARNSTEN)
	else:
		_stamning_text.text = "Upprörd"
		_stamning_text.add_theme_color_override("font_color", UiKit.ROSA)


func _process(delta: float) -> void:
	if visible:
		_tid += delta
		_tid_label.text = "Tid i kontakt %02d:%02d" % [floori(_tid / 60.0), int(_tid) % 60]


func _unhandled_input(event: InputEvent) -> void:
	var tangent := event as InputEventKey
	if not visible or tangent == null or not tangent.pressed or tangent.echo:
		return
	if _slut and (tangent.keycode == KEY_ENTER or tangent.keycode == KEY_SPACE):
		_stang()
	elif tangent.keycode >= KEY_1 and tangent.keycode <= KEY_9:
		_valj(tangent.keycode - KEY_1)
	else:
		return
	get_viewport().set_input_as_handled()
