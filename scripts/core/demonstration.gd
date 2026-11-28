class_name Demonstration
extends Node
## Scenario Demokratiska rättigheter: ett dussin demonstranter med plakat och
## slagord kommer längs vägen och vill in på skyddsobjektet för att sätta sig
## och sjunga. De är fredliga men högljudda och trycker på vid grinden.
##
## Mekanik:
##  - Demonstranterna går inte igenom en ruta där ettan eller tvåan står. Står
##    stridsparet i grindens två rutor kommer ingen in – men de som trycker på
##    kan slinka förbi ibland (oftare ju mer upprörda de är).
##  - Den som kommit in sätter sig och sjunger. Avlägsna (12 §) = bära ut honom,
##    och under tiden står grinden halvöppen.
##  - Halt-order, handgemäng, varningsskott och verkanseld trappar upp stämningen.
##  - Talespersonen går att prata med; går gruppen med på att sitta utanför
##    grinden lugnar det sig (utom för de mest envisa).
##  - Begärd polis kommer efter en stund och gruppen går. Annars tröttnar de.

var main  # Main (otypad: vi använder dess hjälpfunktioner)
var h: Dictionary

## Faser: kommer, samlas, trycker, slut
var fas := "kommer"
var upptackt := false
var stress := 0
var antal_halt := 0
var antal_handgemang := 0
var antal_varningsskott := 0
var antal_verkanseld := 0

## En post per demonstrant: {id, n, lage, variant, mal, t, envis, ledare}
## lagen: vantar, kommer, samlas, trycker, tillbaka, sitter_inne, bars_ut,
##        sitter_ute, gar_hem, borta, skadad, skjuten, fryst
var demonstranter: Array[Dictionary] = []

var _t := 0.0
var _fas_t := 0.0
var _upptack_t := 0.0
var _slagord_t := 2.0
var _tryck_t := 2.0
var _knuff_t := 1.0
var _kamrat_slank_t := 0.0
var _polis_t := -1.0
var _polis_framme := false
var _polisbil: Sprite2D = null
var _avslutad := false
var _bar_ut: Dictionary = {}
var _ledig_inne: Array[Vector2i] = []
var _ledig_ute: Array[Vector2i] = []
var _skyddsvakt_skadad := false
## Speltid (s) för upptäckten, första bråket och stridsparets rapport/förstärkning.
var upptackt_s := -1.0
var brak_s := -1.0
var rapport_s := -1.0
var forstarkning_s := -1.0
var _rond: Array[Aktor] = []
var _rond_t := -1.0
var _fh_given: Dictionary = {}


func setup(p_main, p_h: Dictionary) -> void:
	main = p_main
	h = p_h
	_bygg_platser()
	var varianter := ["a", "b", "c", "d"]
	var antal := int(h.get("antal", 12))
	var start: Vector2i = main.varld.punkt(h.get("start", [51, 24]))
	var envisa := int(h.get("envisa", 2))
	var ledare := str(h.get("ledare", "talespersonen"))
	for i in antal:
		var id := ledare if i == 0 else "demo_%d" % i
		var n: Aktor = main.varld.npcer.get(id)
		var variant := "b" if i == 0 else str(varianter[i % varianter.size()])
		if n == null:
			n = main.varld.skapa_npc(id, {"sprite": "demonstrant_" + variant, "start": [start.x, start.y]})
		n.cell = start
		n.stanna()
		n.visible = false
		n.vila_aktiv = false
		n.hastighet = randf_range(26.0, 32.0)
		demonstranter.append({"id": id, "n": n, "lage": "vantar", "variant": variant,
			"mal": Vector2i(-1, -1), "t": 0.6 * i, "envis": i > 0 and i <= envisa, "ledare": i == 0,
			"reserv": Vector2i(-1, -1)})
	Spel.satt_fakta({"vill_ha_tilltrade": true, "behov_avvisa": true})


## Platser att sitta på: innanför staketet nära grinden och ute på vägen.
func _bygg_platser() -> void:
	var v: Varld = main.varld
	var inne: Array = h.get("sitt_inne", [22, 23, 29, 26])
	var ute: Array = h.get("sitt_ute", [32, 22, 37, 27])
	for y in range(int(inne[1]), int(inne[3]) + 1):
		for x in range(int(inne[0]), int(inne[2]) + 1):
			var c := Vector2i(x, y)
			if v.ar_fri(c) and v.ar_inom_skyddsomrade(c) and not c in v.grindceller():
				_ledig_inne.append(c)
	for y in range(int(ute[1]), int(ute[3]) + 1):
		for x in range(int(ute[0]), int(ute[2]) + 1):
			var c := Vector2i(x, y)
			if v.ar_fri(c) and not v.ar_inom_skyddsomrade(c):
				_ledig_ute.append(c)
	_ledig_inne.shuffle()
	# Närmast grinden först, så att de sätter sig i en klunga utanför.
	var grind: Vector2i = v.punkt(h.get("samling", "grind_ute"))
	_ledig_ute.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a - grind).length() < Vector2(b - grind).length())


func _process(delta: float) -> void:
	if not Spel.klocka_igang or _avslutad:
		return
	# Under samtalet med talespersonen lyssnar gruppen (ingen trycker på).
	if main.kontakt.visible:
		return
	_t += delta
	_kamrat_slank_t -= delta
	_uppdatera_upptackt(delta)
	_uppdatera_fas(delta)
	for d in demonstranter:
		_uppdatera_demonstrant(d, delta)
	_uppdatera_tryck(delta)
	_uppdatera_slagord(delta)
	_uppdatera_polis(delta)
	_uppdatera_samband(delta)
	_uppdatera_kamrat()
	_uppdatera_fakta()


# ------------------------------------------------------------ Faser --

