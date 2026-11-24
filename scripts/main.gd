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
## Fordon som hör till en person: id -> {sprite, cell}
var _fordon: Dictionary = {}
var _dronare_handelse: Dictionary = {}
var radio: Radiotrafik
## Horde (scenario Zombieapokalypsen): {h, zombies: {id: {lage, omvag_t}}, kvar_att_spawna,
## spawn_t, upptackt, replik_t, banter_i, banter_t, kommenterat}
var _horde: Dictionary = {}
## Frihetsberövade som sitter vid grinden och muttrar: id -> {t, i, repliker, intervall}
var _sittande: Dictionary = {}
## Angripare (scenario Yxmannen): {h, id, lage, omvag_t, replik_t, replik_i, kamrat_nara}
## lage: "anfaller", "gett_upp", "skjuten", "overmannad".
var _angripare: Dictionary = {}


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
	hud.handling.connect(_pa_hud_handling)
	hud.avsluta_pass.connect(_visa_debriefing)
	hud.ersattningar = _radio_ersattningar
	hud.situation.connect(_pa_situation)

	radio = Radiotrafik.new()
	add_child(radio)
	radio.setup(_scenario)
	radio.ersattningar = _radio_ersattningar
	Spel.logg_ny.connect(_pa_logg_post)

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
	if not Spel.titel_visad:
		var titel := Titelskarm.new()
		rot.add_child(titel)
		titel.bygg()
		titel.fortsatt.connect(_efter_titel.bind(titel))
		rot.add_child(VridOverlay.new())
		return
	_bygg_scenarioval()


func _efter_titel(titel: Control) -> void:
	Spel.titel_visad = true
	titel.queue_free()
	_bygg_scenarioval()


func _bygg_scenarioval() -> void:
	var val := Scenarioval.new()
	rot.add_child(val)
	val.bygg(Spel.scenarier())
	val.valt.connect(_valj_scenario)
	rot.add_child(VridOverlay.new())


func _valj_scenario(sokvag: String) -> void:
	Spel.nollstall(sokvag)
	get_tree().reload_current_scene()


func _pa_hud_handling(id: String, beskrivning: String) -> void:
	# "Anteckna" blir protokoll enligt 16 § när en åtgärd kräver det.
	if id == "dokumentera" and Spel.protokoll_kravs():
		Spel.utfor("uppratta_protokoll", "Upprättade protokoll över åtgärden")
		hud.visa_meddelande("Protokoll upprättat (16 §)")
		return
	Spel.utfor(id, beskrivning)


## Ersättningar i radiotrafiken efter läget just nu: {lage} från "lagestext"
## och en ersättning per nyckel i "sambandstexter" (t.ex. {svar} och {polis}),
## så att vi inte rapporterar en drönare över objektet när den redan är nedskjuten.
func _radio_ersattningar() -> Dictionary:
	var byt := {"lage": _lagestext()}
	var st: Dictionary = _scenario.get("sambandstexter", {})
	for nyckel: String in st:
		byt[nyckel] = _fasvarde(st[nyckel])
	return byt


func _lagestext() -> String:
	return _fasvarde(_scenario.get("lagestext", {}))


## Väljer text efter händelsens fas. Nycklar i prioritetsordning:
## "fakta:<nyckel>" (när faktumet är sant, i filens ordning), "avslutad",
## "lamnat" (personen gav sig av), "kontakt" (efter avslutad kontakt),
## "efter" (efter upptäckt) och "fore"; alla även per variant, t.ex. "kontakt_oriktig".
func _fasvarde(lt: Dictionary) -> String:
	for nyckel: String in lt:
		if nyckel.begins_with("fakta:") and bool(Spel.fakta.get(nyckel.substr(6), false)):
			return str(lt[nyckel])
	var faser: Array[String] = []
	if bool(Spel.fakta.get("lage_avslutat", false)):
		faser.append("avslutad")
	if not _lamnat.is_empty():
		faser.append("lamnat")
	if not _samtal_klara.is_empty():
		faser.append("kontakt")
	if _larm_har_skett:
		faser.append("efter")
	faser.append("fore")
	for fas in faser:
		if Spel.variant != "" and lt.has(fas + "_" + Spel.variant):
			return str(lt[fas + "_" + Spel.variant])
		if lt.has(fas):
			return str(lt[fas])
	return ""


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
	_uppdatera_angripare(delta)
	_uppdatera_horde(delta)
	_uppdatera_sittande(delta)
	radio.vanta = kontakt.visible
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
	rader.append(radio.status())
	if not _horde.is_empty():
		var nere := 0
		for z in (_horde["zombies"] as Dictionary).values():
			if str(z["lage"]) != "gar":
				nere += 1
		rader.append("Horde: %d ute, %d nere, %d kvar att komma, närmast %s" % [
			(_horde["zombies"] as Dictionary).size(), nere, int(_horde["kvar"]), str(_horde.get("narmast", ""))])
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
		Spel.spela_samband(vaxlingar[_rng.randi_range(0, vaxlingar.size() - 1)], {}, true)


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
			_valj_variant(h)
			var fordon: Dictionary = h.get("fordon", {})
			if not fordon.is_empty():
				var fc := varld.punkt(fordon.get("plats", [0, 0]))
				var fs := varld.placera_fordon(str(fordon.get("sprite", "bil")), fc)
				_fordon[id] = {"sprite": fs, "cell": fc}
				if str(fordon.get("ljud", "")) != "":
					hud.visa_ljud(fs, str(fordon["ljud"]), 1.8, 30.0)
			n.visible = true
			n.framme.connect(_pa_npc_framme.bind(h, id), CONNECT_ONE_SHOT)
			varld.flytta_npc(id, varld.punkt(h.get("mal", [0, 0])))
		"dronare":
			_starta_dronare(h)
		"angripare":
			_starta_angripare(h)
		"horde":
			_starta_horde(h)


