class_name Hud
extends Control
## Gränssnittet under patrull: tid, uppdrag, avvikelser, samband och handlingar.

signal forcera_handelse(handelse_id: String)
signal tysta_kamrat
## Situationsknappen (t.ex. "Bekämpa drönaren") trycktes.
## En situationsknapp trycktes (id från satt_situationer).
signal situation(id: String)
signal handling(handling_id: String, beskrivning: String)
signal avsluta_pass
## Ett sambandsval när motstationen har tystnat (scenariots "samband_tyst").
signal samband_utan_svar

var varld: Varld
var scenario: Dictionary
## Returnerar aktuell lägestext för lägesrapporter (sätts av main.gd).
## -> Dictionary med ersättningar för sambandsvalen ({lage}, {svar}, {polis} …) efter läget just nu.
var ersattningar: Callable

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
## Köade repliker per figur: mal -> [{text, sek, ms}]
var _talko: Dictionary = {}
## Eget lager för radiomenyn (överst).
var _radiolager: Control
var _samband_lista: VBoxContainer
var _samband_panel: PanelContainer
## Sekunder som en radiorad syns innan den börjar blekna, och hur länge den bleknar.
const SAMBAND_SYNS_S := 12.0
const SAMBAND_BLEKNAR_S := 3.0
var _sambandsmeny: PanelContainer
var _instruktion: PanelContainer
var _meddelande: Label
var _ljudknapp: Button
## Situationsknappar för det som händer just nu (t.ex. bekämpa drönare,
## halt-order, varningsskott). Står i en kolumn vid högerkanten.
var _situationer: VBoxContainer
var _situation_tangenter: Dictionary = {}  # keycode -> id
const IKON_PA := preload("res://assets/gfx/hogtalare_pa.png")
const IKON_AV := preload("res://assets/gfx/hogtalare_av.png")
var _meddelande_t := 0.0


