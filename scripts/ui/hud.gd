class_name Hud
extends Control
## Gränssnittet under patrull: tid, uppdrag, avvikelser, samband och handlingar.

signal forcera_handelse(handelse_id: String)
signal tysta_kamrat
signal handling(handling_id: String, beskrivning: String)
signal avsluta_pass

var varld: Varld
var scenario: Dictionary
## Returnerar aktuell lägestext för lägesrapporter (sätts av main.gd).
var lagestext: Callable

var _klocka: Label
var _position: Label
var _position_ruta: ColorRect
var _mal_rutor: Array = []  # [{handling, ruta}]
var _debug: PanelContainer
var _debug_status: Label
var _debug_knappar: Dictionary = {}
var _debug_info: PanelContainer
var _debug_info_text: Label
## Aktiva pratbubblor/ljudtexter: {nod, mal, t, hojd, stig, typ}
var _bubblor: Array = []
var _samband_lista: VBoxContainer
var _sambandsmeny: PanelContainer
var _instruktion: PanelContainer
var _meddelande: Label
var _ljudknapp: Button
const IKON_PA := preload("res://assets/gfx/hogtalare_pa.png")
const IKON_AV := preload("res://assets/gfx/hogtalare_av.png")
var _meddelande_t := 0.0


func bygg(p_scenario: Dictionary, p_varld: Varld) -> void:
	scenario = p_scenario
	varld = p_varld
	UiKit.helskarm(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bygg_toppfalt()
	_bygg_uppdrag()
	_bygg_debug()
	_bygg_debug_info()
	_bygg_samband()
	_bygg_position()
	_bygg_handlingar()
	_bygg_sambandsmeny()
	_bygg_instruktion()
	_meddelande = UiKit.etikett("", 24, UiKit.BARNSTEN)
	_meddelande.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_meddelande.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_meddelande.offset_top = 84
	_meddelande.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meddelande.add_theme_color_override("font_outline_color", UiKit.MORK)
	_meddelande.add_theme_constant_override("outline_size", 6)
	add_child(_meddelande)
	Spel.logg_ny.connect(_pa_logg)
	Spel.samband_ny.connect(_pa_samband)


func _bygg_toppfalt() -> void:
	var rad := UiKit.hbox(12)
	rad.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rad.offset_left = 16
	rad.offset_right = -16
	rad.offset_top = 16
	rad.offset_bottom = 68
	add_child(rad)

	var tid := UiKit.panel(UiKit.KANT, UiKit.PANEL, 18, 4)
	var th := UiKit.hbox(14)
	tid.add_child(th)
	th.add_child(UiKit.rubrik(str(scenario.get("pass", "")).to_upper(), 16, UiKit.GRON))
	_klocka = UiKit.etikett("00:00", 30)
	th.add_child(_klocka)
	th.add_child(UiKit.etikett(str(scenario.get("vader", "")), 20, UiKit.DAMPAD))
	for c in th.get_children():
		var lbl := c as Label
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rad.add_child(tid)

	var bered := UiKit.panel(UiKit.BARNSTEN, UiKit.PANEL, 16, 4)
	var bh := UiKit.hbox(10)
	bered.add_child(bh)
	var prick := UiKit.ruta_farg(UiKit.BARNSTEN, Vector2(10, 10))
	prick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bh.add_child(prick)
	var bl := UiKit.rubrik("BEREDSKAP: " + str(scenario.get("beredskap", "")), 15, UiKit.BARNSTEN)
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bh.add_child(bl)
	rad.add_child(bered)

	rad.add_child(UiKit.fyllnad())

	var obj := UiKit.panel(UiKit.KANT, UiKit.PANEL, 16, 4)
	var oh := UiKit.hbox(10)
	obj.add_child(oh)
	var ol := UiKit.etikett("Skyddsobjekt", 20, UiKit.DAMPAD)
	ol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	oh.add_child(ol)
	var on := UiKit.rubrik(str(scenario.get("objekt", "")).to_upper(), 15, UiKit.TEXT)
	on.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	oh.add_child(on)
	rad.add_child(obj)

	_ljudknapp = Button.new()
	_ljudknapp.custom_minimum_size = Vector2(52, 52)
	_ljudknapp.focus_mode = Control.FOCUS_NONE
	_ljudknapp.expand_icon = true
	_ljudknapp.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ljudknapp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ljudknapp.tooltip_text = "Musik av/på [M]"
	_ljudknapp.add_theme_stylebox_override("normal", UiKit.ruta(UiKit.PANEL, UiKit.KANT, 3, 10, 10))
	_ljudknapp.pressed.connect(func() -> void: Musik.vaxla())
	Musik.andrad.connect(_uppdatera_ljudikon)
	_uppdatera_ljudikon(Musik.ar_pa())
	rad.add_child(_ljudknapp)


func _uppdatera_ljudikon(pa: bool) -> void:
	_ljudknapp.icon = IKON_PA if pa else IKON_AV


func _bygg_uppdrag() -> void:
	var p := UiKit.panel()
	p.position = Vector2(16, 88)
	p.custom_minimum_size = Vector2(300, 0)
	add_child(p)
	var v := UiKit.vbox(6)
	p.add_child(v)
	var b: Dictionary = scenario.get("briefing", {})
	v.add_child(UiKit.rubrik("UPPDRAG", 15))
	var upp := UiKit.etikett(str(b.get("uppdrag", "")), 21, UiKit.TEXT, true)
	upp.custom_minimum_size = Vector2(268, 0)
	v.add_child(upp)
	for m in b.get("mal", []):
		var rad := UiKit.hbox(8)
		var ruta := ColorRect.new()
		ruta.custom_minimum_size = Vector2(12, 12)
		ruta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ruta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var klar := bool(m.get("klar_fran_start", false))
		ruta.color = UiKit.GRON if klar else UiKit.KANT
		rad.add_child(ruta)
		rad.add_child(UiKit.etikett(str(m.get("text", "")), 20))
		v.add_child(rad)
		_mal_rutor.append({"handling": str(m.get("handling", "")), "ruta": ruta})


## Debugrad (F3): forcera händelser och se upptäcktstimern.
func _bygg_debug() -> void:
	_debug = UiKit.panel(UiKit.ROSA, UiKit.PANEL, 10, 2)
	_debug.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_debug.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_debug.offset_top = 76
	_debug.offset_bottom = 76
	add_child(_debug)
	var h := UiKit.hbox(8)
	_debug.add_child(h)
	var rub := UiKit.rubrik("DEBUG", 12, UiKit.ROSA)
	rub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(rub)
	for hd in scenario.get("handelser", []):
		var id := str(hd.get("id", "?"))
		var b := UiKit.knapp("%s · %s" % [id, hd.get("namn", "")])
		b.custom_minimum_size = Vector2(0, 30)
		b.add_theme_font_size_override("font_size", 18)
		b.tooltip_text = "Starta händelse %s nu" % id
		b.pressed.connect(_pa_debug_knapp.bind(id))
		_debug_knappar[id] = b
		h.add_child(b)
	var info := UiKit.knapp("INFO")
	info.custom_minimum_size = Vector2(0, 30)
	info.add_theme_font_size_override("font_size", 18)
	info.tooltip_text = "Visa timers och spelets tillstånd"
	info.pressed.connect(_vaxla_debug_info)
	h.add_child(info)
	_debug_status = UiKit.etikett("", 18, UiKit.DAMPAD)
	_debug_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_debug_status)
	h.add_child(UiKit.etikett("[F3]", 16, UiKit.DAMPAD))