## Väljer variant för händelser som har "varianter" (om ingen redan valts).
func _valj_variant(h: Dictionary) -> void:
	var varianter: Array = h.get("varianter", [])
	if varianter.is_empty() or Spel.variant != "":
		return
	var v := str(h.get("vald_variant", ""))
	if v == "":
		_rng.randomize()
		v = str(varianter[_rng.randi_range(0, varianter.size() - 1)])
	Spel.satt_variant(v)


func _pa_npc_framme(h: Dictionary, id: String) -> void:
	var n: Aktor = varld.npcer.get(id)
	if n == null or _samtal_klara.has(id):
		return
	match str(h.get("vid_framme", "")):
		"fotograferar":
			n.vand_mot(varld.cell_pos(varld.punkt("objekt_mitt")))
			n.satt_fotograferar(true)
			if not n.blixt.is_connected(_pa_blixt):
				n.blixt.connect(_pa_blixt.bind(id))
		"vantar":
			n.vand_mot(varld.cell_pos(varld.punkt("grind")))
			var replik := str(h.get("vid_framme_replik", ""))
			if replik != "":
				hud.visa_bubbla(n, replik, 4.0)
		_:
			return
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
	radio.krok("npc_lamnar")
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
	Spel.satt_fakta({"dronare_borta": true})
	radio.krok("dronare_flyger_bort")
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
	Spel.satt_fakta({"dronare_landad": true})
	radio.krok("dronare_landar")


func _pa_situation(id: String) -> void:
	match id:
		"dronare":
			_bekampa_dronare()
		"halt":
			_halt_order()
		"varningsskott":
			_varningsskott()
		"verkanseld":
			_verkanseld()
		"sjukvard":
			_larma_sjukvard()
		"forsta_hjalpen":
			_forsta_hjalpen()


## Situationsknappen: bekämpa drönaren med vapen (ett beslut som bedöms).
func _bekampa_dronare() -> void:
	if dronare == null or not dronare.i_luften():
		return
	hud.satt_situation("", false)
	_markera_upptackt(_dronare_handelse)
	if not _upptackt.is_empty() and _upptackt["nod"] == dronare:
		_upptackt = {}
	Spel.utfor("vald_mot_farkost", "Bekämpade drönaren med automatkarbin")
	Spel.satt_fakta({"dronare_nedskjuten": true})
	hud.visa_ljud(varld.spelare, "PANG PANG", 1.5)
	dronare.krascha()
	varld.kollega.vand_mot(dronare.global_position)
	var efter := str(_dronare_handelse.get("kamrat_efter_skott", "…Det där kommer CQ inte gilla."))
	get_tree().create_timer(1.8).timeout.connect(_kamrat_sager.bind(efter))
	for id: String in _dronare_handelse.get("visa_npc_med_pilot", []):
		var n: Aktor = varld.npcer.get(id)
		var replik := str(_scenario.get("npc", {}).get(id, {}).get("efter_skott", ""))
		if n and n.visible and replik != "":
			hud.visa_bubbla(n, replik, 5.0)


# ---------------------------------------------------------- Angripare --
# Scenario Yxmannen: en man med yxa kommer ut ur skogen och går rakt mot
# stridsparet. Situationsknapparna (halt-order, varningsskott, verkanseld)
# visas så snart kamraten upptäcker honom. Bedömningen beror på avstånd,
# varning och om angreppet pågår (fakta uppdateras löpande).

func _starta_angripare(h: Dictionary) -> void:
	var id := str(h.get("npc", ""))
	var n: Aktor = varld.npcer.get(id)
	if n == null:
		return
	_valj_variant(h)
	n.visible = true
	n.hastighet = float(h.get("fart", 30))
	n.vila_aktiv = false
	_angripare = {"h": h, "id": id, "lage": "anfaller", "omvag_t": 0.0, "replik_t": 0.5, "replik_i": 0,
		"upptackt": false, "kamrat_nara": false}
	_larm_npc = id
	Spel.satt_fakta({"hot_svarare_vald": true, "angrepp_pagar": true, "brott_pa_bar_garning": true})


func _angripare_nod() -> Aktor:
	if _angripare.is_empty():
		return null
	return varld.npcer.get(str(_angripare["id"]))


