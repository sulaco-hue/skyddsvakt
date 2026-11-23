extends Node
## Styr spelets flöde: briefing -> patrull (med kontaktläge) -> debriefing.

var varld: Varld
var rot: Control
var briefing: Briefing
var hud: Hud
var kontakt: Kontakt
var debriefing: Debriefing

var _handelser_kvar: Array = []
var _larm_npc := ""
var _samtal_klara: Dictionary = {}
var _vantar_samtal := ""
var _npc_efter_samtal := {}  # npc_id -> beteende
var _scenario: Dictionary
var _larm_har_skett := false
## Pågående upptäckt: {npc, h, bas, varde}. Tom när ingen upptäckt pågår.
var _upptackt: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var snack: Kamratsnack
var dronare: Dronare
## Radiobrus: trafik mellan andra enheter (data/radiobrus.json).
var _brus: Dictionary = {}
var _brus_t := 0.0
## Status per startad händelse: id -> {h, start_s, slut_s, upptackt, narmast}
var _handelse_status: Dictionary = {}
## Personer som lämnat platsen innan kontakt togs.
var _lamnat: Dictionary = {}
var _dronare_handelse: Dictionary = {}


func _ready() -> void:
	_scenario = Spel.scenario
	if _scenario.is_empty():
		_visa_scenarioval()
		return
	varld = Varld.new()
	add_child(varld)
	varld.bygg(Spel.karta)
	var npcer: Dictionary = _scenario.get("npc", {})
	for id: String in npcer:
		varld.skapa_npc(id, npcer[id])
	varld.npc_klickad.connect(_pa_npc_klickad)
	varld.spelare_framme.connect(_pa_spelare_framme)

	var lager := CanvasLayer.new()
	add_child(lager)
	rot = Control.new()
	UiKit.helskarm(rot)
	rot.theme = UiKit.skapa_tema()
	rot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lager.add_child(rot)

	hud = Hud.new()
	rot.add_child(hud)
	hud.bygg(_scenario, varld)
	hud.visible = false
	hud.forcera_handelse.connect(_forcera_handelse)
	hud.handling.connect(func(id: String, beskrivning: String) -> void: Spel.utfor(id, beskrivning))
	hud.avsluta_pass.connect(_visa_debriefing)
	hud.lagestext = _lagestext
	hud.situation.connect(_bekampa_dronare)

	snack = Kamratsnack.new()
	add_child(snack)
	snack.setup(hud, varld, _scenario)
	hud.tysta_kamrat.connect(snack.tysta)
	varld.kamrat_klickad.connect(snack.tysta)

	kontakt = Kontakt.new()
	rot.add_child(kontakt)
	kontakt.bygg(_scenario)
	kontakt.visible = false
	kontakt.val_gjort.connect(_pa_val)
	kontakt.nod_visad.connect(func(nod: Dictionary) -> void: Spel.satt_fakta(nod.get("satt_fakta", {})))
	kontakt.stangd.connect(_pa_kontakt_stangd)

	var handelser: Array = _scenario.get("handelser", [])
	_handelser_kvar = handelser.duplicate(true)

	briefing = Briefing.new()
	rot.add_child(briefing)
	briefing.bygg(_scenario)
	briefing.starta.connect(_starta_pass)
	rot.add_child(VridOverlay.new())


func _visa_scenarioval() -> void:
	var lager := CanvasLayer.new()
	add_child(lager)
	rot = Control.new()
	UiKit.helskarm(rot)
	rot.theme = UiKit.skapa_tema()
	lager.add_child(rot)
	var val := Scenarioval.new()
	rot.add_child(val)
	val.bygg(Spel.scenarier())
	val.valt.connect(_valj_scenario)
	rot.add_child(VridOverlay.new())


func _valj_scenario(sokvag: String) -> void:
	Spel.nollstall(sokvag)
	get_tree().reload_current_scene()


func _lagestext() -> String:
	var lt: Dictionary = _scenario.get("lagestext", {})
	return str(lt.get("efter" if _larm_har_skett else "fore", ""))


func _starta_pass() -> void:
	briefing.queue_free()
	briefing = null
	hud.visible = true
	varld.interaktion_aktiv = true
	varld.kamrat_folj = true
	snack.aktiv = true
	Spel.klocka_igang = true