func _bygg_debug_info() -> void:
	_debug_info = UiKit.panel(UiKit.ROSA, Color(0.03, 0.04, 0.06, 0.94), 12, 8)
	_debug_info.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_debug_info.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_debug_info.offset_top = 116
	_debug_info.offset_bottom = 116
	_debug_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_info.visible = false
	add_child(_debug_info)
	_debug_info_text = UiKit.etikett("", 17, UiKit.TEXT)
	_debug_info.add_child(_debug_info_text)


func _vaxla_debug_info() -> void:
	_debug_info.visible = not _debug_info.visible


func debug_info_synlig() -> bool:
	return _debug_info.visible and _debug.visible


func satt_debug_info(text: String) -> void:
	_debug_info_text.text = text


## Pratbubbla ovanför en figur i världen (ersätter figurens förra bubbla).
func visa_bubbla(mal: Node2D, text: String, sek := 4.5) -> void:
	_ta_bort_bubbla(mal, "prat")
	var p := UiKit.panel(UiKit.MORK, UiKit.TEXT, 8, 3)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.etikett(text, 19, UiKit.MORK, text.length() > 26)
	if text.length() > 26:
		l.custom_minimum_size = Vector2(220, 0)
	p.add_child(l)
	add_child(p)
	_bubblor.append({"nod": p, "mal": mal, "t": sek, "hojd": 34.0, "stig": false, "typ": "prat"})