func _avstand_angripare() -> int:
	var n := _angripare_nod()
	if n == null:
		return 999
	return varld.avstand(varld.spelare.cell, n.cell)


func _uppdatera_angripare(delta: float) -> void:
	if _angripare.is_empty() or str(_angripare["lage"]) != "anfaller":
		return
	var n := _angripare_nod()
	var h: Dictionary = _angripare["h"]
	var avst := _avstand_angripare()
	Spel.satt_fakta({"angrepp_overhangande": avst <= int(h.get("overhangande_avstand", 6))})
	# Vrålen hörs långt: kamraten reagerar direkt när han är inom hörhåll.
	if not bool(_angripare["upptackt"]) and avst <= int(h.get("upptacks_avstand", 18)):
		_angripare_upptackt()
	# Repliker med jämna mellanrum
	_angripare["replik_t"] = float(_angripare["replik_t"]) - delta
	if float(_angripare["replik_t"]) <= 0.0:
		_angripare["replik_t"] = float(h.get("replik_intervall_s", 3.5))
		var rep: Array = h.get("repliker", [])
		if not rep.is_empty() and hud.visible:
			hud.visa_bubbla(n, str(rep[int(_angripare["replik_i"]) % rep.size()]), 2.6)
			_angripare["replik_i"] = int(_angripare["replik_i"]) + 1
	if bool(_angripare["upptackt"]) and not bool(_angripare["kamrat_nara"]) and avst <= 4:
		_angripare["kamrat_nara"] = true
		_kamrat_sager(str(h.get("kamrat_nara", "")))
	# Framme: angreppet når stridsparet.
	if avst <= 1:
		_angrepp_nadde_fram()
		return
	# Ny väg mot spelaren med jämna mellanrum (spelaren rör sig).
	_angripare["omvag_t"] = float(_angripare["omvag_t"]) - delta
	if float(_angripare["omvag_t"]) <= 0.0:
		_angripare["omvag_t"] = float(h.get("omvag_s", 0.8))
		n.ga_langs(varld.vag_mot(n.cell, varld.spelare.cell))


func _angripare_upptackt() -> void:
	var h: Dictionary = _angripare["h"]
	var n := _angripare_nod()
	_angripare["upptackt"] = true
	_markera_upptackt(h)
	_larm_har_skett = true
	snack.pausa(600.0)
	varld.satt_larm(str(_angripare["id"]))
	radio.krok("upptackt")
	_kamrat_sager(str(h.get("kamrat", "")))
	varld.kollega.stanna()
	varld.kollega.vand_mot(n.global_position)
	_visa_angripar_knappar()


## Situationsknapparna följer läget: under angreppet halt/varningsskott/verkanseld,
## efter verkanseld sjukvård och första hjälpen.
func _visa_angripar_knappar() -> void:
	if _angripare.is_empty():
		return
	var val: Array = []
	match str(_angripare["lage"]):
		"anfaller", "gett_upp":
			if not bool(Spel.fakta.get("varning_given", false)):
				val.append({"id": "halt", "text": "Halt-order", "tangent": "H", "farg": "barnsten"})
			if not bool(Spel.fakta.get("varningsskott_avlossat", false)):
				val.append({"id": "varningsskott", "text": "Varningsskott", "tangent": "V", "farg": "barnsten"})
			val.append({"id": "verkanseld", "text": "Verkanseld", "tangent": "F", "farg": "rosa"})
		"skjuten":
			if not bool(Spel.fakta.get("sjukvard_larmad", false)):
				val.append({"id": "sjukvard", "text": "Larma sjukvård", "tangent": "S", "farg": "gron"})
			if not bool(Spel.fakta.get("forsta_hjalp_given", false)):
				val.append({"id": "forsta_hjalpen", "text": "Första hjälpen", "tangent": "J", "farg": "gron"})
	hud.satt_situationer(val)


func _variantreplik(h: Dictionary, nyckel: String) -> String:
	var v: Variant = h.get(nyckel, "")
	if v is Dictionary:
		return str((v as Dictionary).get(Spel.variant, ""))
	return str(v)


func _halt_order() -> void:
	if not _horde.is_empty():
		_horde_halt()
		return
	if _angripare.is_empty():
		return
	var h: Dictionary = _angripare["h"]
	Spel.utfor("halt_order", "Ropade: ”Halt! Militär skyddsvakt! Halt eller jag skjuter skarpt!”")
	hud.visa_bubbla(varld.spelare, "HALT! MILITÄR SKYDDSVAKT! HALT ELLER JAG SKJUTER SKARPT!", 3.5)
	if str(_angripare["lage"]) == "anfaller":
		var svar := _variantreplik(h, "svar_halt")
		if svar != "":
			get_tree().create_timer(1.2).timeout.connect(_angripare_sager.bind(svar))
		var kamrat := _variantreplik(h, "kamrat_efter_halt")
		if kamrat != "":
			get_tree().create_timer(2.4).timeout.connect(_kamrat_sager.bind(kamrat))
		if Spel.variant == "ger_upp" and _avstand_angripare() <= int(h.get("ger_upp_inom", 14)):
			get_tree().create_timer(1.6).timeout.connect(_angripare_ger_upp)
	_visa_angripar_knappar()