func _process(delta: float) -> void:
	if not Spel.klocka_igang:
		return
	_uppdatera_upptackt(delta)
	_uppdatera_brus(delta)
	if hud.debug_info_synlig():
		hud.satt_debug_info(_debug_text())
	for h in _handelser_kvar.duplicate():
		if Spel.klocka_s >= Datafil.tid_till_s(str(h.get("tid", "00:00"))):
			_handelser_kvar.erase(h)
			_utlos_handelse(h)


func _debug_text() -> String:
	var rader := PackedStringArray()
	var kvar := PackedStringArray()
	for h in _handelser_kvar:
		kvar.append("%s (%s)" % [h.get("id", "?"), h.get("tid", "")])
	rader.append("Klocka %s · tidsfaktor x%s · händelser kvar: %s" % [
		Spel.klockstrang(), _scenario.get("tidsfaktor", 1), ", ".join(kvar) if kvar.size() > 0 else "inga"])
	var sp := varld.spelare
	rader.append("Spelare %s zon %s %s · Kamrat %s %s" % [sp.cell, varld.zon(sp.cell),
		"går" if sp.ar_i_rorelse() else "står", varld.kollega.cell, "går" if varld.kollega.ar_i_rorelse() else "står"])
	for id: String in varld.npcer:
		var n: Aktor = varld.npcer[id]
		rader.append("NPC %s %s synlig:%s %s avstånd %d" % [id, n.cell, "ja" if n.visible else "nej",
			"går" if n.ar_i_rorelse() else "står", varld.avstand(sp.cell, n.cell)])
	if _upptackt.is_empty():
		rader.append("Upptäckt: ingen pågår%s" % (" (händelse upptäckt)" if _larm_har_skett else ""))
	else:
		rader.append("Upptäckt: %d %% · grundtid %.1f s · har pågått %.1f s" % [
			int(float(_upptackt["varde"]) * 100.0), float(_upptackt["bas"]), float(_upptackt["tid"])])
	var f := PackedStringArray()
	for k in Spel.fakta:
		f.append("%s=%s" % [k, "ja" if Spel.fakta[k] else "nej"])
	rader.append("Fakta: " + ", ".join(f))
	rader.append("Kamratsnack: " + snack.status() + " · skyddsobjekt: " + Spel.objekttyp + " · variant: " + Spel.variant)
	rader.append("Beslut i logg: %d · sambandsrader: %d · musik: %s" % [Spel.logg.size(), Spel.samband.size(),
		"på" if Musik.ar_pa() else "av"])
	return "\n".join(rader)


## id kan vara "1" eller "1:variant" (debugraden).
func _uppdatera_brus(delta: float) -> void:
	if _brus.is_empty():
		_brus = Datafil.las_json("res://data/radiobrus.json")
		_brus_t = float(_brus.get("installningar", {}).get("forsta_efter_s", 20))
		return
	if kontakt.visible:
		return
	_brus_t -= delta
	if _brus_t > 0.0:
		return
	var inst: Dictionary = _brus.get("installningar", {})
	_brus_t = _rng.randf_range(float(inst.get("intervall_min_s", 30)), float(inst.get("intervall_max_s", 70)))
	var vaxlingar: Array = _brus.get("vaxlingar", [])
	if not vaxlingar.is_empty():
		Spel.spela_samband(vaxlingar[_rng.randi_range(0, vaxlingar.size() - 1)])


func _forcera_handelse(id: String) -> void:
	var delar := id.split(":")
	for h in _handelser_kvar.duplicate():
		if str(h.get("id", "")) == delar[0]:
			_handelser_kvar.erase(h)
			if delar.size() > 1:
				h["vald_variant"] = delar[1]
			_utlos_handelse(h)
			return
	hud.visa_meddelande("Händelse %s har redan startat." % id, 2.0)


