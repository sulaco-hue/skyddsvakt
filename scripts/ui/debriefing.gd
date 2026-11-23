class_name Debriefing
extends Control
## Debriefing: tidslinje över beslut med lagrum och bedömning.

signal spela_igen
signal byt_scenario

var _poster: Array = []
var _rader: Array[PanelContainer] = []
var _vald := 0
var _analys: PanelContainer
var _a_utfall: Label
var _a_tid: Label
var _a_rubrik: Label
var _a_lagrum: Label
var _a_kommentar: Label
var _a_krav_rubrik: Label
var _a_krav: Label
var _a_ok_rubrik: Label
var _a_ok: Label
var _a_diskutera: Label
var _status: Label


func bygg(poster: Array, scenario: Dictionary, granskad: bool, kommentar: String) -> void:
	_poster = poster
	UiKit.helskarm(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := UiKit.ruta_farg(UiKit.BG, Vector2.ZERO)
	UiKit.helskarm(bg)
	add_child(bg)
	var marg := MarginContainer.new()
	UiKit.helskarm(marg)
	for s in ["margin_left", "margin_right"]:
		marg.add_theme_constant_override(s, 32)
	for s in ["margin_top", "margin_bottom"]:
		marg.add_theme_constant_override(s, 28)
	marg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marg)
	var kol := UiKit.vbox(16)
	marg.add_child(kol)

	# Rubrikrad med sammanfattning
	var topp := UiKit.hbox(16)
	topp.add_child(UiKit.titel("Debriefing · " + str(scenario.get("pass", ""))))
	var under := UiKit.etikett(str(scenario.get("namn", "")), 22, UiKit.DAMPAD)
	under.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	topp.add_child(under)
	topp.add_child(UiKit.fyllnad())
	var antal := {"ok": 0, "warn": 0, "bad": 0}
	for p in poster:
		var u := str(p.get("utfall", "warn"))
		antal[u] = int(antal.get(u, 0)) + 1
	for u in ["ok", "warn", "bad"]:
		var chip := UiKit.panel(UiKit.KANT, Color(0, 0, 0, 0), 12, 4)
		var ch := UiKit.hbox(8)
		chip.add_child(ch)
		var ik := UiKit.utfallsikon(u, 18)
		ik.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ch.add_child(ik)
		var etikett_text := {"ok": "lagstöd", "warn": "diskutabelt", "bad": "saknar lagstöd"}
		ch.add_child(UiKit.etikett("%d %s" % [antal[u], etikett_text[u]], 20))
		topp.add_child(chip)
	kol.add_child(topp)

	if not granskad:
		var varning := UiKit.panel(UiKit.BARNSTEN, Color(0.95, 0.69, 0.2, 0.08), 14, 6)
		varning.add_child(UiKit.etikett("EJ JURIDISKT GRANSKAT · " + kommentar, 19, UiKit.BARNSTEN, true))
		kol.add_child(varning)

	var mitt := UiKit.hbox(20)
	mitt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kol.add_child(mitt)

	# Tidslinje
	var vanster := UiKit.vbox(8)
	vanster.custom_minimum_size = Vector2(420 if UiKit.kompakt else 580, 0)
	mitt.add_child(vanster)
	vanster.add_child(UiKit.rubrik("TIDSLINJE – VÄLJ ETT BESLUT", 13, UiKit.DAMPAD))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vanster.add_child(scroll)
	var lista := UiKit.vbox(8)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)
	if poster.is_empty():
		lista.add_child(UiKit.etikett("Inga beslut registrerades under passet.", 22, UiKit.DAMPAD))
	for i in poster.size():
		var rad := _tidslinjerad(i, poster[i])
		_rader.append(rad)
		lista.add_child(rad)

	# Analys
	_analys = UiKit.panel(UiKit.KANT2, UiKit.RUTA, 22, 18)
	_analys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mitt.add_child(_analys)
	var ascroll := ScrollContainer.new()
	ascroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_analys.add_child(ascroll)
	var av := UiKit.vbox(10)
	av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	av.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ascroll.add_child(av)
	var ar := UiKit.hbox(12)
	_a_utfall = UiKit.rubrik("", 14)
	ar.add_child(_a_utfall)
	_a_tid = UiKit.etikett("", 20, UiKit.DAMPAD)
	ar.add_child(_a_tid)
	av.add_child(ar)
	_a_rubrik = UiKit.titel("", 20)
	_a_rubrik.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	av.add_child(_a_rubrik)
	av.add_child(UiKit.rubrik("LAGRUM", 13, UiKit.DAMPAD))
	_a_lagrum = UiKit.etikett("", 22, UiKit.TEXT, true)
	av.add_child(_a_lagrum)
	av.add_child(UiKit.rubrik("BEDÖMNING", 13, UiKit.DAMPAD))
	_a_kommentar = UiKit.etikett("", 22, UiKit.TEXT, true)
	av.add_child(_a_kommentar)
	_a_ok_rubrik = UiKit.rubrik("UPPFYLLDA REKVISIT", 13, UiKit.DAMPAD)
	av.add_child(_a_ok_rubrik)
	_a_ok = UiKit.etikett("", 21, UiKit.GRON, true)
	av.add_child(_a_ok)
	_a_krav_rubrik = UiKit.rubrik("EJ UPPFYLLDA REKVISIT", 13, UiKit.DAMPAD)
	av.add_child(_a_krav_rubrik)
	_a_krav = UiKit.etikett("", 22, UiKit.BARNSTEN, true)
	av.add_child(_a_krav)
	av.add_child(UiKit.rubrik("ATT DISKUTERA", 13, UiKit.DAMPAD))
	_a_diskutera = UiKit.etikett("", 22, UiKit.LJUS, true)
	av.add_child(_a_diskutera)
	av.add_child(UiKit.fyllnad())
	_status = UiKit.etikett("", 19, UiKit.GRON, true)
	av.add_child(_status)
	var knappar := UiKit.hbox(10)
	var spara := UiKit.knapp("SPARA LOGG FÖR INSTRUKTÖR")
	spara.pressed.connect(_spara)
	knappar.add_child(spara)
	knappar.add_child(UiKit.fyllnad())
	var byt := UiKit.knapp("BYT SCENARIO")
	byt.pressed.connect(func() -> void: byt_scenario.emit())
	knappar.add_child(byt)
	var igen := UiKit.knapp("SPELA IGEN", true, UiKit.GRON)
	igen.pressed.connect(func() -> void: spela_igen.emit())
	knappar.add_child(igen)
	av.add_child(knappar)

	# Börja med det första beslutet som saknar lagstöd, annars det första.
	_vald = 0
	for i in poster.size():
		if poster[i].get("utfall", "") == "bad":
			_vald = i
			break
	_visa(_vald)