func _angripare_sager(text: String) -> void:
	var n := _angripare_nod()
	if n and hud.visible and str(_angripare.get("lage", "")) == "anfaller":
		hud.visa_bubbla(n, text, 2.5)
		_angripare["replik_t"] = 3.0


func _skott(antal: int) -> void:
	hud.visa_ljud(varld.spelare, "PANG" if antal == 1 else "PANG PANG", 1.4)
	var flamma := varld.lagg_foremal("mynningsflamma", varld.spelare.cell)
	flamma.position += Vector2(-8 if varld.spelare.position.x > varld.kollega.position.x else 8, -14)
	get_tree().create_timer(0.12).timeout.connect(flamma.queue_free)


func _varningsskott() -> void:
	if not _horde.is_empty():
		_horde_varningsskott()
		return
	if _angripare.is_empty():
		return
	var h: Dictionary = _angripare["h"]
	Spel.utfor("varningsskott", "Avlossade varningsskott (riktat så att ingen kan skadas)")
	_skott(1)
	if str(_angripare["lage"]) == "anfaller":
		if Spel.variant == "ger_upp":
			get_tree().create_timer(1.0).timeout.connect(_angripare_ger_upp)
		else:
			var svar := _variantreplik(h, "svar_varningsskott")
			if svar != "":
				get_tree().create_timer(1.0).timeout.connect(_angripare_sager.bind(svar))
			# Han ryggar en kort stund.
			var n := _angripare_nod()
			n.stanna()
			_angripare["omvag_t"] = 0.8
	_visa_angripar_knappar()


func _verkanseld() -> void:
	if not _horde.is_empty():
		_horde_verkanseld()
		return
	if _angripare.is_empty() or str(_angripare["lage"]) in ["skjuten"]:
		return
	var h: Dictionary = _angripare["h"]
	var n := _angripare_nod()
	# Fanns det tid för varningsskott? Inte om han redan är inpå.
	if _avstand_angripare() <= int(h.get("ingen_tid_avstand", 2)):
		Spel.satt_fakta({"varningsskott_foregick": true})
	if str(_angripare["lage"]) == "anfaller":
		Spel.satt_fakta({"angrepp_overhangande": _avstand_angripare() <= int(h.get("overhangande_avstand", 6))})
	Spel.utfor("verkanseld", "Avgav verkanseld mot mannen (patronvis, mot benen)")
	_skott(2)
	_angripare["lage"] = "skjuten"
	n.stanna()
	n.vaxla_still = true
	varld.byt_bilder(n, "yxman_ligger")
	_tappa_yxa(n)
	_angrepp_upphort({"motpart_skjuten": true})
	get_tree().create_timer(1.4).timeout.connect(_kamrat_sager.bind(str(h.get("kamrat_efter_verkanseld", ""))))
	radio.krok("motpart_skjuten")
	_visa_angripar_knappar()


func _angripare_ger_upp() -> void:
	if _angripare.is_empty() or str(_angripare["lage"]) != "anfaller":
		return
	var h: Dictionary = _angripare["h"]
	var n := _angripare_nod()
	_angripare["lage"] = "gett_upp"
	n.stanna()
	n.vaxla_still = true
	varld.byt_bilder(n, "yxman_upp")
	n.vand_mot(varld.spelare.position)
	_tappa_yxa(n)
	hud.visa_bubbla(n, "OKEJ OKEJ! SKJUT INTE!", 3.0)
	_angrepp_upphort({"motpart_gett_upp": true})
	get_tree().create_timer(1.6).timeout.connect(_kamrat_sager.bind(str(h.get("kamrat_ger_upp", ""))))
	radio.krok("motpart_ger_upp")
	_visa_angripar_knappar()


func _angrepp_nadde_fram() -> void:
	var h: Dictionary = _angripare["h"]
	var n := _angripare_nod()
	_angripare["lage"] = "overmannad"
	n.stanna()
	n.vaxla_still = true
	Spel.utfor("angrepp_nadde_fram", "Angreppet nådde fram – brottade ner honom med kamratens hjälp")
	hud.visa_ljud(n, "BRAK!", 1.5)
	_kamrat_sager(str(h.get("kamrat_nadde_fram", "")))
	varld.byt_bilder(n, "yxman_ligger")
	_tappa_yxa(n)
	varld.kollega.stanna()
	_angrepp_upphort({"motpart_overmannad": true})
	radio.krok("angrepp_nadde_fram")
	_visa_angripar_knappar()


func _tappa_yxa(n: Aktor) -> void:
	hud.visa_ljud(n, "KLONK", 1.2, 4.0)
	var c := n.cell + Vector2i(1, 0)
	varld.lagg_foremal("yxa", c if varld.ar_fri(c) else n.cell)