func _utlos_handelse(h: Dictionary) -> void:
	hud.markera_handelse_startad(str(h.get("id", "")))
	_handelse_status[str(h.get("id", ""))] = {
		"h": h, "start_s": Spel.klocka_s, "start": Spel.klockstrang(), "slut_s": -1.0,
		"upptackt": false, "narmast": 999,
	}
	match str(h.get("typ", "")):
		"npc_gar_till":
			var id := str(h.get("npc", ""))
			var n: Aktor = varld.npcer.get(id)
			if n == null:
				return
			n.visible = true
			n.framme.connect(_pa_npc_framme.bind(h, id), CONNECT_ONE_SHOT)
			varld.flytta_npc(id, varld.punkt(h.get("mal", [0, 0])))
		"dronare":
			_starta_dronare(h)


func _pa_npc_framme(h: Dictionary, id: String) -> void:
	var n: Aktor = varld.npcer.get(id)
	if n == null or h.get("vid_framme", "") != "fotograferar" or _samtal_klara.has(id):
		return
	n.vand_mot(varld.cell_pos(varld.punkt("objekt_mitt")))
	n.satt_fotograferar(true)
	if not n.blixt.is_connected(_pa_blixt):
		n.blixt.connect(_pa_blixt.bind(id))
	_larm_npc = id
	_starta_upptackt(h, n, id)
	var lamnar := float(h.get("lamnar_efter_s", 0))
	if lamnar > 0.0:
		get_tree().create_timer(lamnar).timeout.connect(_npc_lamnar.bind(id, h))


## Personen ger sig av om ingen kontakt tagits (t.ex. fotografen efter 30 s).
func _npc_lamnar(id: String, h: Dictionary) -> void:
	var n: Aktor = varld.npcer.get(id)
	if n == null or not n.visible or _samtal_klara.has(id):
		return
	if kontakt.visible and str(kontakt.get_meta("npc", "")) == id:
		return
	_lamnat[id] = true
	_samtal_klara[id] = true
	n.satt_fotograferar(false)
	if not _upptackt.is_empty() and str(_upptackt["npc"]) == id:
		_upptackt = {}
	if _larm_npc == id:
		varld.satt_larm("")
	if _vantar_samtal == id:
		_vantar_samtal = ""
	_avsluta_handelse(h)
	var data: Dictionary = _scenario.get("npc", {}).get(id, {})
	if str(data.get("lamnar_replik", "")) != "" and hud.visible:
		hud.visa_bubbla(n, str(data.get("lamnar_replik", "")), 3.0)
	n.framme.connect(_dolj_npc.bind(id), CONNECT_ONE_SHOT)
	varld.flytta_npc(id, varld.punkt(data.get("start", [0, 0])))


func _markera_upptackt(h: Dictionary) -> void:
	var hs: Dictionary = _handelse_status.get(str(h.get("id", "")), {})
	if not hs.is_empty():
		hs["upptackt"] = true


func _avsluta_handelse(h: Dictionary) -> void:
	var hs: Dictionary = _handelse_status.get(str(h.get("id", "")), {})
	if not hs.is_empty() and float(hs["slut_s"]) < 0.0:
		hs["slut_s"] = Spel.klocka_s


## Startar kamratens upptäcktstimer mot en nod (figur eller drönare):
## slumpad grundtid, snabbare ju närmare.
func _starta_upptackt(h: Dictionary, nod: Node2D, npc_id: String) -> void:
	var u: Dictionary = h.get("upptackt", {})
	_rng.randomize()
	_upptackt = {
		"npc": npc_id,
		"nod": nod,
		"h": h,
		"bas": _rng.randf_range(float(u.get("min_s", 6)), float(u.get("max_s", 30))),
		"ref": float(u.get("referensavstand", 6)),
		"max": int(u.get("max_avstand", 14)),
		"varde": 0.0,
		"tid": 0.0,
	}


# ------------------------------------------------------------ Drönare --