func _uppdatera_fas(delta: float) -> void:
	_fas_t += delta
	match fas:
		"kommer":
			var framme := true
			for d in demonstranter:
				if d["lage"] in ["vantar", "kommer"]:
					framme = false
			if framme or _fas_t > float(h.get("max_kommer_s", 40)):
				fas = "samlas"
				_fas_t = 0.0
				_sag(_ledaren(), str(h.get("ledare_samlas", "")), 3.0)
		"samlas":
			if _fas_t > float(h.get("samlas_s", 10)):
				fas = "trycker"
				_fas_t = 0.0
				_sag(_ledaren(), str(h.get("ledare_in", "")), 3.0)
				for d in demonstranter:
					if d["lage"] == "samlas" and not d["ledare"]:
						_borja_trycka(d)
				visa_knappar()
		"trycker":
			if _fas_t > float(h.get("trottnar_efter_s", 240)) and _polis_t < 0.0:
				_alla_gar_hem(str(h.get("ledare_trott", "")))


func _ledaren() -> Aktor:
	return demonstranter[0]["n"] if not demonstranter.is_empty() else null


func _sag(n: Aktor, text: String, sek := 2.5) -> void:
	if n == null or text == "" or not n.visible or not main.hud.visible:
		return
	main.hud.visa_bubbla(n, text, sek)


## Gruppen går med på att sitta utanför grinden (samtal med talespersonen).
func _lugnt() -> bool:
	return bool(Spel.fakta.get("demo_sitter_utanfor", false))


func _borja_trycka(d: Dictionary) -> void:
	if _lugnt() and not d["envis"] and not bool(d.get("otalig", false)):
		_satt_utanfor(d)
		return
	d["lage"] = "trycker"
	if d["mal"] == Vector2i(-1, -1) or not main.varld.ar_inom_skyddsomrade(d["mal"]):
		d["mal"] = _ledig_inne.pop_back() if not _ledig_inne.is_empty() else main.varld.punkt("objekt_mitt")


func _satt_utanfor(d: Dictionary) -> void:
	d["lage"] = "sitter_ute"
	d["sitter"] = false
	# De nöjer sig inte länge med att sitta utanför.
	d["ute_t"] = randf_range(float(h.get("sitter_ute_min_s", 20)), float(h.get("sitter_ute_max_s", 40)))
	d["mal"] = _ledig_ute.pop_front() if not _ledig_ute.is_empty() else main.varld.punkt("grind_ute")
	var n: Aktor = d["n"]
	n.stanna()
	n.ga_langs(main.varld.vag_mot(n.cell, d["mal"]))


# ------------------------------------------------------- Rörelse --

func _uppdatera_demonstrant(d: Dictionary, delta: float) -> void:
	var n: Aktor = d["n"]
	var lage := str(d["lage"])
	if d["ledare"] and main._sittande.has(str(d["id"])):
		return  # omhändertagen: huvudskriptet sköter honom
	match lage:
		"vantar":
			d["t"] = float(d["t"]) - delta
			if float(d["t"]) <= 0.0:
				d["lage"] = "kommer"
				n.visible = true
				d["mal"] = _ledig_ute.pop_front() if not _ledig_ute.is_empty() else main.varld.punkt("grind_ute")
				n.ga_langs(main.varld.vag_mot(n.cell, d["mal"]))
		"kommer":
			if not n.ar_i_rorelse():
				d["lage"] = "samlas"
				n.vand_mot(main.varld.cell_pos(main.varld.punkt("grind")))
				if fas == "trycker" and not d["ledare"]:
					_borja_trycka(d)
		"trycker":
			if _lugnt() and not d["envis"] and not bool(d.get("otalig", false)) and not main.varld.ar_inom_skyddsomrade(n.cell):
				_ledig_inne.append(d["mal"])
				_satt_utanfor(d)
				return
			if not n.ar_i_rorelse():
				d["t"] = float(d["t"]) - delta
				if float(d["t"]) <= 0.0:
					_nasta_steg(d)
		"tillbaka", "fryst":
			d["t"] = float(d["t"]) - delta
			if float(d["t"]) <= 0.0 and not n.ar_i_rorelse():
				if lage == "fryst":
					main.varld.byt_bilder(n, "demonstrant_" + str(d["variant"]))
					n.vaxla_still = false
				_borja_trycka(d)
		"sitter_ute", "sitter_inne":
			if lage == "sitter_ute" and fas == "trycker" and not d["ledare"] and bool(d.get("sitter", false)):
				d["ute_t"] = float(d.get("ute_t", 30.0)) - delta
				if float(d["ute_t"]) <= 0.0:
					_reser_sig(d)
					return
			if not n.ar_i_rorelse() and not bool(d.get("sitter", false)):
				d["sitter"] = true
				main.varld.byt_bilder(n, "demonstrant_%s_sitter" % d["variant"])
				n.vaxla_still = true
				n.vand_mot(main.varld.cell_pos(main.varld.punkt("objekt_mitt")))
				if lage == "sitter_inne":
					Spel.satt_fakta({"demo_sitter_inne": true})


## Tröttnar på att sitta utanför: reser sig och trycker på igen.
var _otalig_sagt := false


func _reser_sig(d: Dictionary) -> void:
	var n: Aktor = d["n"]
	d["otalig"] = true
	d["sitter"] = false
	_ledig_ute.append(d["mal"])
	n.vaxla_still = false
	main.varld.byt_bilder(n, "demonstrant_" + str(d["variant"]))
	d["mal"] = Vector2i(-1, -1)
	_borja_trycka(d)
	d["t"] = 0.0
	if not _otalig_sagt:
		_otalig_sagt = true
		_sag(_ledaren(), str(h.get("ledare_otalig", "")), 3.5)
	else:
		_sag(n, str((h.get("repliker_reser_sig", ["In igen!"]) as Array).pick_random()), 2.0)