func _angrepp_upphort(extra: Dictionary) -> void:
	var f := {"angrepp_pagar": false, "angrepp_overhangande": false, "angrepp_pagar_ej": true}
	f.merge(extra, true)
	Spel.satt_fakta(f)
	varld.satt_larm("")
	_avsluta_handelse(_angripare["h"])


func _larma_sjukvard() -> void:
	Spel.utfor("larma_sjukvard", "Larmade sjukvård via CQ")
	Spel.spela_samband([
		{"fran": "Grindposten", "text": "CQ, CQ.", "efter": 0},
		{"fran": "CQ", "text": "CQ kom.", "efter": 1.5},
		{"fran": "Grindposten", "text": "Från Grindposten, en skadad person vid grinden, skottskada i benet, begär ambulans, kom.", "efter": 3.0},
		{"fran": "CQ", "text": "Uppfattat, ambulans larmas, kom.", "efter": 5.0},
		{"fran": "Grindposten", "text": "Uppfattat, slut kom.", "efter": 6.5},
		{"fran": "CQ", "text": "Klart slut.", "efter": 8.0},
	])
	_visa_angripar_knappar()


func _forsta_hjalpen() -> void:
	var n := _angripare_nod()
	Spel.utfor("forsta_hjalpen", "Gav första hjälpen (tryckförband)")
	if n:
		varld.ga_till(n.cell)
		hud.visa_bubbla(varld.spelare, "Tryckförband på! Ligg still.", 3.0)
	_visa_angripar_knappar()


## Rapport till CQ efter skott räknas som rapport om skjutvapenanvändningen.
func _pa_logg_post(post: Dictionary) -> void:
	if str(post.get("handling", "")) == "rapportera_vaktchef" and (
			bool(Spel.fakta.get("varningsskott_avlossat", false)) or bool(Spel.fakta.get("verkanseld_avlossad", false))):
		Spel.satt_fakta({"skjutning_rapporterad": true})


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


func _spelaren_sager(text: String) -> void:
	if hud.visible:
		hud.visa_bubbla(varld.spelare, text, 3.0)


func _kamrat_reagerar() -> void:
	var id := str(_upptackt["npc"])
	var h: Dictionary = _upptackt["h"]
	var nod: Node2D = _upptackt["nod"]
	_upptackt = {}
	_markera_upptackt(h)
	_larm_har_skett = true
	radio.krok("upptackt")
	snack.pausa(float(h.get("upptackt", {}).get("paus_snack_s", 60)))
	if id != "":
		varld.satt_larm(id)
	Spel.spela_samband(h.get("samband", []))
	# "kamrat_per_objekttyp" kan ersätta kamratens replik och ge vårt svar,
	# t.ex. när kamraten kallar helikoptern för lastbil.
	var per_typ: Dictionary = h.get("kamrat_per_objekttyp", {}).get(Spel.objekttyp, {})
	var kamrat := str(per_typ.get("kamrat", h.get("kamrat", "")))
	if kamrat != "":
		hud.visa_bubbla(varld.kollega, kamrat, 5.0)
	if str(per_typ.get("svar", "")) != "":
		get_tree().create_timer(2.2).timeout.connect(_spelaren_sager.bind(str(per_typ["svar"])))
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
	# Personens fordon åker också (t.ex. servicebilen).
	if _fordon.has(id):
		var f: Dictionary = _fordon[id]
		hud.visa_ljud(f["sprite"], "brumm", 1.5, 30.0)
		varld.ta_bort_fordon(f["sprite"], f["cell"])
		_fordon.erase(id)


# ----------------------------------------------------------- Kontakt --

func _pa_npc_klickad(id: String) -> void:
	if not _horde.is_empty() and (_horde["zombies"] as Dictionary).has(id):
		_kamrat_sager("Jag tror inte han vill prata.")
		return
	if _sittande.has(id):
		_sittande[id]["t"] = 0.0
		return
	if not _angripare.is_empty() and str(_angripare["id"]) == id and str(_angripare["lage"]) == "anfaller":
		hud.visa_meddelande("Han anfaller! Halt-order [H], varningsskott [V] eller verkanseld [F].")
		return
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
	radio.krok("upptackt")
	radio.krok("kontakt_start")
	varld.kollega.stanna()
	varld.kollega.vand_mot(n.position)
	varld.interaktion_aktiv = false
	hud.visible = false
	snack.aktiv = false
	var data: Dictionary = _scenario.get("npc", {}).get(id, {})
	kontakt.set_meta("npc", id)
	kontakt.oppna(data, _dialogstart(data))