func _spara() -> void:
	var sokvag := Spel.spara_logg()
	_status.text = ("Sparad: " + sokvag) if sokvag != "" else "Kunde inte spara loggen."


func _tidslinjerad(i: int, post: Dictionary) -> PanelContainer:
	var ruta := UiKit.klickruta(UiKit.KANT, UiKit.RUTA, UiKit.KANT2)
	var h := UiKit.hbox(14)
	ruta.add_child(h)
	var tid := UiKit.etikett(str(post.get("tid", "")), 20, UiKit.DAMPAD)
	tid.custom_minimum_size = Vector2(56, 0)
	h.add_child(tid)
	var ik := UiKit.utfallsikon(str(post.get("utfall", "warn")), 22)
	ik.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ik)
	var t := UiKit.etikett(str(post.get("beskrivning", post.get("namn", ""))), 22, UiKit.TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	ruta.gui_input.connect(_pa_rad_input.bind(i, ruta))
	return ruta


func _pa_rad_input(ev: InputEvent, i: int, ruta: Control) -> void:
	if UiKit.ar_tryck(ev, ruta):
		_visa(i)


func _visa(i: int) -> void:
	if _poster.is_empty():
		_a_rubrik.text = "Inga beslut att visa."
		_a_utfall.text = ""
		_a_krav_rubrik.visible = false
		return
	_vald = i
	var post: Dictionary = _poster[i]
	var info: Dictionary = UiKit.UTFALL.get(str(post.get("utfall", "warn")), UiKit.UTFALL["warn"])
	var farg: Color = info["farg"]
	_a_utfall.text = str(info["etikett"])
	_a_utfall.add_theme_color_override("font_color", farg)
	_a_tid.text = "kl " + str(post.get("tid", ""))
	_a_rubrik.text = str(post.get("beskrivning", ""))
	_a_lagrum.text = str(post.get("lagrum", ""))
	_a_kommentar.text = str(post.get("kommentar", ""))
	var krav: Array = post.get("saknade_krav", [])
	_a_krav_rubrik.visible = not krav.is_empty()
	_a_krav.visible = not krav.is_empty()
	var lasbara := PackedStringArray()
	for k in krav:
		lasbara.append("– " + str(k))
	_a_krav.text = "\n".join(lasbara)
	var ok: Array = post.get("uppfyllda_krav", [])
	var oklista := PackedStringArray()
	for k in ok:
		oklista.append("+ " + str(k))
	_a_ok.text = "\n".join(oklista)
	_a_ok_rubrik.visible = not ok.is_empty()
	_a_ok.visible = not ok.is_empty()
	_a_diskutera.text = str(post.get("diskutera", ""))
	_analys.add_theme_stylebox_override("panel", UiKit.ruta(UiKit.RUTA, farg, 3, 22, 18))
	for j in _rader.size():
		var vald := j == i
		var kant: Color = UiKit.KANT
		if vald:
			var rad_info: Dictionary = UiKit.UTFALL.get(str(_poster[j].get("utfall", "warn")), UiKit.UTFALL["warn"])
			kant = rad_info["farg"]
		var stil := UiKit.ruta(UiKit.KNAPP_HOVER if vald else UiKit.RUTA, kant, 3, 16, 10)
		_rader[j].set_meta("normal", stil)
		_rader[j].add_theme_stylebox_override("panel", stil)