## Ett steg i taget mot målet. Rutor där ettan eller tvåan står går inte att
## passera; finns ingen annan väg trycker demonstranten på mot vakten.
func _nasta_steg(d: Dictionary) -> void:
	var n: Aktor = d["n"]
	var mal: Vector2i = d["mal"]
	if n.cell == mal:
		_framme_inne(d)
		return
	var v: Varld = main.varld
	var vakter := _vakter()
	var vag := _vag_utan(n.cell, mal, vakter)
	d["tryck"] = false
	if vag.size() < 2:
		# Blockerad: gå fram till vakten och tryck på.
		var fri := _vag_utan(n.cell, mal, [])
		if fri.size() < 2 or fri[1] in vakter:
			d["tryck"] = fri.size() >= 2
			d["t"] = 0.4
			if fri.size() >= 2:
				n.vand_mot(v.cell_pos(fri[1]))
			return
		vag = fri
	var nasta: Vector2i = vag[1]
	if _upptagen(nasta, d):
		d["t"] = 0.35
		return
	d["reserv"] = nasta
	var steg: Array[Vector2i] = [n.cell, nasta]
	n.ga_langs(steg)
	d["t"] = 0.0


func _vag_utan(fran: Vector2i, till: Vector2i, hinder: Array[Vector2i]) -> Array[Vector2i]:
	var a: AStarGrid2D = main.varld.astar
	if not a.region.has_point(till) or a.is_point_solid(till):
		return []
	var andrade: Array[Vector2i] = []
	for c in hinder:
		if c != fran and c != till and a.region.has_point(c) and not a.is_point_solid(c):
			a.set_point_solid(c, true)
			andrade.append(c)
	var vag := a.get_id_path(fran, till)
	for c in andrade:
		a.set_point_solid(c, false)
	return vag


func _upptagen(c: Vector2i, jag: Dictionary) -> bool:
	for d in demonstranter:
		if d == jag or d["lage"] in ["borta", "vantar"]:
			continue
		var n: Aktor = d["n"]
		if n.cell == c or (n.ar_i_rorelse() and d["reserv"] == c):
			return true
	return false


func _framme_inne(d: Dictionary) -> void:
	d["lage"] = "sitter_inne"
	d["sitter"] = false
	Spel.satt_fakta({"motpart_inom": true, "overtratt_forbud": true, "behov_avlagsna": true, "demo_inne": true})
	_sag(d["n"], str((h.get("repliker_sitter", ["Vi sitter kvar!"]) as Array).pick_random()), 2.5)
	visa_knappar()


# ------------------------------------------------------- Trycket --

func _tryckande() -> Array[Dictionary]:
	var ut: Array[Dictionary] = []
	for d in demonstranter:
		if d["lage"] == "trycker" and bool(d.get("tryck", false)):
			ut.append(d)
	return ut


func _uppdatera_tryck(delta: float) -> void:
	var tryckande := _tryckande()
	if tryckande.is_empty():
		return
	_borjar_brakas()
	_knuff_t -= delta
	if _knuff_t <= 0.0:
		_knuff_t = randf_range(0.9, 1.6)
		var d: Dictionary = tryckande.pick_random()
		_knuff(d["n"])
		if main.hud.visible and randf() < 0.5:
			main.hud.visa_ljud(d["n"], str((h.get("ljud_tryck", ["*tryck*"]) as Array).pick_random()), 0.8, 30.0)
	_uppdatera_kamrat_knuff(delta, tryckande)
	_tryck_t -= delta
	if _tryck_t > 0.0:
		return
	_tryck_t = float(h.get("tryck_intervall_s", 2.0))
	var chans := float(h.get("chans_slinka", 0.05)) * (1.0 + 0.5 * stress) * clampf(tryckande.size() / 4.0, 0.5, 2.0)
	if _lugnt():
		chans *= 0.5
	for d in tryckande:
		if randf() < chans:
			_slinker_forbi(d)
			return


## Tvåan hindrar också – men tar aldrig till mer våld än ettan redan gjort:
## först när vi själva tagit handgemäng knuffar han tillbaka den som trycker
## mot honom. Han skjuter aldrig här.
var _kamrat_knuff_t := 3.0


func _uppdatera_kamrat_knuff(delta: float, tryckande: Array[Dictionary]) -> void:
	if antal_handgemang == 0:
		return
	_kamrat_knuff_t -= delta
	if _kamrat_knuff_t > 0.0:
		return
	_kamrat_knuff_t = randf_range(3.5, 6.0)
	var v: Varld = main.varld
	for d in tryckande:
		var n: Aktor = d["n"]
		if v.avstand(n.cell, v.kollega.cell) <= 1 and randf() < float(h.get("chans_kamrat_knuffar", 0.4)):
			v.kollega.vand_mot(n.global_position)
			var fram: Vector2 = (n.global_position - v.kollega.global_position).normalized() * 4.0
			var tw := v.kollega.create_tween()
			tw.tween_property(v.kollega, "position", v.kollega.position + fram, 0.08)
			tw.tween_property(v.kollega, "position", v.kollega.position, 0.14)
			if main.hud.visible:
				main.hud.visa_bubbla(v.kollega, str((h.get("kamrat_knuffar", ["Backa!"]) as Array).pick_random()), 1.8)
			_knuffad_tillbaka(d)
			return


func _knuff(n: Aktor) -> void:
	var v: Varld = main.varld
	var mal := v.spelare if v.avstand(n.cell, v.spelare.cell) <= v.avstand(n.cell, v.kollega.cell) else v.kollega
	var fram: Vector2 = (mal.global_position - n.global_position).normalized() * 3.0
	var tw := n.create_tween()
	tw.tween_property(n, "position", n.position + fram, 0.1)
	tw.tween_property(n, "position", n.position, 0.15)