func _starta_dronare(h: Dictionary) -> void:
	_dronare_handelse = h
	var varianter: Array = h.get("varianter", ["med_pilot"])
	var variant := str(h.get("vald_variant", ""))
	if variant == "":
		_rng.randomize()
		variant = "utan_pilot" if _rng.randf() < float(h.get("chans_utan_pilot", 0.3)) else str(varianter[0])
	Spel.satt_variant(variant)
	var med_pilot := variant != "utan_pilot"
	for id: String in h.get("visa_npc_med_pilot", []):
		var n: Aktor = varld.npcer.get(id)
		if n:
			n.visible = med_pilot
	var start := varld.punkt(h.get("start_med_pilot" if med_pilot else "start_utan_pilot", [0, 0]))
	dronare = Dronare.new()
	varld.add_child(dronare)
	dronare.setup(varld.cell_pos(start) + Vector2(10, 0), varld.dekal_lager)
	dronare.ljud.connect(_pa_dronarljud)
	dronare.framme.connect(_pa_dronare_framme, CONNECT_ONE_SHOT)
	dronare.flyg_till(varld.cell_pos(varld.punkt(h.get("mal", "objekt_mitt"))))
	if not med_pilot:
		var sek := float(h.get("utan_pilot_flyger_s", 60))
		get_tree().create_timer(sek).timeout.connect(_dronare_flyger_bort)


func _kamrat_sager(text: String) -> void:
	if hud.visible:
		hud.visa_bubbla(varld.kollega, text, 5.0)


func _pa_dronare_framme() -> void:
	if dronare == null or not dronare.i_luften():
		return
	dronare.cirkla(varld.cell_pos(varld.punkt(_dronare_handelse.get("mal", "objekt_mitt"))))
	_starta_upptackt(_dronare_handelse, dronare, "")


func _pa_dronarljud(text: String) -> void:
	if hud.visible and dronare:
		hud.visa_ljud(dronare.ljudpunkt, text, 1.3, 10.0)


func _dronare_flyger_bort() -> void:
	if dronare == null or not dronare.i_luften():
		return
	hud.satt_situation("", false)
	_avsluta_handelse(_dronare_handelse)
	if not _upptackt.is_empty() and _upptackt["nod"] == dronare:
		_upptackt = {}
	dronare.flyg_till(varld.cell_pos(varld.punkt(_dronare_handelse.get("bort_utan_pilot", "kant_sydvast"))), 60.0)
	dronare.framme.connect(_ta_bort_dronare, CONNECT_ONE_SHOT)


func _ta_bort_dronare() -> void:
	if dronare:
		dronare.queue_free()
		dronare = null


func _landa_dronare() -> void:
	if dronare == null or not dronare.i_luften():
		return
	hud.satt_situation("", false)
	var plats := varld.punkt(_dronare_handelse.get("start_med_pilot", [0, 0]))
	dronare.landa_vid(varld.cell_pos(plats) + Vector2(10, 4))


## Situationsknappen: bekämpa drönaren med vapen (ett beslut som bedöms).
func _bekampa_dronare() -> void:
	if dronare == null or not dronare.i_luften():
		return
	hud.satt_situation("", false)
	_markera_upptackt(_dronare_handelse)
	if not _upptackt.is_empty() and _upptackt["nod"] == dronare:
		_upptackt = {}
	Spel.utfor("vald_mot_farkost", "Bekämpade drönaren med automatkarbin")
	hud.visa_ljud(varld.spelare, "PANG PANG", 1.5)
	dronare.krascha()
	varld.kollega.vand_mot(dronare.global_position)
	var efter := str(_dronare_handelse.get("kamrat_efter_skott", "…Det där kommer AQ inte gilla."))
	get_tree().create_timer(1.8).timeout.connect(_kamrat_sager.bind(efter))
	for id: String in _dronare_handelse.get("visa_npc_med_pilot", []):
		var n: Aktor = varld.npcer.get(id)
		var replik := str(_scenario.get("npc", {}).get(id, {}).get("efter_skott", ""))
		if n and n.visible and replik != "":
			hud.visa_bubbla(n, replik, 5.0)


func _pa_blixt(id: String) -> void:
	var n: Aktor = varld.npcer.get(id)
	var ljud: Dictionary = _scenario.get("npc", {}).get(id, {}).get("ljud", {})
	if n and hud.visible:
		hud.visa_ljud(n, str(ljud.get("fotograferar", "klick klick")))