## Startnod för dialogen. "dialog_start_om": [{fakta, nod}] väljer en annan
## start om ett faktum är sant (t.ex. att drönaren har skjutits ner).
func _dialogstart(data: Dictionary) -> String:
	for villkor in data.get("dialog_start_om", []):
		if bool(Spel.fakta.get(str(villkor.get("fakta", "")), false)):
			return str(villkor.get("nod", "start"))
	return str(data.get("dialog_start", "start"))


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
	radio.krok("kontakt_slut")
	hud.visible = true
	varld.satt_larm("")
	varld.interaktion_aktiv = true
	snack.aktiv = true
	snack.pausa(30.0)
	hud.visa_meddelande("Kom ihåg: rapportera och dokumentera händelsen.", 4.0)
	if _npc_efter_samtal.get(id, "") != "ga_till_start" and _frihetsberovad():
		_satt_vid_grinden(id)
	if _npc_efter_samtal.get(id, "") == "ga_till_start":
		var n: Aktor = varld.npcer[id]
		# Angriparen går därifrån utan yxa.
		if not _angripare.is_empty() and str(_angripare["id"]) == id:
			n.vaxla_still = false
			varld.byt_bilder(n, "yxman_utan")
		var data: Dictionary = _scenario.get("npc", {}).get(id, {})
		n.framme.connect(_dolj_npc.bind(id), CONNECT_ONE_SHOT)
		varld.flytta_npc(id, varld.punkt(data.get("start", [0, 0])))


# -------------------------------------------------------------- Horde --
# Scenario Zombieapokalypsen: ett dussin zombies kommer från olika håll.
# Samma regler som för yxmannen (halt-order, varningsskott, verkanseld), men
# varning och varningsskott biter inte. Kamraten och vi har svårt att tro det.

func _starta_horde(h: Dictionary) -> void:
	_horde = {"h": h, "zombies": {}, "kvar": int(h.get("antal", 12)), "spawn_t": 0.0, "nr": 0,
		"upptackt": false, "replik_t": 2.0, "banter_i": 0, "banter_t": 0.0, "kommenterat": {}}
	Spel.satt_fakta({"hot_svarare_vald": true, "angrepp_pagar": true})


## En startruta i riktning vinkel från spelaren, en bit utanför synfältet.
func _horde_startruta(vinkel: float, avst: int) -> Vector2i:
	var p := varld.spelare.cell
	for extra in range(0, 10):
		for d: float in [0.0, 0.25, -0.25, 0.5, -0.5]:
			var v := vinkel + d
			var c := p + Vector2i(roundi(cos(v) * (avst + extra)), roundi(sin(v) * (avst + extra)))
			c = c.clamp(Vector2i.ZERO, varld.storlek - Vector2i.ONE)
			# Rutan måste ha en väg fram till oss (inte instängd bakom vatten eller staket).
			if varld.ar_fri(c) and varld.avstand(c, p) >= avst - 2 and not varld.vag(c, p).is_empty():
				return c
	return Vector2i.ZERO


func _uppdatera_horde(delta: float) -> void:
	if _horde.is_empty():
		return
	var h: Dictionary = _horde["h"]
	var zombies: Dictionary = _horde["zombies"]
	# Nya zombies i vågor, från olika håll
	_horde["spawn_t"] = float(_horde["spawn_t"]) - delta
	if int(_horde["kvar"]) > 0 and float(_horde["spawn_t"]) <= 0.0:
		_horde["spawn_t"] = float(h.get("spawn_intervall_s", 4.0))
		for i in mini(int(h.get("per_vag", 2)), int(_horde["kvar"])):
			var nr := int(_horde["nr"])
			var vinkel := float(nr) * 2.4 + randf_range(-0.3, 0.3)  # gyllene vinkel: sprids runt om
			var c := _horde_startruta(vinkel, int(h.get("start_avstand", 18)))
			var id := "zombie_%d" % nr
			var n := varld.skapa_npc(id, {"sprite": str(h.get("sprite", "zombie")), "start": [c.x, c.y], "synlig_fran_start": true})
			n.hastighet = float(h.get("fart", 20)) * randf_range(0.85, 1.15)
			n.vila_aktiv = false
			zombies[id] = {"lage": "gar", "omvag_t": randf_range(0.0, 1.0)}
			_horde["nr"] = nr + 1
			_horde["kvar"] = int(_horde["kvar"]) - 1
	# Rörelse, avstånd och framme
	var narmast := 999
	var narmast_id := ""
	var gar := 0
	for id: String in zombies:
		var z: Dictionary = zombies[id]
		if str(z["lage"]) == "slagen":
			gar += 1  # ligger bara tillfälligt
			continue
		if str(z["lage"]) != "gar":
			continue
		gar += 1
		var n: Aktor = varld.npcer[id]
		var avst := varld.avstand(varld.spelare.cell, n.cell)
		if avst < narmast:
			narmast = avst
			narmast_id = id
		if avst <= 1:
			_horde_nadde_fram(id)
			continue
		z["omvag_t"] = float(z["omvag_t"]) - delta
		if float(z["omvag_t"]) <= 0.0:
			z["omvag_t"] = float(h.get("omvag_s", 1.0))
			n.ga_langs(varld.vag_mot(n.cell, varld.spelare.cell))
	_horde["narmast"] = narmast_id
	Spel.satt_fakta({"angrepp_overhangande": narmast <= int(h.get("overhangande_avstand", 6))})
	if not bool(_horde["upptackt"]) and narmast <= int(h.get("upptacks_avstand", 15)):
		_horde_upptackt()
	# Stön från en slumpvis zombie i närheten
	_horde["replik_t"] = float(_horde["replik_t"]) - delta
	if float(_horde["replik_t"]) <= 0.0 and narmast_id != "" and hud.visible:
		_horde["replik_t"] = randf_range(2.5, 4.5)
		var rep: Array = h.get("repliker", [])
		var kandidater: Array = []
		for id: String in zombies:
			if str(zombies[id]["lage"]) == "gar" and varld.avstand(varld.spelare.cell, varld.npcer[id].cell) <= 12:
				kandidater.append(id)
		if not rep.is_empty() and not kandidater.is_empty():
			hud.visa_bubbla(varld.npcer[kandidater.pick_random()], str(rep.pick_random()), 2.2)
	# Replikväxling mellan oss och kamraten
	if bool(_horde["upptackt"]):
		var banter: Array = h.get("replikvaxling", [])
		_horde["banter_t"] = float(_horde["banter_t"]) + delta
		var bi := int(_horde["banter_i"])
		if bi < banter.size() and float(_horde["banter_t"]) >= float(banter[bi].get("t", 0)):
			_horde["banter_i"] = bi + 1
			var b: Dictionary = banter[bi]
			if str(b.get("vem", "")) == "du":
				_spelaren_sager(str(b.get("text", "")))
			else:
				_kamrat_sager(str(b.get("text", "")))
	# Alla nere
	if gar == 0 and int(_horde["kvar"]) == 0 and not bool(Spel.fakta.get("horde_nere", false)):
		Spel.satt_fakta({"horde_nere": true, "angrepp_pagar": false, "angrepp_overhangande": false, "angrepp_pagar_ej": true})
		hud.satt_situationer([])
		varld.satt_larm("")
		_avsluta_handelse(h)
		get_tree().create_timer(1.5).timeout.connect(_kamrat_sager.bind(str(h.get("kamrat_slut", ""))))