## Han tränger sig förbi vakten han trycker mot och fortsätter in.
func _slinker_forbi(d: Dictionary) -> void:
	var v: Varld = main.varld
	var n: Aktor = d["n"]
	var vakt: Aktor = v.spelare if v.avstand(n.cell, v.spelare.cell) <= 1 else v.kollega
	if v.avstand(n.cell, vakt.cell) > 1:
		return
	var bortom := Vector2i(-1, -1)
	var basta := INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := vakt.cell + Vector2i(dx, dy)
			if c in _vakter() or not v.ar_fri(c):
				continue
			if not v.ar_inom_skyddsomrade(c) or _upptagen(c, d):
				continue
			var avst := Vector2(c - n.cell).length()
			if avst > 1.5 and avst < basta:
				basta = avst
				bortom = c
	if bortom.x < 0:
		return
	var steg: Array[Vector2i] = [n.cell, vakt.cell, bortom]
	n.ga_langs(steg)
	d["reserv"] = bortom
	d["tryck"] = false
	_sag(n, str((h.get("repliker_slinker", ["Släpp förbi!"]) as Array).pick_random()), 1.8)
	if _kamrat_slank_t <= 0.0:
		_kamrat_slank_t = 8.0
		main.get_tree().create_timer(0.8).timeout.connect(main._kamrat_sager.bind(str(h.get("kamrat_slinker", ""))))


## Tvåan ställer sig i den andra grindrutan när ettan står i grinden.
func _uppdatera_kamrat() -> void:
	if fas == "kommer" or _avslutad:
		return
	var v: Varld = main.varld
	var grind: Array[Vector2i] = v.grindceller()
	if grind.size() < 2 or not v.spelare.cell in grind or v.spelare.ar_i_rorelse() or v.kollega.ar_i_rorelse():
		return
	if v.kollega.cell in grind:
		return
	for c in grind:
		if c != v.spelare.cell:
			var vag := v.vag(v.kollega.cell, c)
			if vag.size() > 1 and vag.size() <= 4:
				v.kollega.ga_langs(vag)
			return


# ------------------------------------------------------- Slagord --

func _uppdatera_slagord(delta: float) -> void:
	if fas == "kommer" and not upptackt:
		return
	_slagord_t -= delta
	if _slagord_t > 0.0 or not main.hud.visible:
		return
	_slagord_t = randf_range(1.6, 2.6) / (1.0 + 0.25 * mini(stress, 4))
	var aktiva: Array[Dictionary] = []
	for d in demonstranter:
		if (d["n"] as Aktor).visible and d["lage"] in ["kommer", "samlas", "trycker", "sitter_inne", "sitter_ute", "tillbaka"]:
			aktiva.append(d)
	if aktiva.is_empty():
		return
	var d: Dictionary = aktiva.pick_random()
	var nyckel := "repliker_sitter" if str(d["lage"]).begins_with("sitter") else "slagord"
	if stress >= 2 and nyckel == "slagord" and randf() < 0.5:
		nyckel = "repliker_arga"
	main.hud.visa_bubbla(d["n"], str((h.get(nyckel, ["…"]) as Array).pick_random()), 2.0)


# ------------------------------------------------------- Upptäckt --

func _uppdatera_upptackt(delta: float) -> void:
	if upptackt:
		return
	for d in demonstranter:
		var n: Aktor = d["n"]
		if n.visible and main.varld.avstand(main.varld.spelare.cell, n.cell) <= int(h.get("upptacks_avstand", 20)):
			_upptack_t += delta
			if _upptack_t >= float(h.get("upptacks_fordrojning_s", 2.0)):
				upptack()
			return


func upptack() -> void:
	if upptackt:
		return
	upptackt = true
	upptackt_s = Spel.klocka_s
	Spel.satt_fakta({"demo_upptackt": true, "motpart_invid": true})
	main._markera_upptackt(h)
	main._larm_har_skett = true
	main.snack.pausa(900.0)
	main.radio.krok("upptackt")
	main._kamrat_sager(str(h.get("kamrat", "")))
	visa_knappar()


func ar_demonstrant(id: String) -> bool:
	for d in demonstranter:
		if str(d["id"]) == id:
			return true
	return false


func hanterar() -> bool:
	return upptackt


# ------------------------------------------------------- Samband --

## Rutor där en vakt står (stridsparet och en eventuell rondpatrull).
func _vakter() -> Array[Vector2i]:
	var ut: Array[Vector2i] = [main.varld.spelare.cell, main.varld.kollega.cell]
	for r in _rond:
		ut.append(r.cell)
	return ut


func _borjar_brakas() -> void:
	if brak_s < 0.0:
		brak_s = Spel.klocka_s


## Rapport till CQ och förstärkning: tider för bedömningen, och rondpatrullen
## kommer en stund efter att förstärkning begärts.
func _uppdatera_samband(delta: float) -> void:
	if rapport_s < 0.0 and Spel.handling_utford("rapportera_vaktchef"):
		rapport_s = Spel.klocka_s
	if forstarkning_s < 0.0 and Spel.handling_utford("begar_forstarkning"):
		forstarkning_s = Spel.klocka_s
		_rond_t = float(h.get("forstarkning_efter_s", 25))
	if _rond_t > 0.0:
		_rond_t -= delta
		if _rond_t <= 0.0:
			_rondpatrullen_kommer()


func _rondpatrullen_kommer() -> void:
	var v: Varld = main.varld
	var start: Vector2i = v.punkt(h.get("forstarkning_start", "stig_nord"))
	var platser: Array[Vector2i] = []
	for c in v.grindceller():
		platser.append(c + Vector2i(-1, 0))
	for i in 2:
		var n: Aktor = v.skapa_npc("rond_%d" % (i + 1), {"sprite": "vakt", "start": [start.x + i, start.y], "synlig_fran_start": true})
		n.hastighet = 60.0
		_rond.append(n)
		var mal: Vector2i = platser[i] if i < platser.size() else v.punkt("grind")
		n.ga_langs(v.vag(n.cell, mal))
		if i == 0:
			n.framme.connect(func() -> void:
				Spel.satt_fakta({"forstarkning_pa_plats": true})
				_sag(n, str(h.get("rond_framme", "Rondpatrullen på plats – vi tar grinden bakom er!")), 3.0), CONNECT_ONE_SHOT)


