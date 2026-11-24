class_name Kontakt
extends Control
## Kontaktläge: närbild och dialog med en person.
##
## Dialogen läses från scenariots "dialog"-nyckel. Varje alternativ har en
## "handling" som bedöms av regelmotorn. Vilket alternativ som är rätt visas
## aldrig här – det tas upp i debriefingen.
##
## Under svaren finns alltid samma åtgärder (avvisa, avlägsna, omhänderta,
## gripa …), så att valet inte avslöjar vad som är rimligt. Motpartens
## reaktion på en åtgärd står i scenariots "atgarder" och kan ersättas per
## dialogsteg (nodens "atgarder"). En reaktion har antingen "nasta" (nästa
## steg) eller en egen "replik" – då ligger samma svar kvar.
## Med debug påslaget visas inom parentes bedömningen just nu och vart valet leder.

## Åtgärdsraden: handling i lagrum.json och kort etikett.
const ATGARDER := [
	["begara_identitet", "Begär uppgifter"],  # namn, födelsetid, hemvist (10 §)
	["be_om_legitimation", "Be om leg."],  # frivilligt – ingen skyldighet att visa
	["kroppsvisitera", "Visitera"],
	["undersoka_fordon", "Undersök fordon"],
	["beslag", "Beslag"],
	["avvisa", "Avvisa"],
	["avlagsna", "Avlägsna"],
	["tillfalligt_omhanderta", "Omhänderta"],
	["gripa", "Gripa"],
	["envarsgripande", "Envarsgripande"],  # BrB 24:7
	["forsta_hjalpen", "Första hjälpen"],
	["lata_ga", "Låt gå"],
]

signal val_gjort(alternativ: Dictionary)
signal nod_visad(nod: Dictionary)
signal stangd

var dialog: Dictionary = {}
## Scenariots standardreaktioner på åtgärderna ({handling: {text, nasta | replik, …}}).
var atgarder: Dictionary = {}
var _atgard_lista: Array = []
var _nod_id := ""
## Åtgärder med egen replik som redan valts i det här steget (grånas ut).
var _anvanda: Dictionary = {}
var stamning := 3

var _replik: Label
## Det vi själva sa just före motpartens replik: nodens "du", valets "du"
## (åtgärderna) eller citatet i det valda svaret.
var _du: Label
var _senast_sagt := ""
var _alternativ_lista: VBoxContainer
var _stamning_rutor: Array[ColorRect] = []
var _stamning_text: Label
var _namn: Label
var _beskrivning: Label
var _portratt: TextureRect
var _vanster: VBoxContainer
var _stamning_etikett: Label
var _motpart_rubrik: Label
## Efter första valet krymper porträttet så att dialogen får mer plats.
var _krympt := false
var _tid_label: Label
var _aktuella: Array = []
var _slut := false
var _tid := 0.0
var _chips: HFlowContainer
var _atgard_rubrik: Label
var _svar_rubrik: Label
var _atgard_rad: HFlowContainer
var _atgard_val: Array = []


func bygg(scenario: Dictionary) -> void:
	dialog = scenario.get("dialog", {})
	atgarder = scenario.get("atgarder", {})
	_atgard_lista = scenario.get("atgarder_lista", ATGARDER.map(func(a: Array) -> String: return str(a[0])))
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
	# Lägesraden bryts till flera rader i stället för att bli bredare än skärmen.
	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override("h_separation", 8)
	_chips.add_theme_constant_override("v_separation", 6)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kol.add_child(_chips)

	var mitt := UiKit.hbox(32)
	mitt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kol.add_child(mitt)

	# Motpart
	var vanster := UiKit.vbox(12)
	_vanster = vanster
	var portr := 180 if UiKit.kompakt else 320
	vanster.custom_minimum_size = Vector2(portr + 6, 0)
	mitt.add_child(vanster)
	var ram := UiKit.panel(UiKit.KANT2, Color("22303D"), 0, 0)
	_portratt = TextureRect.new()
	_portratt.custom_minimum_size = Vector2(portr, portr)
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
	_stamning_etikett = sl
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
	# Dialogspalten kan scrollas (behövs på små skärmar med långa repliker).
	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mitt.add_child(dscroll)
	var hoger := UiKit.vbox(14)
	hoger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(hoger)
	var bubbla := UiKit.panel(Color("0B1016"), UiKit.TEXT, 24, 18)
	bubbla.mouse_filter = Control.MOUSE_FILTER_PASS  # tryck-dra i textrutan scrollar
	var bv := UiKit.vbox(6)
	bubbla.add_child(bv)
	_du = UiKit.etikett("", 21 if UiKit.kompakt else 25, Color("2E4A1E"), true)
	bv.add_child(_du)
	_motpart_rubrik = UiKit.rubrik("MOTPARTEN", 14, Color("5A3B12"))
	bv.add_child(_motpart_rubrik)
	_replik = UiKit.etikett("", 24 if UiKit.kompakt else 30, UiKit.MORK, true)
	bv.add_child(_replik)
	hoger.add_child(bubbla)
	_svar_rubrik = UiKit.rubrik("DITT SVAR", 14, UiKit.GRON)
	hoger.add_child(_svar_rubrik)
	_alternativ_lista = UiKit.vbox(8)
	hoger.add_child(_alternativ_lista)
	_atgard_rubrik = UiKit.rubrik("ÅTGÄRDER", 14, UiKit.BARNSTEN)
	hoger.add_child(_atgard_rubrik)
	_atgard_rad = HFlowContainer.new()
	_atgard_rad.add_theme_constant_override("h_separation", 8)
	_atgard_rad.add_theme_constant_override("v_separation", 8)
	hoger.add_child(_atgard_rad)

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
	bvv.add_child(UiKit.titel("Ettan · Skyddsvakt", 15))
	_tid_label = UiKit.etikett("", 19, UiKit.DAMPAD)
	bvv.add_child(_tid_label)
	botten.add_child(bvv)
	kol.add_child(botten)
	botten.visible = not UiKit.kompakt