## Ljud som text ovanför en figur, t.ex. "klick klick", "klipp klipp", "brak".
func visa_ljud(mal: Node2D, text: String, sek := 1.3) -> void:
	_ta_bort_bubbla(mal, "ljud")
	var l := UiKit.rubrik(text.to_upper(), 14, UiKit.BARNSTEN)
	l.add_theme_color_override("font_outline_color", UiKit.MORK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	_bubblor.append({"nod": l, "mal": mal, "t": sek, "hojd": 40.0, "stig": true, "typ": "ljud", "start": sek})


func _ta_bort_bubbla(mal: Node2D, typ: String) -> void:
	for b in _bubblor.duplicate():
		if b["mal"] == mal and b["typ"] == typ:
			(b["nod"] as Control).queue_free()
			_bubblor.erase(b)


func _uppdatera_bubblor(delta: float) -> void:
	var kamera := get_viewport().get_canvas_transform()
	for b in _bubblor.duplicate():
		var nod: Control = b["nod"]
		b["t"] = float(b["t"]) - delta
		var mal_ok := is_instance_valid(b["mal"]) and (b["mal"] as Node2D).visible
		if float(b["t"]) <= 0.0 or not mal_ok:
			nod.queue_free()
			_bubblor.erase(b)
			continue
		var mal: Node2D = b["mal"]
		var pos := kamera * (mal.global_position + Vector2(0, -float(b["hojd"])))
		if b["stig"]:
			pos.y -= (float(b["start"]) - float(b["t"])) * 18.0
		nod.position = (pos - Vector2(nod.size.x / 2.0, nod.size.y)).round()


func _pa_debug_knapp(id: String) -> void:
	forcera_handelse.emit(id)


func satt_debug_status(text: String) -> void:
	_debug_status.text = text


func markera_handelse_startad(id: String) -> void:
	var b: Button = _debug_knappar.get(id)
	if b:
		b.disabled = true


func _bygg_samband() -> void:
	var p := UiKit.panel(UiKit.KANT, UiKit.PANEL, 18, 10)
	p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = -300
	p.offset_right = -16
	p.offset_top = -16
	p.offset_bottom = -16
	add_child(p)
	var v := UiKit.vbox(1)
	p.add_child(v)
	v.add_child(UiKit.rubrik("SAMBAND", 12, UiKit.DAMPAD))
	_samband_lista = UiKit.vbox(2)
	v.add_child(_samband_lista)
	for rad in Spel.samband:
		_pa_samband(rad)


func _bygg_position() -> void:
	var p := UiKit.panel(UiKit.KANT, UiKit.PANEL, 14, 8)
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = 16
	p.offset_right = 256
	p.offset_top = -16
	p.offset_bottom = -16
	add_child(p)
	var v := UiKit.vbox(2)
	p.add_child(v)
	v.add_child(UiKit.rubrik("DIN POSITION", 12, UiKit.DAMPAD))
	var rad := UiKit.hbox(8)
	_position_ruta = UiKit.ruta_farg(UiKit.GRON, Vector2(10, 10))
	_position_ruta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rad.add_child(_position_ruta)
	_position = UiKit.etikett("", 20)
	rad.add_child(_position)
	v.add_child(rad)


func _bygg_handlingar() -> void:
	var p := UiKit.panel(UiKit.KANT, UiKit.PANEL, 10, 10)
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_top = -16
	p.offset_bottom = -16
	add_child(p)
	var h := UiKit.hbox(10)
	p.add_child(h)
	var knappar := [
		["Observera", "Q", _observera],
		["Samband", "R", _vaxla_sambandsmeny],
		["Anteckna", "N", _anteckna],
		["Instruktion", "I", _vaxla_instruktion],
		["Avsluta pass", "Esc", _avsluta],
	]
	for k in knappar:
		var b := UiKit.knapp("%s\n[%s]" % [k[0], k[1]])
		b.custom_minimum_size = Vector2(96, 60)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(k[2])
		h.add_child(b)


func _bygg_sambandsmeny() -> void:
	_sambandsmeny = UiKit.panel(UiKit.BARNSTEN, UiKit.PANEL, 14, 12)
	_sambandsmeny.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sambandsmeny.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sambandsmeny.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sambandsmeny.offset_top = -112
	_sambandsmeny.offset_bottom = -112
	_sambandsmeny.visible = false
	add_child(_sambandsmeny)
	var v := UiKit.vbox(8)
	_sambandsmeny.add_child(v)
	v.add_child(UiKit.rubrik("SAMBAND", 13, UiKit.BARNSTEN))
	for val in scenario.get("sambandsval", []):
		var b := UiKit.knapp(str(val.get("etikett", "")))
		b.pressed.connect(_pa_sambandsval.bind(val))
		v.add_child(b)
	var stang := UiKit.knapp("Stäng")
	stang.pressed.connect(func() -> void: _sambandsmeny.visible = false)
	v.add_child(stang)


func _pa_sambandsval(val: Dictionary) -> void:
	_sambandsmeny.visible = false
	if str(val.get("handling", "")) != "":
		handling.emit(str(val.get("handling", "")), str(val.get("etikett", "")))
	var lage := str(lagestext.call()) if lagestext.is_valid() else ""
	Spel.spela_samband(val.get("meddelanden", []), {"lage": lage})


func _bygg_instruktion() -> void:
	_instruktion = UiKit.panel(UiKit.KANT2, UiKit.PANEL, 24, 18)
	_instruktion.set_anchors_preset(Control.PRESET_CENTER)
	_instruktion.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_instruktion.grow_vertical = Control.GROW_DIRECTION_BOTH
	_instruktion.custom_minimum_size = Vector2(560, 0)
	_instruktion.visible = false
	add_child(_instruktion)
	var v := UiKit.vbox(10)
	_instruktion.add_child(v)
	var b: Dictionary = scenario.get("briefing", {})
	v.add_child(UiKit.titel("Bevakningsinstruktion", 22))
	v.add_child(UiKit.etikett(str(b.get("uppdrag", "")), 22, UiKit.TEXT, true))
	v.add_child(UiKit.etikett(str(b.get("objektinfo", "")), 22, UiKit.LJUS, true))
	var stang := UiKit.knapp("Stäng [I]")
	stang.pressed.connect(_vaxla_instruktion)
	v.add_child(stang)


# --------------------------------------------------------------- Logik --

func visa_meddelande(text: String, sek := 3.0) -> void:
	_meddelande.text = text
	_meddelande_t = sek


func _tysta() -> void:
	tysta_kamrat.emit()


func _avsluta() -> void:
	avsluta_pass.emit()


func _observera() -> void:
	handling.emit("observera", "Observerade händelsen på avstånd")


func _anteckna() -> void:
	handling.emit("dokumentera", "Förde anteckningar i vaktjournalen")
	visa_meddelande("Anteckning förd i vaktjournalen")


func _vaxla_sambandsmeny() -> void:
	_sambandsmeny.visible = not _sambandsmeny.visible


func _vaxla_instruktion() -> void:
	_instruktion.visible = not _instruktion.visible


func _pa_logg(post: Dictionary) -> void:
	for m in _mal_rutor:
		if m["handling"] != "" and m["handling"] == post.get("handling", ""):
			var ruta: ColorRect = m["ruta"]
			ruta.color = UiKit.GRON


func _pa_samband(rad: Dictionary) -> void:
	var du := str(scenario.get("anropssignaler", {}).get("du", ""))
	var egen := str(rad.get("fran", "")) == du
	var t := UiKit.etikett("", 18, UiKit.TEXT, true)
	t.custom_minimum_size = Vector2(250, 0)
	t.text = "%s %s: %s" % [rad.get("tid", ""), rad.get("fran", ""), rad.get("text", "")]
	t.add_theme_color_override("font_color", UiKit.BARNSTEN if egen else UiKit.TEXT)
	_samband_lista.add_child(t)
	while _samband_lista.get_child_count() > 4:
		var forsta := _samband_lista.get_child(0)
		_samband_lista.remove_child(forsta)
		forsta.queue_free()


func _process(delta: float) -> void:
	if not visible:
		return
	_klocka.text = Spel.klockstrang()
	_uppdatera_bubblor(delta)
	if varld and varld.spelare:
		match varld.zon(varld.spelare.cell):
			"pa":
				_position.text = "På skyddsobjektet"
				_position_ruta.color = UiKit.GRON
			"invid":
				_position.text = "Invid (bedömning)"
				_position_ruta.color = UiKit.BARNSTEN
			_:
				_position.text = "Utanför skyddsobjektet"
				_position_ruta.color = UiKit.DAMPAD
	if _meddelande_t > 0.0:
		_meddelande_t -= delta
		_meddelande.visible = _meddelande_t > 0.0


func _unhandled_input(event: InputEvent) -> void:
	var tangent := event as InputEventKey
	if not visible or tangent == null or not tangent.pressed or tangent.echo:
		return
	match tangent.keycode:
		KEY_Q:
			_observera()
		KEY_R:
			_vaxla_sambandsmeny()
		KEY_N:
			_anteckna()
		KEY_I:
			_vaxla_instruktion()
		KEY_T:
			_tysta()
		KEY_F3:
			_debug.visible = not _debug.visible
		KEY_ESCAPE:
			if _sambandsmeny.visible or _instruktion.visible:
				_sambandsmeny.visible = false
				_instruktion.visible = false
			else:
				avsluta_pass.emit()
		_:
			return
	get_viewport().set_input_as_handled()