## Läggs till debriefingen: kom rapporten till CQ tidigt, och begärdes
## förstärkning senast när det började bråkas?
func bedom_efterat() -> void:
	if upptackt_s < 0.0:
		return
	var rapport_grans := upptackt_s + float(h.get("rapport_senast_s", 120))
	if brak_s >= 0.0:
		rapport_grans = minf(rapport_grans, brak_s + float(h.get("rapport_marginal_s", 30)))
	if rapport_s >= 0.0 and rapport_s > rapport_grans:
		Spel.lagg_till_missad(_post("sen_rapport", "warn", "Rapporten till CQ kom sent",
			str(h.get("text_sen_rapport", "")), str(h.get("diskutera_sen_rapport", ""))))
	if brak_s >= 0.0:
		var grans := brak_s + float(h.get("forstarkning_marginal_s", 60))
		if forstarkning_s < 0.0:
			Spel.lagg_till_missad(_post("ingen_forstarkning", "bad", "Förstärkning begärdes aldrig",
				str(h.get("text_ingen_forstarkning", "")), str(h.get("diskutera_forstarkning", ""))))
		elif forstarkning_s > grans:
			Spel.lagg_till_missad(_post("sen_forstarkning", "warn", "Förstärkning begärdes sent",
				str(h.get("text_sen_forstarkning", "")), str(h.get("diskutera_forstarkning", ""))))


func _post(handling: String, utfall: String, beskrivning: String, kommentar: String, diskutera: String) -> Dictionary:
	return {"tid": "Efter", "handling": handling, "namn": beskrivning, "beskrivning": beskrivning,
		"utfall": utfall, "lagrum": "Bevakningsinstruktionen – rapportering, larm och förstärkning",
		"kommentar": kommentar, "diskutera": diskutera, "saknade_krav": []}


# ------------------------------------------------------- Polisen --

func _uppdatera_polis(delta: float) -> void:
	if _polis_t < 0.0:
		if Spel.handling_utford("anmala_polis"):
			_polis_t = float(h.get("polis_efter_s", 45))
		return
	if _polis_framme:
		return
	_polis_t -= delta
	if _polis_t <= 0.0:
		_polisen_kommer()


func _polisen_kommer() -> void:
	_polis_framme = true
	var v: Varld = main.varld
	var bil: Vector2i = v.punkt(h.get("polisbil", [40, 25]))
	_polisbil = v.placera_fordon("polisbil", bil)
	main.hud.visa_ljud(_polisbil, "*IIIUUU IIIUUU*", 2.0, 30.0)
	Spel.satt_fakta({"polis_pa_plats": true})
	var mal: Vector2i = v.punkt(h.get("samling", "grind_ute"))
	var i := 0
	for id in ["polis_1", "polis_2"]:
		var n: Aktor = v.skapa_npc(id, {"sprite": "polis", "start": [bil.x - 1, bil.y + i], "synlig_fran_start": true})
		n.vila_aktiv = false
		n.ga_langs(v.vag_mot(n.cell, mal + Vector2i(2, i)))
		i += 1
	main.get_tree().create_timer(4.0).timeout.connect(func() -> void:
		_sag(v.npcer.get("polis_1"), str(h.get("polis_replik", "Polisen! Demonstrationen är upplöst.")), 3.0)
		main.get_tree().create_timer(2.5).timeout.connect(_alla_gar_hem.bind(str(h.get("ledare_polis", "")))))


func _alla_gar_hem(replik: String) -> void:
	if fas == "slut":
		return
	fas = "slut"
	_sag(_ledaren(), replik, 3.5)
	for d in demonstranter:
		if d["lage"] in ["borta", "gar_hem", "skadad", "skjuten"]:
			continue
		if d["ledare"] and main._sittande.has(str(d["id"])):
			continue
		_gar_hem(d)
	visa_knappar()
	_kolla_slut()


func _gar_hem(d: Dictionary, fart := 0.0) -> void:
	var n: Aktor = d["n"]
	if d["lage"] in ["sitter_inne", "trycker"] and main.varld.ar_inom_skyddsomrade(d["mal"]):
		_ledig_inne.append(d["mal"])
	d["lage"] = "gar_hem"
	d["sitter"] = false
	n.vaxla_still = false
	main.varld.byt_bilder(n, "demonstrant_" + str(d["variant"]))
	if fart > 0.0:
		n.hastighet = fart
	n.stanna()
	n.ga_langs(main.varld.vag_mot(n.cell, main.varld.punkt(h.get("hem", h.get("start", [51, 24])))))
	n.framme.connect(func() -> void:
		if d["lage"] == "gar_hem":
			d["lage"] = "borta"
			n.visible = false
			_kolla_slut(), CONNECT_ONE_SHOT)


func _kolla_slut() -> void:
	if _avslutad:
		return
	for d in demonstranter:
		if d["ledare"] and main._sittande.has(str(d["id"])):
			continue  # omhändertagen: sitter vid bommen och väntar på polis
		if d["lage"] in ["vantar", "kommer", "samlas", "trycker", "tillbaka", "fryst", "sitter_inne", "sitter_ute", "bars_ut"]:
			return
	_avslutad = true
	Spel.satt_fakta({"angrepp_pagar": false, "angrepp_pagar_ej": true})
	main._avsluta_handelse(h)
	visa_knappar()


# ------------------------------------------------------- Fakta --

func _uppdatera_fakta() -> void:
	var inne := false
	for d in demonstranter:
		var n: Aktor = d["n"]
		if n.visible and d["lage"] != "borta" and main.varld.ar_inom_skyddsomrade(n.cell):
			inne = true
	Spel.satt_fakta({"motpart_inom": inne, "demo_inne_nu": inne})