func _bygg_chips(rader: Array) -> void:
	for c in _chips.get_children():
		c.queue_free()
	_chips.visible = not rader.is_empty()
	for t in rader:
		var c := UiKit.panel(UiKit.KANT, UiKit.PANEL, 10 if UiKit.kompakt else 14, 3)
		c.add_child(UiKit.etikett(str(t), 17 if UiKit.kompakt else 20))
		_chips.add_child(c)


func oppna(npc: Dictionary, start_nod: String) -> void:
	_bygg_chips(npc.get("kontakt_info", []))
	# Rubriken över repliken: MANNEN, KVINNAN, FLICKAN, POJKEN …
	_motpart_rubrik.text = str(npc.get("benamning", "MOTPARTEN")).to_upper()
	_satt_krympt(false)
	_namn.text = str(npc.get("namn", "Okänd person"))
	_beskrivning.text = str(npc.get("beskrivning", ""))
	_portratt.texture = load("res://assets/gfx/%s.png" % npc.get("portratt", "portratt_civil"))
	stamning = int(npc.get("stamning", 3))
	_tid = 0.0
	_uppdatera_stamning()
	visible = true
	visa_nod(start_nod)


## Litet porträtt (efter första valet): ger dialogen mer plats.
func _satt_krympt(k: bool) -> void:
	_krympt = k
	var portr := (180 if UiKit.kompakt else 320) if not k else (88 if UiKit.kompakt else 150)
	_portratt.custom_minimum_size = Vector2(portr, portr)
	_vanster.custom_minimum_size = Vector2(portr + 6, 0)
	_beskrivning.visible = not k
	_stamning_etikett.visible = not k
	_stamning_text.visible = not k
	var ruta := Vector2(9, 10) if k else Vector2(20, 14)
	for rr in _stamning_rutor:
		rr.custom_minimum_size = ruta
	_namn.add_theme_font_size_override("font_size", 14 if k else 17)
	_namn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if k else TextServer.AUTOWRAP_OFF


func visa_nod(nod_id: String, replik_override := "") -> void:
	var nod: Dictionary = dialog.get(nod_id, {})
	if replik_override == "" or nod_id != _nod_id:
		_anvanda.clear()
	_nod_id = nod_id
	_replik.text = replik_override if replik_override != "" else str(nod.get("replik", "…"))
	# Vår egen replik först: nodens "du" (t.ex. hälsningen) eller det vi just sa.
	var du := _senast_sagt if _senast_sagt != "" else str(nod.get("du", ""))
	_senast_sagt = ""
	_du.text = "DU: – " + du if du != "" else ""
	_du.visible = du != ""
	if nod.has("stamning"):
		stamning = clampi(int(nod["stamning"]), 0, 8)
		_uppdatera_stamning()
	if replik_override == "":
		nod_visad.emit(nod)
	for c in _alternativ_lista.get_children():
		c.queue_free()
	for c in _atgard_rad.get_children():
		c.queue_free()
	_atgard_val.clear()
	_aktuella = nod.get("alternativ", [])
	_svar_rubrik.visible = not _aktuella.is_empty() or bool(nod.get("slut", false))
	# Utan svar och utan åtgärdsrad är samtalet slut.
	var utan_atgarder: bool = atgarder.is_empty() or nod.get("atgarder", {}) is bool
	_slut = bool(nod.get("slut", false)) or (_aktuella.is_empty() and utan_atgarder)
	if _slut:
		var b := UiKit.knapp("TILLBAKA TILL PASSET  [Enter]", true, UiKit.GRON)
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(_stang)
		_alternativ_lista.add_child(b)
		_atgard_rubrik.visible = false
		return
	for i in _aktuella.size():
		_alternativ_lista.add_child(_alternativrad(i, _aktuella[i]))
	_bygg_atgarder(nod)