func _horde_upptackt() -> void:
	var h: Dictionary = _horde["h"]
	_horde["upptackt"] = true
	_markera_upptackt(h)
	_larm_har_skett = true
	snack.pausa(900.0)
	radio.krok("upptackt")
	varld.kollega.stanna()
	_visa_horde_knappar()


func _visa_horde_knappar() -> void:
	var val: Array = []
	if not bool(Spel.fakta.get("varning_given", false)):
		val.append({"id": "halt", "text": "Halt-order", "tangent": "H", "farg": "barnsten"})
	if not bool(Spel.fakta.get("varningsskott_avlossat", false)):
		val.append({"id": "varningsskott", "text": "Varningsskott", "tangent": "V", "farg": "barnsten"})
	val.append({"id": "verkanseld", "text": "Verkanseld", "tangent": "F", "farg": "rosa"})
	hud.satt_situationer(val)


func _horde_kommentar(nyckel: String, fordrojning := 2.0) -> void:
	var kommenterat: Dictionary = _horde["kommenterat"]
	var text := str((_horde["h"] as Dictionary).get(nyckel, ""))
	if text == "" or kommenterat.has(nyckel):
		return
	kommenterat[nyckel] = true
	get_tree().create_timer(fordrojning).timeout.connect(_kamrat_sager.bind(text))


## Avståndet till närmaste zombie just nu (inte från förra bildrutan).
func _horde_narmast_fakta() -> void:
	var narmast := 999
	for id: String in _horde["zombies"]:
		if str(_horde["zombies"][id]["lage"]) == "gar":
			narmast = mini(narmast, varld.avstand(varld.spelare.cell, varld.npcer[id].cell))
	Spel.satt_fakta({"angrepp_overhangande": narmast <= int((_horde["h"] as Dictionary).get("overhangande_avstand", 6))})


func _horde_halt() -> void:
	Spel.utfor("halt_order", "Ropade: ”Halt! Militär skyddsvakt! Halt eller jag skjuter skarpt!”")
	hud.visa_bubbla(varld.spelare, "HALT! MILITÄR SKYDDSVAKT! HALT ELLER JAG SKJUTER SKARPT!", 3.5)
	_horde_kommentar("kamrat_efter_halt", 2.4)
	_visa_horde_knappar()


func _horde_varningsskott() -> void:
	_horde_narmast_fakta()
	Spel.utfor("varningsskott", "Avlossade varningsskott (riktat så att ingen kan skadas)")
	_skott(1)
	_horde_kommentar("kamrat_efter_varningsskott", 1.6)
	_visa_horde_knappar()