func _uppdatera_upptackt(delta: float) -> void:
	if _upptackt.is_empty():
		hud.satt_debug_status("ingen upptäckt pågår")
		return
	var nod: Node2D = _upptackt["nod"]
	if not is_instance_valid(nod):
		_upptackt = {}
		return
	var cell := varld.cell_av(nod.global_position)
	var avst := mini(varld.avstand(varld.spelare.cell, cell), varld.avstand(varld.kollega.cell, cell))
	_upptackt["tid"] = float(_upptackt["tid"]) + delta
	var hs: Dictionary = _handelse_status.get(str(_upptackt["h"].get("id", "")), {})
	if not hs.is_empty():
		hs["narmast"] = mini(int(hs["narmast"]), avst)
	# För långt bort: timern står still tills ni kommer närmare.
	if avst > int(_upptackt["max"]):
		hud.satt_debug_status("kamraten upptäcker: %d %% · PAUSAD, avstånd %d > %d" % [
			int(float(_upptackt["varde"]) * 100.0), avst, int(_upptackt["max"])])
		return
	var narhet := clampf(float(_upptackt["ref"]) / maxf(float(avst), 1.0), 0.3, 3.0)
	_upptackt["varde"] = float(_upptackt["varde"]) + delta * narhet / float(_upptackt["bas"])
	hud.satt_debug_status("kamraten upptäcker: %d %% · avstånd %d · grundtid %.0f s" % [
		int(float(_upptackt["varde"]) * 100.0), avst, float(_upptackt["bas"])])
	if float(_upptackt["varde"]) >= 1.0:
		_kamrat_reagerar()


func _kamrat_reagerar() -> void:
	var id := str(_upptackt["npc"])
	var h: Dictionary = _upptackt["h"]
	var nod: Node2D = _upptackt["nod"]
	_upptackt = {}
	_markera_upptackt(h)
	_larm_har_skett = true
	snack.pausa(float(h.get("upptackt", {}).get("paus_snack_s", 60)))
	if id != "":
		varld.satt_larm(id)
	Spel.spela_samband(h.get("samband", []))
	if str(h.get("kamrat", "")) != "":
		hud.visa_bubbla(varld.kollega, str(h.get("kamrat", "")), 5.0)
	if is_instance_valid(nod):
		varld.kollega.vand_mot(nod.global_position)
	# Ev. ledtråd från kamraten en stund senare (per variant).
	var ledtradar: Dictionary = h.get("kamrat_ledtrad", {})
	var ledtrad := str(ledtradar.get(Spel.variant, ""))
	if ledtrad != "":
		get_tree().create_timer(5.5).timeout.connect(_kamrat_sager.bind(ledtrad))
	if dronare and dronare.i_luften():
		hud.satt_situation(str(_dronare_handelse.get("situationsknapp", "Bekämpa drönaren")), true)


func _dolj_npc(id: String) -> void:
	var n: Aktor = varld.npcer.get(id)
	if n:
		n.visible = false


# ----------------------------------------------------------- Kontakt --

func _pa_npc_klickad(id: String) -> void:
	if _lamnat.has(id):
		hud.visa_meddelande("Personen har lämnat platsen.")
		return
	if _samtal_klara.has(id):
		hud.visa_meddelande("Kontakten med personen är redan avslutad.")
		return
	_ga_till_samtal(id)


func _ga_till_samtal(id: String) -> void:
	var n: Aktor = varld.npcer.get(id)
	if n == null or not n.visible:
		return
	if varld.avstand(varld.spelare.cell, n.cell) <= 3:
		_oppna_kontakt(id)
		return
	if varld.ga_till(n.cell):
		_vantar_samtal = id
		hud.visa_meddelande("Går närmare…", 1.5)
	else:
		hud.visa_meddelande("Du kan inte ta dig närmare härifrån.")


func _pa_spelare_framme() -> void:
	if _vantar_samtal == "":
		return
	var id := _vantar_samtal
	_vantar_samtal = ""
	var n: Aktor = varld.npcer.get(id)
	if n and varld.avstand(varld.spelare.cell, n.cell) <= 3:
		_oppna_kontakt(id)
	else:
		hud.visa_meddelande("För långt bort för att tilltala personen.")