## Åtgärdsknapparna. Nodens "atgarder" ersätter scenariots reaktioner;
## "atgarder": false i en nod döljer raden.
func _bygg_atgarder(nod: Dictionary) -> void:
	var egna: Variant = nod.get("atgarder", {})
	_atgard_rubrik.visible = egna is Dictionary and not atgarder.is_empty()
	if not _atgard_rubrik.visible:
		return
	for a in ATGARDER:
		var id := str(a[0])
		if not id in _atgard_lista:
			continue
		var reaktion: Dictionary = (egna as Dictionary).get(id, atgarder.get(id, {}))
		if reaktion.is_empty():
			continue
		var alt := reaktion.duplicate()
		alt["handling"] = id
		if not alt.has("text"):
			alt["text"] = str(a[1])
		if not alt.has("du") and (atgarder.get(id, {}) as Dictionary).has("du"):
			alt["du"] = atgarder[id]["du"]
		var etikett := str(a[1])
		if Spel.debug:
			etikett += "\n" + _spar(alt)
		var b := UiKit.knapp(etikett, true, UiKit.BARNSTEN)
		b.add_theme_font_size_override("font_size", 18 if UiKit.kompakt else 20)
		b.custom_minimum_size = Vector2(0, 40)
		# Knappen tar inte emot tryck själv; omslaget släpper igenom dragningar
		# till scrollningen och räknar bara ett "tryck" (släpp utan att dra) som val.
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var omslag := MarginContainer.new()
		omslag.mouse_filter = Control.MOUSE_FILTER_PASS
		omslag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		omslag.add_child(b)
		omslag.gui_input.connect(_pa_atgardstryck.bind(omslag, b, alt))
		b.disabled = _anvanda.has(id)
		_atgard_val.append(alt)
		_atgard_rad.add_child(omslag)
	# Man kan alltid avsluta samtalet utan att välja något.
	var avsluta := UiKit.knapp("Avsluta samtalet")
	avsluta.add_theme_font_size_override("font_size", 18 if UiKit.kompakt else 20)
	avsluta.custom_minimum_size = Vector2(0, 40)
	avsluta.pressed.connect(_stang)
	_atgard_rad.add_child(avsluta)


func _pa_atgardstryck(ev: InputEvent, omslag: Control, b: Button, alt: Dictionary) -> void:
	if not b.disabled and UiKit.ar_tryck(ev, omslag):
		_valj_alt(alt)


## Debug: bedömningen just nu och vart valet leder, t.ex. "(DISKUTABELT → lamnar)".
func _spar(alt: Dictionary) -> String:
	var delar: Array[String] = []
	var h := str(alt.get("handling", ""))
	if h != "":
		var b := Spel.forhandsbedom(h, alt.get("satt_fakta", {}))
		delar.append(str(UiKit.UTFALL.get(str(b.get("utfall", "")), {}).get("etikett", b.get("utfall", ""))))
	var nasta := _nasta(alt)
	if nasta != "":
		delar.append("→ " + nasta)
	elif alt.has("replik"):
		delar.append("→ (svarar)")
	else:
		delar.append("→ slut")
	return "(" + " ".join(delar) + ")"


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
	var text := str(alt.get("text", ""))
	if Spel.debug:
		text += "  " + _spar(alt)
	var t := UiKit.etikett(text, 21 if UiKit.kompakt else 24, UiKit.TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	ruta.gui_input.connect(_pa_alternativ_input.bind(i, ruta))
	return ruta


func _pa_alternativ_input(ev: InputEvent, i: int, ruta: Control) -> void:
	if UiKit.ar_tryck(ev, ruta):
		_valj(i)


func _valj(i: int) -> void:
	if i < 0 or i >= _aktuella.size():
		return
	_valj_alt(_aktuella[i])


## Väljer en åtgärd i raden (index i den ordning knapparna visas; används av testerna).
func valj_atgard(handling_id: String) -> bool:
	for alt in _atgard_val:
		if str(alt.get("handling", "")) == handling_id:
			_valj_alt(alt)
			return true
	return false


func _nasta(alt: Dictionary) -> String:
	var nasta := str(alt.get("nasta", ""))
	# "nasta_variant": olika fortsättning beroende på scenariots variant
	var per_variant: Dictionary = alt.get("nasta_variant", {})
	if per_variant.has(Spel.variant):
		nasta = str(per_variant[Spel.variant])
	return nasta


func _valj_alt(alt: Dictionary) -> void:
	if not _krympt:
		_satt_krympt(true)
	var h := str(alt.get("handling", ""))
	if h != "" and _anvanda.has(h):
		return
	if alt.has("replik") and _nasta(alt) == "" and h != "":
		_anvanda[h] = true
	stamning = clampi(stamning + int(alt.get("stamning", 0)), 0, 8)
	_uppdatera_stamning()
	# Citat i svaret (”…”) visas som det vi sa ovanför motpartens svar.
	var text := str(alt.get("text", ""))
	if alt.has("du"):
		_senast_sagt = str(alt["du"])
	elif text.count("”") >= 2:
		_senast_sagt = text.get_slice("”", 1).strip_edges()
	val_gjort.emit(alt)
	var nasta := _nasta(alt)
	if nasta == "" and alt.has("replik"):
		# Motparten svarar men samtalet står kvar i samma steg.
		visa_nod(_nod_id, str(alt["replik"]))
	elif nasta == "" or not dialog.has(nasta):
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