func _horde_verkanseld() -> void:
	var id := str(_horde.get("narmast", ""))
	if id == "" or not (_horde["zombies"] as Dictionary).has(id):
		return
	var h: Dictionary = _horde["h"]
	var n: Aktor = varld.npcer[id]
	var avst := varld.avstand(varld.spelare.cell, n.cell)
	if avst <= int(h.get("ingen_tid_avstand", 2)):
		Spel.satt_fakta({"varningsskott_foregick": true})
	Spel.satt_fakta({"angrepp_overhangande": avst <= int(h.get("overhangande_avstand", 6))})
	Spel.utfor("verkanseld", "Avgav verkanseld mot närmaste… person (patronvis, mot benen)")
	_skott(2)
	_horde_falla(id)
	var blod := varld.lagg_dekal("blod", n.cell)
	blod.modulate.a = 0.0
	create_tween().tween_property(blod, "modulate:a", 1.0, 1.2)
	_horde_kommentar("kamrat_efter_verkanseld", 1.4)
	_visa_horde_knappar()


func _horde_falla(id: String) -> void:
	var n: Aktor = varld.npcer[id]
	_horde["zombies"][id]["lage"] = "nere"
	n.stanna()
	n.vaxla_still = true
	varld.byt_bilder(n, "zombie_ligger")


func _horde_nadde_fram(id: String) -> void:
	var n: Aktor = varld.npcer[id]
	Spel.utfor("angrepp_nadde_fram", "En av dem nådde fram – knuffades omkull av kamraten")
	hud.visa_ljud(n, "DUNS!", 1.4)
	# Knuffas bakåt ett par rutor, ligger några sekunder och reser sig igen.
	var bort := Vector2(n.cell - varld.spelare.cell)
	bort = bort.normalized() if bort.length() > 0.0 else Vector2(1, 0)
	for steg: int in [3, 2]:
		var c := n.cell + Vector2i(roundi(bort.x * steg), roundi(bort.y * steg))
		if varld.ar_fri(c):
			n.cell = c
			create_tween().tween_property(n, "position", varld.cell_pos(c), 0.25)
			break
	_horde_falla(id)
	_horde["zombies"][id]["lage"] = "slagen"
	var h: Dictionary = _horde["h"]
	var tid: Array = h.get("reser_sig_efter_s", [3.0, 6.0])
	get_tree().create_timer(randf_range(float(tid[0]), float(tid[1]))).timeout.connect(_horde_reser_sig.bind(id))
	_horde_kommentar("kamrat_nadde_fram", 0.3)


func _horde_reser_sig(id: String) -> void:
	if _horde.is_empty() or str(_horde["zombies"].get(id, {}).get("lage", "")) != "slagen":
		return
	var n: Aktor = varld.npcer[id]
	n.vaxla_still = false
	varld.byt_bilder(n, str((_horde["h"] as Dictionary).get("sprite", "zombie")))
	_horde["zombies"][id]["lage"] = "gar"
	_horde["zombies"][id]["omvag_t"] = 0.5
	hud.visa_bubbla(n, "Uuurrgh…", 2.0)
	_horde_kommentar("kamrat_reser_sig", 0.8)


# ------------------------------------------------- Frihetsberövad --
# Den som omhändertagits eller gripits förs till grinden, sätter sig och
# muttrar surt (personens "frihetsberovad" i scenariofilen).

func _frihetsberovad() -> bool:
	for f in ["omhandertagande_genomfort", "gripande_genomfort", "envarsgripande_genomfort"]:
		if bool(Spel.fakta.get(f, false)):
			return true
	return false


func _satt_vid_grinden(id: String) -> void:
	var cfg: Dictionary = _scenario.get("npc", {}).get(id, {}).get("frihetsberovad", {})
	if cfg.is_empty() or _sittande.has(id):
		return
	var n: Aktor = varld.npcer[id]
	_sittande[id] = {"t": 4.0, "i": 0, "repliker": cfg.get("repliker", []), "sitter": false,
		"intervall": cfg.get("intervall_s", [7.0, 12.0]), "sprite": str(cfg.get("sprite", ""))}
	var repl: Array = _sittande[id]["repliker"]
	repl.shuffle()
	n.framme.connect(_satter_sig.bind(id), CONNECT_ONE_SHOT)
	varld.flytta_npc(id, varld.punkt(cfg.get("plats", "grind_ute")))


func _satter_sig(id: String) -> void:
	var n: Aktor = varld.npcer[id]
	var s: Dictionary = _sittande[id]
	if str(s["sprite"]) != "":
		varld.byt_bilder(n, str(s["sprite"]))
	n.vila_aktiv = false
	n.vand_mot(varld.spelare.global_position)
	s["sitter"] = true


func _uppdatera_sittande(delta: float) -> void:
	for id: String in _sittande:
		var s: Dictionary = _sittande[id]
		if not bool(s["sitter"]):
			continue
		s["t"] = float(s["t"]) - delta
		if float(s["t"]) > 0.0:
			continue
		var iv: Array = s["intervall"]
		s["t"] = randf_range(float(iv[0]), float(iv[1]))
		var rep: Array = s["repliker"]
		if rep.is_empty() or not hud.visible:
			continue
		hud.visa_bubbla(varld.npcer[id], str(rep[int(s["i"]) % rep.size()]), 3.0)
		s["i"] = int(s["i"]) + 1
		varld.npcer[id].vaxla_still = false
		varld.npcer[id]._sprite.texture = varld.npcer[id]._bilder[int(s["i"]) % 2]


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