# ------------------------------------------------------- Knappar --

func _aktiva() -> Array[Dictionary]:
	var ut: Array[Dictionary] = []
	for d in demonstranter:
		if (d["n"] as Aktor).visible and d["lage"] in ["kommer", "samlas", "trycker", "tillbaka", "sitter_inne", "sitter_ute", "fryst"]:
			ut.append(d)
	return ut


func _narmast(lista: Array[Dictionary], max_avst := 999) -> Dictionary:
	var basta: Dictionary = {}
	var minst := max_avst + 1
	for d in lista:
		var a: int = main.varld.avstand(main.varld.spelare.cell, (d["n"] as Aktor).cell)
		if a < minst:
			minst = a
			basta = d
	return basta


func _inne() -> Array[Dictionary]:
	var ut: Array[Dictionary] = []
	for d in demonstranter:
		if d["lage"] in ["sitter_inne", "trycker"] and main.varld.ar_inom_skyddsomrade((d["n"] as Aktor).cell):
			ut.append(d)
	return ut


func _skadade() -> Array[Dictionary]:
	var ut: Array[Dictionary] = []
	for d in demonstranter:
		if d["lage"] in ["skadad", "skjuten"] and not _fh_given.has(str(d["id"])):
			ut.append(d)
	return ut


func visa_knappar() -> void:
	var val: Array = []
	if upptackt and not _aktiva().is_empty():
		val.append({"id": "halt", "text": "Halt-order", "tangent": "H", "farg": "barnsten"})
		val.append({"id": "handgemang", "text": "Handgemäng", "tangent": "G", "farg": "barnsten"})
		val.append({"id": "varningsskott", "text": "Varningsskott", "tangent": "V", "farg": "barnsten"})
		val.append({"id": "verkanseld", "text": "Verkanseld", "tangent": "F", "farg": "rosa"})
	if not _inne().is_empty() and _bar_ut.is_empty():
		val.append({"id": "avlagsna", "text": "Bär ut", "tangent": "B", "farg": "gron"})
	if not _skadade().is_empty() or (_skyddsvakt_skadad and not _fh_given.has("du")):
		val.append({"id": "forsta_hjalpen", "text": "Första hjälpen", "tangent": "J", "farg": "gron"})
	main.hud.satt_situationer(val)


func situation(id: String) -> void:
	match id:
		"halt":
			_halt()
		"handgemang":
			_handgemang()
		"varningsskott":
			_varningsskott()
		"verkanseld":
			_verkanseld()
		"avlagsna":
			_bar_ut_narmaste()
		"forsta_hjalpen":
			_forsta_hjalpen()
	visa_knappar()


## Gemensamma fakta för bedömningen: fredliga demonstranter, inget angrepp.
func _fakta_ingen_fara() -> void:
	Spel.satt_fakta({"angrepp_pagar": false, "angrepp_overhangande": false, "hot_svarare_vald": false,
		"angrepp_pagar_ej": true, "skott_utan_risk": false})


func _halt() -> void:
	antal_halt += 1
	_fakta_ingen_fara()
	var rop: Array = h.get("rop_halt", ["HALT! MILITÄR SKYDDSVAKT! HALT ELLER JAG SKJUTER SKARPT!"])
	var text := str(rop[mini(antal_halt - 1, rop.size() - 1)])
	Spel.utfor("halt_order", "Ropade halt-order mot demonstranterna" + (" igen" if antal_halt > 1 else ""))
	main.hud.visa_bubbla(main.varld.spelare, text, 3.0)
	stress += 1
	var aktiva := _aktiva()
	# Någon enstaka blir rädd och går.
	if randf() < float(h.get("chans_halt_fungerar", 0.5)):
		var kandidater: Array[Dictionary] = []
		for d in aktiva:
			if not d["envis"] and not d["ledare"] and d["lage"] != "sitter_inne":
				kandidater.append(d)
		if not kandidater.is_empty():
			var d: Dictionary = kandidater.pick_random()
			main.get_tree().create_timer(1.4).timeout.connect(func() -> void:
				if d["lage"] in ["trycker", "samlas", "sitter_ute", "tillbaka", "kommer"]:
					_sag(d["n"], str((h.get("repliker_ger_upp", ["Okej, jag går."]) as Array).pick_random()), 2.5)
					_gar_hem(d))
	# Resten buar.
	for i in mini(2, aktiva.size()):
		var d: Dictionary = aktiva.pick_random()
		main.get_tree().create_timer(0.8 + 0.6 * i).timeout.connect(func() -> void:
			_sag(d["n"], str((h.get("repliker_halt", ["Buuu!"]) as Array).pick_random()), 2.0))
	var kamrat: Array = h.get("kamrat_halt", [])
	if not kamrat.is_empty() and antal_halt >= 2:
		main.get_tree().create_timer(2.6).timeout.connect(main._kamrat_sager.bind(
			str(kamrat[mini(antal_halt - 2, kamrat.size() - 1)])))