func bygg(p_scenario: Dictionary, p_varld: Varld) -> void:
	scenario = p_scenario
	varld = p_varld
	UiKit.helskarm(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bygg_toppfalt()
	# Uppdragsrutan är borttagen tills vidare (ersätts av något bättre).
	_bygg_debug()
	_bygg_debug_info()
	_debug.visible = false
	_debug.visibility_changed.connect(func() -> void: Spel.debug = _debug.visible)
	Spel.debug = _debug.visible
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
	var vader := UiKit.etikett(str(scenario.get("vader", "")), 20, UiKit.DAMPAD)
	vader.visible = not UiKit.kompakt
	th.add_child(vader)
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
	if UiKit.VISA_BEREDSKAP:
		rad.add_child(bered)
	else:
		bered.free()

	rad.add_child(UiKit.fyllnad())

	var obj := UiKit.panel(UiKit.KANT, UiKit.PANEL, 16, 4)
	var oh := UiKit.hbox(10)
	obj.add_child(oh)
	var ol := UiKit.etikett("Skyddsobjekt", 20, UiKit.DAMPAD)
	ol.visible = not UiKit.kompakt
	ol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	oh.add_child(ol)
	var on := UiKit.rubrik(str(scenario.get("objekt", "")).to_upper(), 15, UiKit.TEXT)
	on.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	oh.add_child(on)
	rad.add_child(obj)
	obj.visible = not UiKit.kompakt  # objektets namn står i briefingen

	var dbg := UiKit.knapp("DBG")
	dbg.custom_minimum_size = Vector2(52, 52)
	dbg.add_theme_font_size_override("font_size", 16)
	dbg.tooltip_text = "Visa/dölj debugraden [F3]"
	dbg.pressed.connect(func() -> void: _debug.visible = not _debug.visible)
	rad.add_child(dbg)

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
	v.add_child(UiKit.rubrik("BEVAKNINGSINSTRUKTION", 15))
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
		# Delhändelser (t.ex. smygaren som följer på slagsmålet) startas av huvudhändelsen.
		if not bool(hd.get("i_debug", true)):
			continue
		var id := str(hd.get("id", "?"))
		var varianter: Array = hd.get("varianter", [])
		var val: Array = [[id, str(hd.get("namn", ""))]]
		if not varianter.is_empty():
			val = []
			for v in varianter:
				val.append(["%s:%s" % [id, v], "%s (%s)" % [hd.get("namn", ""), str(v).replace("_", " ")]])
		for par in val:
			var b := UiKit.knapp("%s · %s" % [id, par[1]])
			b.custom_minimum_size = Vector2(0, 30)
			b.add_theme_font_size_override("font_size", 18)
			b.tooltip_text = "Starta händelse %s nu" % par[0]
			b.pressed.connect(_pa_debug_knapp.bind(str(par[0])))
			_debug_knappar[str(par[0])] = b
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


## Pratbubbla ovanför en figur i världen. Pratar figuren redan köas den nya
## repliken: den pågående får stå kvar tills den hunnit läsas (kortas av till
## läsminimum) och sedan kommer nästa – repliker avbryter inte varandra.
func visa_bubbla(mal: Node2D, text: String, sek := 4.5) -> void:
	if text.strip_edges() == "":
		return
	var pagaende: Dictionary = {}
	for b in _bubblor:
		if b["mal"] == mal and b["typ"] == "prat":
			pagaende = b
	if not pagaende.is_empty():
		var ko: Array = _talko.get(mal, [])
		if str(pagaende.get("text", "")) == text or ko.any(func(k: Dictionary) -> bool: return str(k["text"]) == text):
			return
		ko.append({"text": text, "sek": sek, "ms": Time.get_ticks_msec()})
		while ko.size() > 3:
			ko.pop_front()
		_talko[mal] = ko
		# Den pågående står kvar tills den hunnit läsas, inte längre.
		pagaende["t"] = maxf(0.0, minf(float(pagaende["t"]), float(pagaende["las_t"]) - float(pagaende["visad"])))
		return
	_visa_bubbla_nu(mal, text, sek)


## Hur länge en replik minst ska synas för att hinna läsas.
static func lastid(text: String) -> float:
	return clampf(1.2 + text.length() * 0.055, 1.6, 4.5)


func _visa_bubbla_nu(mal: Node2D, text: String, sek: float) -> void:
	var p := UiKit.panel(UiKit.MORK, UiKit.TEXT, 8, 3)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.etikett(text, 19, UiKit.MORK, text.length() > 26)
	if text.length() > 26:
		l.custom_minimum_size = Vector2(220, 0)
	if UiKit.ar_kyrillisk(text):
		UiKit.kyrillisk_etikett(l)
		l.add_theme_font_size_override("font_size", 15)
	p.add_child(l)
	p.modulate.a = 0.0  # visas först när den har storlek och plats (annars blinkar den i hörnet)
	add_child(p)
	_bubblor.append({"nod": p, "mal": mal, "t": maxf(sek, 0.5), "hojd": 34.0, "stig": false, "typ": "prat",
		"text": text, "visad": 0.0, "las_t": minf(lastid(text), sek)})


## Ljud som text ovanför en figur, t.ex. "klick klick", "klipp klipp", "brak".
func visa_ljud(mal: Node2D, text: String, sek := 1.3, hojd := 40.0) -> void:
	_ta_bort_bubbla(mal, "ljud")
	var l := UiKit.rubrik(text.to_upper(), 14, UiKit.BARNSTEN)
	if UiKit.ar_kyrillisk(text):
		UiKit.kyrillisk_etikett(l)
	l.add_theme_color_override("font_outline_color", UiKit.MORK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	add_child(l)
	_bubblor.append({"nod": l, "mal": mal, "t": sek, "hojd": hojd, "stig": true, "typ": "ljud", "start": sek})


## Nästa köade replik för figuren (för gamla repliker hoppas över).
func _nasta_i_ko(mal: Node2D) -> void:
	var ko: Array = _talko.get(mal, [])
	while not ko.is_empty():
		var k: Dictionary = ko.pop_front()
		if Time.get_ticks_msec() - int(k["ms"]) <= 12000:
			_visa_bubbla_nu(mal, str(k["text"]), float(k["sek"]))
			break
	if ko.is_empty():
		_talko.erase(mal)


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
		b["visad"] = float(b.get("visad", 0.0)) + delta
		var mal_ok := is_instance_valid(b["mal"]) and (b["mal"] as Node2D).visible
		if float(b["t"]) <= 0.0 or not mal_ok:
			nod.queue_free()
			_bubblor.erase(b)
			if b["typ"] == "prat" and mal_ok:
				_nasta_i_ko(b["mal"])
			elif not mal_ok:
				_talko.erase(b["mal"])
			continue
		var mal: Node2D = b["mal"]
		# Är personen själv utanför bild? Då står bubblan still vid kanten tills han syns.
		var fot := kamera * mal.global_position
		b["utanfor"] = not get_viewport_rect().grow(-4.0).has_point(fot)
		if not bool(b["utanfor"]):
			b.erase("fast_pos")
		var pos := kamera * (mal.global_position + Vector2(0, -float(b["hojd"])))
		if b["stig"]:
			pos.y -= (float(b["start"]) - float(b["t"])) * 18.0
		nod.position = (pos - Vector2(nod.size.x / 2.0, nod.size.y)).round()
	_undvik_overlapp()


## Flyttar bubblor som överlappar: äldre bubblor ligger kvar, nyare staplas
## ovanför (eller nedanför om de skulle hamna utanför skärmen). En bubbla
## behåller sin förskjutning tills den försvinner, så att den inte hoppar
## tillbaka när en annan bubbla tas bort.
func _undvik_overlapp() -> void:
	var placerade: Array[Rect2] = []
	var skarm := get_viewport_rect().size
	# Personer i händelser (alla synliga figurer utom vi själva) får inte skymmas:
	# bubblor flyttas undan från dem, precis som från andra bubblor.
	var hinder := _handelsefigurer()
	for b in _bubblor:
		var nod: Control = b["nod"]
		if not is_instance_valid(nod) or nod.size == Vector2.ZERO:
			continue
		var egna: Array[Rect2] = placerade.duplicate()
		for hf: Array in hinder:
			if hf[0] != b["mal"]:
				egna.append(hf[1])
		if b.has("fast_pos"):
			nod.position = b["fast_pos"]
			placerade.append(Rect2(nod.position - Vector2(3.0, 3.0), nod.size).grow(3.0))
			nod.modulate.a = 1.0
			continue
		var naturlig_y := nod.position.y
		var r := Rect2(nod.position + Vector2(0.0, float(b.get("dy", 0.0))), nod.size).grow(3.0)
		var varv := 0
		var krock := true
		while krock and varv < 8:
			krock = false
			for p in egna:
				if r.intersects(p):
					r.position.y = p.position.y - r.size.y - 1.0
					krock = true
			varv += 1
		if r.position.y < 70.0:
			r.position.y = 70.0
			for p in egna:
				if r.intersects(p):
					r.position.y = p.end.y + 1.0
		r.position.x = clampf(r.position.x, 4.0, skarm.x - r.size.x - 4.0)
		r.position.y = minf(r.position.y, skarm.y - r.size.y - 4.0)
		b["dy"] = r.position.y + 3.0 - naturlig_y
		placerade.append(r)
		nod.position = (r.position + Vector2(3.0, 3.0)).round()
		nod.modulate.a = 1.0
		if bool(b.get("utanfor", false)):
			b["fast_pos"] = nod.position


## Skärmrutor för synliga figurer som inte är stridsparet: [nod, Rect2].
func _handelsefigurer() -> Array:
	var ut: Array = []
	if varld == null:
		return ut
	var kamera := get_viewport().get_canvas_transform()
	var skala := kamera.get_scale().x
	var skarm := get_viewport_rect()
	for n: Node2D in varld.npcer.values():
		if not n.visible:
			continue
		var fot := kamera * n.global_position
		if not skarm.has_point(fot):
			continue
		# Figuren: ca 16x28 bildpunkter från fötterna och uppåt (ligger: bredare och lägre).
		var storlek := Vector2(18, 30) * skala
		ut.append([n, Rect2(fot - Vector2(storlek.x / 2.0, storlek.y), storlek).grow(2.0)])
	return ut


func _pa_debug_knapp(id: String) -> void:
	forcera_handelse.emit(id)


func satt_debug_status(text: String) -> void:
	_debug_status.text = text


func markera_handelse_startad(id: String) -> void:
	for nyckel: String in _debug_knappar:
		if nyckel == id or nyckel.begins_with(id + ":"):
			(_debug_knappar[nyckel] as Button).disabled = true


func _bygg_samband() -> void:
	var p := UiKit.panel(UiKit.KANT, UiKit.PANEL, 18, 10)
	p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = -300
	p.offset_right = -16
	p.offset_top = -16
	p.offset_bottom = -16
	if UiKit.kompakt:
		# Kompakt: nere i högra hörnet (handlingsraden ligger till vänster),
		# så att rutan inte hamnar mitt i synfältet.
		p.offset_left = -258
		p.offset_right = -8
		p.offset_top = -8
		p.offset_bottom = -8
	add_child(p)
	_samband_panel = p
	p.visible = false
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
	if UiKit.kompakt:
		# Kompakt: uppe till vänster under toppraden
		p.set_anchors_preset(Control.PRESET_TOP_LEFT)
		p.grow_vertical = Control.GROW_DIRECTION_END
		p.offset_left = 16
		p.offset_right = 216
		p.offset_top = 76
		p.offset_bottom = 76
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
	if UiKit.kompakt:
		# Kompakt: nere till vänster, så att sambandsrutan får högra hörnet.
		p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		p.grow_horizontal = Control.GROW_DIRECTION_END
		p.offset_left = 8
		p.offset_right = 8
		p.offset_top = -8
		p.offset_bottom = -8
	add_child(p)
	var h := UiKit.hbox(8 if UiKit.kompakt else 10)
	p.add_child(h)
	var knappar := [
		["Samband", "R", _vaxla_sambandsmeny],
		["Anteckna", "N", _anteckna],
		["Instruktion", "I", _vaxla_instruktion],
		["Avsluta pass", "Esc", _avsluta],
	]
	for k in knappar:
		var b := UiKit.knapp("%s\n[%s]" % [k[0], k[1]])
		b.custom_minimum_size = Vector2(84, 56) if UiKit.kompakt else Vector2(96, 60)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(k[2])
		h.add_child(b)
	_situationer = UiKit.vbox(8)
	_situationer.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_situationer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_situationer.grow_vertical = Control.GROW_DIRECTION_BOTH
	_situationer.offset_right = -10
	_situationer.offset_top = 10 if UiKit.kompakt else 0
	add_child(_situationer)


# ------------------------------------------------------------ Samband --
# Uppropet: ett anrop öppnar förbindelsen med CQ, sedan kan flera ärenden
# tas i samma samtal (data/samband.json), och samtalet avslutas med Klart slut.

var _samband_data: Dictionary = {}
var _samtal_pagar := false
var _samtal_anvanda: Dictionary = {}
var _samband_knappar: Dictionary = {}  # id -> Button
var _samband_lista_v: VBoxContainer


func _bygg_sambandsmeny() -> void:
	_samband_data = Datafil.las_json("res://data/samband.json")
	_sambandsmeny = UiKit.panel(UiKit.BARNSTEN, UiKit.PANEL, 14, 12)
	_sambandsmeny.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sambandsmeny.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sambandsmeny.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sambandsmeny.offset_top = -112
	_sambandsmeny.offset_bottom = -112
	if UiKit.kompakt:
		# Kompakt: ovanför Samband-knappen nere till vänster.
		_sambandsmeny.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_sambandsmeny.grow_horizontal = Control.GROW_DIRECTION_END
		_sambandsmeny.offset_left = 8
		_sambandsmeny.offset_right = 8
		_sambandsmeny.offset_top = -92
		_sambandsmeny.offset_bottom = -92
	_sambandsmeny.visible = false
	# Radiomenyn ligger i ett eget lager allra överst, över pratbubblor och kontaktrutan.
	var lager := CanvasLayer.new()
	lager.layer = 10
	add_child(lager)
	_radiolager = Control.new()
	UiKit.helskarm(_radiolager)
	_radiolager.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radiolager.theme = UiKit.skapa_tema()
	lager.add_child(_radiolager)
	_radiolager.add_child(_sambandsmeny)
	_samband_lista_v = UiKit.vbox(8)
	_sambandsmeny.add_child(_samband_lista_v)
	_visa_sambandsmeny_innehall()


func _visa_sambandsmeny_innehall() -> void:
	for c in _samband_lista_v.get_children():
		c.queue_free()
	_samband_knappar.clear()
	var v := _samband_lista_v
	if not _samtal_pagar:
		v.add_child(UiKit.rubrik("SAMBAND", 13, UiKit.BARNSTEN))
		var anropa := UiKit.knapp("Anropa CQ", true)
		anropa.pressed.connect(radio_anropa)
		v.add_child(anropa)
		var stang := UiKit.knapp("Stäng")
		stang.pressed.connect(func() -> void: _sambandsmeny.visible = false)
		v.add_child(stang)
		return
	v.add_child(UiKit.rubrik("SAMBAND · CQ PÅ LINJEN", 13, UiKit.GRON))
	var rutnat := GridContainer.new()
	rutnat.columns = 2
	rutnat.add_theme_constant_override("h_separation", 8)
	rutnat.add_theme_constant_override("v_separation", 8)
	v.add_child(rutnat)
	for val: Dictionary in _samband_data.get("val", []):
		var b := UiKit.knapp(str(val.get("etikett", "")))
		b.pressed.connect(radio_valj.bind(str(val.get("id", ""))))
		b.disabled = _samtal_anvanda.has(str(val.get("id", "")))
		rutnat.add_child(b)
		_samband_knappar[str(val.get("id", ""))] = b
	var slut := UiKit.knapp("Klart slut", true, UiKit.GRON)
	slut.pressed.connect(radio_avsluta)
	v.add_child(slut)
	_samband_knappar["__slut"] = slut


## Anropa CQ. Har CQ tystnat (scenariots "samband_tyst") svarar ingen.
func radio_anropa() -> void:
	var tyst: Dictionary = scenario.get("samband_tyst", {})
	if not tyst.is_empty() and bool(Spel.fakta.get(str(tyst.get("om_fakta", "")), false)):
		_sambandsmeny.visible = false
		Spel.spela_samband(tyst.get("meddelanden", []), {})
		samband_utan_svar.emit()
		return
	_samtal_pagar = true
	Spel.samtal_oppet = true
	_samtal_anvanda.clear()
	# Anropet går snabbt: vi kan sända ärendet strax efter "CQ kom."
	Spel.spela_samband(_samband_data.get("anrop", []), {}, false, 0.35)
	_visa_sambandsmeny_innehall()
	_sambandsmeny.visible = true


## Ett ärende i samtalet (id i data/samband.json). Varje ärende en gång per samtal.
func radio_valj(id: String) -> void:
	if not _samtal_pagar or _samtal_anvanda.has(id):
		return
	for val: Dictionary in _samband_data.get("val", []):
		if str(val.get("id", "")) != id:
			continue
		_samtal_anvanda[id] = true
		if str(val.get("handling", "")) != "":
			handling.emit(str(val.get("handling", "")), str(val.get("etikett", "")) + " (samband med CQ)")
		var byt: Dictionary = ersattningar.call() if ersattningar.is_valid() else {}
		Spel.spela_samband(val.get("meddelanden", []), byt)
		if _samband_knappar.has(id):
			(_samband_knappar[id] as Button).disabled = true


func radio_avsluta() -> void:
	if not _samtal_pagar:
		_sambandsmeny.visible = false
		return
	_samtal_pagar = false
	Spel.spela_samband(_samband_data.get("avslut", []), {})
	# Linjen räknas som öppen tills "Klart slut" är sagt.
	get_tree().create_timer(2.0).timeout.connect(func() -> void: Spel.samtal_oppet = false)
	_sambandsmeny.visible = false
	_visa_sambandsmeny_innehall()


## Knapparna väntar medan någon pratar på kanalen.
func _uppdatera_sambandsknappar() -> void:
	if not _samtal_pagar or not _sambandsmeny.visible:
		return
	var upptagen := Spel.kanal_upptagen()
	for id: String in _samband_knappar:
		var b: Button = _samband_knappar[id]
		b.disabled = upptagen or _samtal_anvanda.has(id)


## Instruktion [I]: två flikar – bevakningsinstruktionen och lagstödskortet
## (data/lagstodskort.json).
func _bygg_instruktion() -> void:
	_instruktion = UiKit.panel(UiKit.KANT2, UiKit.PANEL, 20, 14)
	_instruktion.set_anchors_preset(Control.PRESET_FULL_RECT)
	var marg := 40 if UiKit.kompakt else 120
	_instruktion.offset_left = marg
	_instruktion.offset_right = -marg
	_instruktion.offset_top = 76
	_instruktion.offset_bottom = -16
	_instruktion.visible = false
	add_child(_instruktion)
	var v := UiKit.vbox(10)
	_instruktion.add_child(v)

	var flikar := UiKit.hbox(8)
	v.add_child(flikar)
	var f1 := UiKit.knapp("BEVAKNINGSINSTRUKTION")
	var f2 := UiKit.knapp("LAGSTÖD")
	flikar.add_child(f1)
	flikar.add_child(f2)
	flikar.add_child(UiKit.fyllnad())
	var stang := UiKit.knapp("Stäng [I]")
	stang.pressed.connect(_vaxla_instruktion)
	flikar.add_child(stang)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var innehall := UiKit.vbox(10)
	innehall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(innehall)

	var instr := UiKit.vbox(10)
	instr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b: Dictionary = scenario.get("briefing", {})
	instr.add_child(UiKit.titel("Bevakningsinstruktion", 22))
	instr.add_child(UiKit.etikett(str(b.get("uppdrag", "")), 22, UiKit.TEXT, true))
	instr.add_child(UiKit.etikett(str(b.get("objektinfo", "")), 22, UiKit.LJUS, true))
	instr.add_child(UiKit.etikett(str(b.get("samband", "")), 20, UiKit.LJUS, true))
	innehall.add_child(instr)

	var lag := UiKit.vbox(12)
	lag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kort := Datafil.las_json("res://data/lagstodskort.json")
	lag.add_child(UiKit.etikett("Sammanfattning i egna ord – inte lagtext. " + str(kort.get("kalla", "")), 18,
		UiKit.DAMPAD, true))
	for par in kort.get("paragrafer", []):
		var rad := UiKit.hbox(14)
		var nr := UiKit.titel(str(par.get("paragraf", "")), 20, UiKit.BARNSTEN)
		nr.custom_minimum_size = Vector2(56, 0)
		rad.add_child(nr)
		var pv := UiKit.vbox(2)
		pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pv.add_child(UiKit.rubrik(str(par.get("rubrik", "")).to_upper(), 13, UiKit.GRON))
		pv.add_child(UiKit.etikett(str(par.get("text", "")), 20, UiKit.TEXT, true))
		rad.add_child(pv)
		lag.add_child(rad)
	lag.visible = false
	innehall.add_child(lag)

	f1.pressed.connect(_visa_flik.bind(instr, lag, false))
	f2.pressed.connect(_visa_flik.bind(instr, lag, true))


func _visa_flik(instr: Control, lag: Control, visa_lag: bool) -> void:
	instr.visible = not visa_lag
	lag.visible = visa_lag


# --------------------------------------------------------------- Logik --

func visa_meddelande(text: String, sek := 3.0) -> void:
	_meddelande.text = text
	_meddelande_t = sek


## Visar/döljer en extra knapp för det som händer just nu (tangent B, id "dronare").
func satt_situation(text: String, synlig: bool) -> void:
	satt_situationer([{"id": "dronare", "text": text, "tangent": "B"}] if synlig else [])


## Ersätter situationsknapparna. Varje val: {id, text, tangent ("H"), farg ("rosa"/"barnsten"/"gron")}.
func satt_situationer(val: Array) -> void:
	for c in _situationer.get_children():
		c.queue_free()
	_situation_tangenter.clear()
	for v in val:
		var id := str(v.get("id", ""))
		var tangent := str(v.get("tangent", ""))
		var farg: Color = {"barnsten": UiKit.BARNSTEN, "gron": UiKit.GRON}.get(str(v.get("farg", "")), UiKit.ROSA)
		var b := UiKit.knapp(str(v.get("text", "")) + ("\n[%s]" % tangent if tangent != "" else ""), true, farg)
		b.custom_minimum_size = Vector2(124, 54) if UiKit.kompakt else Vector2(150, 60)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_pa_situation.bind(id))
		_situationer.add_child(b)
		if tangent != "":
			_situation_tangenter[OS.find_keycode_from_string(tangent)] = id


func _pa_situation(id: String) -> void:
	situation.emit(id)


## Id:n för de situationsknappar som visas just nu (används av testerna).
func situationer() -> Array:
	return _situation_tangenter.values()


func _tysta() -> void:
	tysta_kamrat.emit()


func _avsluta() -> void:
	avsluta_pass.emit()


func _anteckna() -> void:
	handling.emit("dokumentera", "Förde anteckningar i vaktjournalen")
	visa_meddelande("Anteckning förd i vaktjournalen")


func _vaxla_sambandsmeny() -> void:
	# Stängs menyn mitt i ett samtal avslutas samtalet ordentligt (Klart slut).
	if _sambandsmeny.visible and _samtal_pagar:
		radio_avsluta()
		return
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
	# Trafik till/från oss syns tydligt; trafik mellan andra enheter (brus) dämpat.
	var till_oss := egen or str(rad.get("text", "")).contains(du)
	var t := UiKit.etikett("", 18, UiKit.TEXT, true)
	t.custom_minimum_size = Vector2(250, 0)
	t.text = "%s %s: %s" % [rad.get("tid", ""), rad.get("fran", ""), rad.get("text", "")]
	var farg := UiKit.BARNSTEN if egen else (UiKit.TEXT if till_oss else UiKit.DAMPAD)
	t.add_theme_color_override("font_color", farg)
	t.set_meta("alder", 0.0)
	_samband_lista.add_child(t)
	_samband_panel.visible = true
	while _samband_lista.get_child_count() > (3 if UiKit.kompakt else 4):
		var forsta := _samband_lista.get_child(0)
		_samband_lista.remove_child(forsta)
		forsta.queue_free()


## Radiorader bleknar efter en stund och försvinner; tom panel döljs.
func _bleka_samband(delta: float) -> void:
	for rad in _samband_lista.get_children():
		if rad.is_queued_for_deletion():
			continue
		var alder := float(rad.get_meta("alder", 0.0)) + delta
		rad.set_meta("alder", alder)
		var l := rad as Label
		if alder > SAMBAND_SYNS_S:
			l.modulate.a = clampf(1.0 - (alder - SAMBAND_SYNS_S) / SAMBAND_BLEKNAR_S, 0.0, 1.0)
		if alder > SAMBAND_SYNS_S + SAMBAND_BLEKNAR_S:
			_samband_lista.remove_child(rad)
			rad.queue_free()
	_samband_panel.visible = _samband_lista.get_child_count() > 0


func _process(delta: float) -> void:
	_uppdatera_sambandsknappar()
	# Lagret följer inte HUD:ens synlighet av sig självt (t.ex. vid debriefingen).
	_radiolager.visible = visible
	if not visible:
		return
	_klocka.text = Spel.klockstrang()
	_uppdatera_bubblor(delta)
	_bleka_samband(delta)
	if varld and varld.spelare:
		match varld.zon(varld.spelare.cell):
			"pa":
				_position.text = "På skyddsobjektet"
				_position_ruta.color = UiKit.GRON
			"invid":
				_position.text = "Invid (bedömning)"
				_position_ruta.color = UiKit.BARNSTEN
			_:
				_position.text = "Utanför (bedömning)"
				_position_ruta.color = UiKit.DAMPAD
	if _meddelande_t > 0.0:
		_meddelande_t -= delta
		_meddelande.visible = _meddelande_t > 0.0


func _unhandled_input(event: InputEvent) -> void:
	var tangent := event as InputEventKey
	if not visible or tangent == null or not tangent.pressed or tangent.echo:
		return
	match tangent.keycode:
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
			if _situation_tangenter.has(tangent.keycode):
				situation.emit(str(_situation_tangenter[tangent.keycode]))
			else:
				return
	get_viewport().set_input_as_handled()