func _oppna_kontakt(id: String) -> void:
	var n: Aktor = varld.npcer[id]
	varld.spelare.stanna()
	varld.spelare.vand_mot(n.position)
	n.vand_mot(varld.spelare.position)
	n.satt_fotograferar(false)
	# Spelaren upptäckte själv händelsen före kamraten (kontakt = upptäckt).
	for hid: String in _handelse_status:
		var hs: Dictionary = _handelse_status[hid]
		var h: Dictionary = hs["h"]
		var inblandade: Array = h.get("visa_npc_med_pilot", []) + [str(h.get("npc", ""))]
		if id in inblandade:
			_markera_upptackt(h)
	if not _upptackt.is_empty() and str(_upptackt["npc"]) in [id, ""]:
		_upptackt = {}
		_larm_har_skett = true
	varld.kollega.stanna()
	varld.kollega.vand_mot(n.position)
	varld.interaktion_aktiv = false
	hud.visible = false
	snack.aktiv = false
	var data: Dictionary = _scenario.get("npc", {}).get(id, {})
	kontakt.set_meta("npc", id)
	kontakt.oppna(data, str(data.get("dialog_start", "start")))


func _pa_val(alt: Dictionary) -> void:
	Spel.satt_fakta(alt.get("satt_fakta", {}))
	var handling := str(alt.get("handling", ""))
	if handling != "":
		Spel.utfor(handling, str(alt.get("text", "")))
	var beteende := str(alt.get("npc_beteende", ""))
	if beteende == "landa_dronare":
		_landa_dronare()
	elif beteende != "":
		_npc_efter_samtal[str(kontakt.get_meta("npc", ""))] = beteende


func _pa_kontakt_stangd() -> void:
	var id := str(kontakt.get_meta("npc", ""))
	_samtal_klara[id] = true
	hud.visible = true
	varld.satt_larm("")
	varld.interaktion_aktiv = true
	snack.aktiv = true
	snack.pausa(30.0)
	hud.visa_meddelande("Kom ihåg: rapportera och dokumentera händelsen.", 4.0)
	if _npc_efter_samtal.get(id, "") == "ga_till_start":
		var n: Aktor = varld.npcer[id]
		var data: Dictionary = _scenario.get("npc", {}).get(id, {})
		n.framme.connect(_dolj_npc.bind(id), CONNECT_ONE_SHOT)
		varld.flytta_npc(id, varld.punkt(data.get("start", [0, 0])))


# -------------------------------------------------------- Debriefing --

func _visa_debriefing() -> void:
	if debriefing:
		return
	Spel.klocka_igang = false
	snack.aktiv = false
	varld.interaktion_aktiv = false
	hud.visible = false
	kontakt.visible = false
	for hid: String in _handelse_status:
		var hs: Dictionary = _handelse_status[hid]
		if bool(hs["upptackt"]):
			continue
		var h: Dictionary = hs["h"]
		var slut := float(hs["slut_s"]) if float(hs["slut_s"]) >= 0.0 else Spel.klocka_s
		var speltid := int((slut - float(hs["start_s"])) / 60.0)
		var narmast := int(hs["narmast"])
		var var_text := ("Som närmast var ni %d rutor bort." % narmast) if narmast < 999 else ""
		Spel.lagg_till_missad({
			"tid": str(hs["start"]),
			"handling": "missad_" + hid,
			"namn": "Missad händelse",
			"beskrivning": "Missad händelse: " + str(h.get("namn", hid)) + (" (%s)" % Spel.variant.replace("_", " ") if Spel.variant != "" else ""),
			"utfall": "bad",
			"lagrum": "Bevakningsinstruktion – uppmärksamhet",
			"kommentar": "Händelsen pågick i cirka %d minuter speltid utan att stridsparet upptäckte den. %s" % [maxi(speltid, 1), var_text],
			"diskutera": str(h.get("missad_diskutera", "Var borde stridsparet ha befunnit sig? Hur fördelar ni uppmärksamheten under en rond?")),
			"saknade_krav": [],
		})
	debriefing = Debriefing.new()
	rot.add_child(debriefing)
	var meta := Spel.regelmotor.meta
	debriefing.bygg(Spel.slutlogg(), _scenario, Spel.regelmotor.ar_granskad(), str(meta.get("kommentar", "")))
	debriefing.spela_igen.connect(_spela_igen)
	debriefing.byt_scenario.connect(_byt_scenario)


func _byt_scenario() -> void:
	Spel.avsluta_scenario()
	get_tree().reload_current_scene()


func _spela_igen() -> void:
	Spel.nollstall()
	get_tree().reload_current_scene()