## Handgemäng med den närmaste: knuffar tillbaka – ibland går det inte,
## ibland skadas någon, och stämningen trappas upp för varje gång.
func _handgemang() -> void:
	var lista: Array[Dictionary] = []
	for d in _aktiva():
		lista.append(d)
	var d := _narmast(lista, 2)
	if d.is_empty():
		main.hud.visa_meddelande("Ingen inom räckhåll.", 2.0)
		return
	antal_handgemang += 1
	_borjar_brakas()
	var n: Aktor = d["n"]
	var v: Varld = main.varld
	_fakta_ingen_fara()
	# Våld får användas för att hindra den som tränger sig in eller för att avlägsna
	# den som redan är inne – inte mot den som bara står och skriker utanför.
	var tranger: bool = bool(d.get("tryck", false)) or v.ar_inom_skyddsomrade(n.cell) or d["lage"] == "trycker"
	Spel.satt_fakta({"vald_behovs": tranger, "vald_proportionerligt": antal_handgemang <= int(h.get("handgemang_max_rimligt", 3))})
	Spel.utfor("handgemang", "Handgemäng med en demonstrant" + (" som trängde sig in" if tranger else " som stod utanför"))
	stress += 1
	v.spelare.vand_mot(n.global_position)
	var fram: Vector2 = (n.global_position - v.spelare.global_position).normalized() * 4.0
	var tw := v.spelare.create_tween()
	tw.tween_property(v.spelare, "position", v.spelare.position + fram, 0.08)
	tw.tween_property(v.spelare, "position", v.spelare.position, 0.14)
	main.hud.visa_ljud(n, str((h.get("ljud_handgemang", ["*KNUFF*"]) as Array).pick_random()), 0.9, 30.0)
	main.hud.visa_bubbla(v.spelare, str((h.get("rop_handgemang", ["Backa!"]) as Array).pick_random()), 2.0)
	# Skada?
	if randf() < float(h.get("chans_skada", 0.12)) + 0.04 * (antal_handgemang - 1):
		if randf() < 0.5:
			_demonstrant_skadad(d)
		else:
			_vi_skadade()
	elif randf() < float(h.get("chans_handgemang_lyckas", 0.6)) - 0.05 * stress:
		_knuffad_tillbaka(d)
	else:
		_sag(n, str((h.get("repliker_sliter", ["Släpp mig!"]) as Array).pick_random()), 2.0)
	# Upptrappning: någon filmar och ropar.
	if stress >= 2 and not bool(Spel.fakta.get("demo_filmas", false)):
		Spel.satt_fakta({"demo_filmas": true})
		var filmare: Array[Dictionary] = _aktiva()
		if not filmare.is_empty():
			var f: Dictionary = filmare.pick_random()
			main.get_tree().create_timer(1.2).timeout.connect(func() -> void:
				if main.hud.visible and (f["n"] as Aktor).visible:
					main.hud.visa_ljud(f["n"], "*filmar*", 2.0, 30.0)
					_sag(f["n"], str(h.get("replik_filmar", "Polisvåld! Det här hamnar på nätet!")), 2.8))


func _knuffad_tillbaka(d: Dictionary) -> void:
	var v: Varld = main.varld
	var n: Aktor = d["n"]
	if d["lage"] == "sitter_inne":
		return  # en som sitter knuffar man inte bort – han får bäras ut
	var bort: Vector2i = v.punkt(h.get("tillbaka_till", [34, 24]))
	var c := v.narmaste_fria(bort + Vector2i(randi_range(-1, 1), randi_range(-1, 1)), n.cell)
	if v.ar_inom_skyddsomrade(n.cell):
		_ledig_inne.append(d["mal"])
		d["mal"] = Vector2i(-1, -1)
	d["lage"] = "tillbaka"
	d["t"] = float(h.get("tillbaka_s", 8))
	d["tryck"] = false
	n.stanna()
	n.ga_langs(v.vag_mot(n.cell, c))
	_sag(n, str((h.get("repliker_knuffad", ["Aj! Rör mig inte!"]) as Array).pick_random()), 2.0)


func _demonstrant_skadad(d: Dictionary) -> void:
	var n: Aktor = d["n"]
	if d["lage"] in ["sitter_inne", "trycker"] and main.varld.ar_inom_skyddsomrade(d["mal"]):
		_ledig_inne.append(d["mal"])
	d["lage"] = "skadad"
	d["sitter"] = false
	n.stanna()
	main.varld.byt_bilder(n, "demonstrant_%s_skadad" % d["variant"])
	n.vaxla_still = false
	var blod: Sprite2D = main.varld.lagg_dekal("blod", n.cell)
	blod.scale = Vector2(0.45, 0.45)
	Spel.satt_fakta({"skadad_person": true, "demonstrant_skadad": true})
	main.hud.visa_ljud(n, "*KRASCH*", 1.0, 30.0)
	_sag(n, str(h.get("replik_skadad", "AAH! Min näsa! Han slog mig!")), 3.0)
	main.get_tree().create_timer(2.0).timeout.connect(main._kamrat_sager.bind(str(h.get("kamrat_skadad", ""))))
	_kolla_slut()


func _vi_skadade() -> void:
	if _skyddsvakt_skadad:
		return
	_skyddsvakt_skadad = true
	Spel.satt_fakta({"skadad_person": true, "skyddsvakt_skadad": true})
	main.hud.visa_ljud(main.varld.spelare, "*SMACK*", 1.0, 30.0)
	main.hud.visa_bubbla(main.varld.spelare, str(h.get("replik_vi_skadade", "Aj! Fan – armbågen i ansiktet!")), 2.5)
	var blod: Sprite2D = main.varld.lagg_dekal("blod", main.varld.spelare.cell)
	blod.scale = Vector2(0.35, 0.35)
	main.get_tree().create_timer(2.2).timeout.connect(main._kamrat_sager.bind(str(h.get("kamrat_vi_skadade", ""))))


func _varningsskott() -> void:
	antal_varningsskott += 1
	_fakta_ingen_fara()
	Spel.utfor("varningsskott", "Avlossade varningsskott mot demonstranterna")
	main._skott(1)
	stress += 2
	_panik(float(h.get("andel_flyr_varningsskott", 0.25)) * antal_varningsskott, null)
	var kamrat: Array = h.get("kamrat_varningsskott", [])
	if not kamrat.is_empty():
		main.get_tree().create_timer(1.8).timeout.connect(main._kamrat_sager.bind(
			str(kamrat[mini(antal_varningsskott - 1, kamrat.size() - 1)])))


func _verkanseld() -> void:
	var d := _narmast(_aktiva(), 15)
	if d.is_empty():
		return
	antal_verkanseld += 1
	_fakta_ingen_fara()
	Spel.utfor("verkanseld", "Avgav verkanseld mot en demonstrant")
	main._skott(1)
	stress += 3
	var n: Aktor = d["n"]
	var avst: int = main.varld.avstand(main.varld.spelare.cell, n.cell)
	var traff := randf() <= clampf(1.0 - float(avst - 3) * 0.06, 0.35, 0.95)
	if traff:
		if d["lage"] in ["sitter_inne", "trycker"] and main.varld.ar_inom_skyddsomrade(d["mal"]):
			_ledig_inne.append(d["mal"])
		d["lage"] = "skjuten"
		n.stanna()
		n.vaxla_still = true
		main.varld.byt_bilder(n, "civil_ligger")
		main._blodstank(n)
		var blod: Sprite2D = main.varld.lagg_dekal("blod", n.cell)
		blod.modulate.a = 0.0
		blod.create_tween().tween_property(blod, "modulate:a", 1.0, 1.5)
		main.hud.visa_ljud(n, "UHHH…", 1.4, 30.0)
		Spel.satt_fakta({"motpart_skjuten": true, "demonstrant_skjuten": true, "skadad_person": true})
		main.radio.krok("motpart_skjuten")
	_panik(float(h.get("andel_flyr_verkanseld", 0.4)) + 0.2 * (antal_verkanseld - 1), d)
	var kamrat: Array = h.get("kamrat_verkanseld", [])
	if not kamrat.is_empty():
		main.get_tree().create_timer(1.6).timeout.connect(main._kamrat_sager.bind(
			str(kamrat[mini(antal_verkanseld - 1, kamrat.size() - 1)])))
	_kolla_slut()


## Skott: en del flyr skrikande, resten sätter sig ner och skriker.
func _panik(andel: float, utom: Variant) -> void:
	var aktiva := _aktiva()
	aktiva.shuffle()
	var antal_flyr := int(ceil(aktiva.size() * clampf(andel, 0.0, 1.0)))
	var i := 0
	for d in aktiva:
		if d == utom:
			continue
		var n: Aktor = d["n"]
		if i < antal_flyr:
			_sag(n, str((h.get("repliker_flyr", ["AAAH!"]) as Array).pick_random()), 1.8)
			_gar_hem(d, 52.0)
		else:
			if d["lage"] in ["sitter_inne", "sitter_ute"]:
				_sag(n, str((h.get("repliker_skrak", ["Skjut inte!"]) as Array).pick_random()), 2.0)
				continue
			if d["lage"] in ["trycker"] and main.varld.ar_inom_skyddsomrade(d["mal"]):
				_ledig_inne.append(d["mal"])
				d["mal"] = Vector2i(-1, -1)
			d["lage"] = "fryst"
			d["t"] = float(h.get("fryst_s", 6))
			n.stanna()
			main.varld.byt_bilder(n, "demonstrant_%s_sitter" % d["variant"])
			n.vaxla_still = true
			if randf() < 0.5:
				_sag(n, str((h.get("repliker_skrak", ["Skjut inte!"]) as Array).pick_random()), 2.0)
		i += 1


## Vi bär ut den som sitter närmast innanför staketet (avlägsnande, 12 §).
func _bar_ut_narmaste() -> void:
	if not _bar_ut.is_empty():
		return
	var d := _narmast(_inne())
	if d.is_empty():
		return
	Spel.satt_fakta({"motpart_inom": true, "overtratt_forbud": true, "behov_avlagsna": true})
	Spel.utfor("avlagsna", "Bar ut en demonstrant som tagit sig in på skyddsobjektet")
	_bar_ut = d
	var v: Varld = main.varld
	if v.avstand(v.spelare.cell, (d["n"] as Aktor).cell) <= 1:
		_borja_bara()
	else:
		v.ga_till((d["n"] as Aktor).cell)
		v.spelare.framme.connect(_borja_bara, CONNECT_ONE_SHOT)


func _borja_bara() -> void:
	if _bar_ut.is_empty():
		return
	var d := _bar_ut
	var v: Varld = main.varld
	var n: Aktor = d["n"]
	if not d["lage"] in ["sitter_inne", "trycker"]:
		_bar_ut = {}
		return
	_ledig_inne.append(d["mal"])
	d["lage"] = "bars_ut"
	d["sitter"] = false
	_sag(n, str(h.get("replik_bars_ut", "Jag gör passivt motstånd!")), 2.5)
	var ut: Vector2i = _ledig_ute.pop_front() if not _ledig_ute.is_empty() else v.punkt("grind_ute")
	d["mal"] = ut
	var vag := v.vag(n.cell, ut)
	n.stanna()
	n.hastighet = 22.0
	n.ga_langs(vag)
	v.ga_till(ut + Vector2i(-1, 0))
	n.framme.connect(func() -> void:
		if d["lage"] == "bars_ut":
			d["lage"] = "sitter_ute"
			d["sitter"] = false
			d["ute_t"] = randf_range(float(h.get("sitter_ute_min_s", 20)), float(h.get("sitter_ute_max_s", 40)))
		_bar_ut = {}
		visa_knappar(), CONNECT_ONE_SHOT)
	visa_knappar()


func _forsta_hjalpen() -> void:
	var v: Varld = main.varld
	if _skyddsvakt_skadad and not _fh_given.has("du"):
		_fh_given["du"] = true
		Spel.utfor("forsta_hjalpen", "Tvåan gav första hjälpen till ettan")
		main._kamrat_sager(str(h.get("kamrat_fh_du", "Luta huvudet framåt. Tryck här. Det ser inte brutet ut.")))
		return
	var d := _narmast(_skadade())
	if d.is_empty():
		return
	_fh_given[str(d["id"])] = true
	Spel.utfor("forsta_hjalpen", "Gav första hjälpen till en demonstrant")
	v.ga_till((d["n"] as Aktor).cell)
	main.hud.visa_bubbla(v.spelare, str(h.get("forsta_hjalpen_replik", "Sitt still, jag hjälper dig.")), 3.0)
