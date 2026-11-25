class_name Slagsmal
extends Node
## Scenario Slagsmålet: två män slåss på vägen, klart utanför skyddsobjektet.
## Den ena slår ner den andra, sparkar honom och springer till skogs. Ibland
## smyger samtidigt en tredje person fram till staketet och fotograferar eller
## skruvar ner skyddsobjektsskylten – medan stridsparet tittar åt andra hållet.
##
## Halt-order, varningsskott och verkanseld gäller det hot som är närmast
## spelaren. Fakta sätts för just det målet innan beslutet bedöms:
##  - slagsmålet: angrepp pågår, men "svårare våld" först när han sparkar
##    en som ligger (förordning 1992:98 2 §); avstånd/utomstående (4 §) gör
##    skott diskutabla även då
##  - smygaren: inget angrepp alls – skott saknar lagstöd

var main  # Main (otypad: vi använder dess hjälpfunktioner)
var h: Dictionary
var smyg_h: Dictionary = {}

## Lägen: vantar, brak (vid stugan), jagar (nerför vägen), slass, sparkar, stannat, flyr, borta, skjuten
var brakare_lage := "vantar"
## Lägen: slass, nere, staende
var offret_lage := "slass"
## Lägen: vantar, gar_dit, jobbar, stannat, flyr, borta, skjuten
var smyg_lage := "vantar"
var upptackt := false
var smyg_upptackt := false

var _t := 0.0
var _slag_t := 0.0
var _replik_t := 0.0
var _fas_t := 0.0
var _smyg_t := 0.0
var _jobb_t := 0.0
var _lamnat_rapporterat := false
## Halt-order och varningsskott ges en gång per person (mål).
var _halt_givet: Dictionary = {}
var _varn_givet: Dictionary = {}
var _skylt_saknad_sagd := false


func setup(p_main, p_h: Dictionary) -> void:
	main = p_main
	h = p_h
	var b: Aktor = _brakare()
	var o: Aktor = _offret()
	var plats: Vector2i = main.varld.punkt(h.get("plats", "slagsmal"))
	b.cell = plats
	o.cell = plats + Vector2i(0, 1)
	for n: Aktor in [b, o]:
		n.stanna()
		n.visible = true
		n.vila_aktiv = false
	b.vand_mot(o.global_position)
	o.vand_mot(b.global_position)
	# Det börjar med bråk vid stugan, nära oss; sedan drar de iväg nerför vägen.
	brakare_lage = "brak"
	_fas_t = float(h.get("brak_s", 3.5))
	Spel.satt_fakta({"angrepp_pagar": true, "brott_pa_bar_garning": true})


func _brakare() -> Aktor:
	return main.varld.npcer.get(str(h.get("brakare", "brakaren")))


func _offret() -> Aktor:
	return main.varld.npcer.get(str(h.get("offer", "offret")))


func _smygaren() -> Aktor:
	return main.varld.npcer.get(str(smyg_h.get("npc", "smygaren")))


func _process(delta: float) -> void:
	if not Spel.klocka_igang:
		return
	_t += delta
	_uppdatera_slagsmal(delta)
	_uppdatera_smygare(delta)
	_bevaka_posten()


# ------------------------------------------------------------ Slagsmålet --

func _uppdatera_slagsmal(delta: float) -> void:
	var b := _brakare()
	var o := _offret()
	if b == null or o == null:
		return
	# Upptäckt: bråket hörs och syns långt.
	if not upptackt and brakare_lage in AKTIVA:
		var avst: int = main.varld.avstand(main.varld.spelare.cell, b.cell)
		if avst <= int(h.get("upptacks_avstand", 18)):
			_upptack_slagsmal()
	if brakare_lage == "brak":
		_replik_t -= delta
		if _replik_t <= 0.0 and main.hud.visible:
			_replik_t = 1.6
			main.hud.visa_bubbla(b, str((h.get("repliker_brak", ["Kom igen då!"]) as Array).pick_random()), 1.6)
			main.hud.visa_ljud(o, "PUFF", 0.7, 30.0)
		_fas_t -= delta
		if _fas_t <= 0.0:
			_borja_jakt()
	if brakare_lage in ["slass", "sparkar"]:
		_slag_t -= delta
		if _slag_t <= 0.0:
			_slag_t = randf_range(0.7, 1.1) if brakare_lage == "slass" else 0.9
			_slag(b, o)
		_replik_t -= delta
		if _replik_t <= 0.0 and main.hud.visible:
			_replik_t = randf_range(2.6, 3.6)
			var nyckel := "repliker_slass" if brakare_lage == "slass" else "repliker_sparkar"
			var rep: Array = h.get(nyckel, [])
			if not rep.is_empty():
				var vem: Aktor = b if brakare_lage == "sparkar" or randf() < 0.6 else o
				if vem == o and offret_lage == "slass":
					rep = h.get("repliker_offret", rep)
				main.hud.visa_bubbla(vem, str(rep.pick_random()), 2.2)
		_fas_t -= delta
		if _fas_t <= 0.0:
			if brakare_lage == "slass":
				_slar_ner()
			else:
				_flyr("efter_sparkar")
	_uppdatera_fakta()


const AKTIVA := ["brak", "jagar", "slass", "sparkar"]


## Offret springer nerför vägen och bråkaren efter – bort från skyddsobjektet.
func _borja_jakt() -> void:
	var b := _brakare()
	var o := _offret()
	brakare_lage = "jagar"
	var mal: Vector2i = main.varld.punkt(h.get("mal", "slagsmal_mal"))
	o.hastighet = float(h.get("fart_jakt", 40))
	b.hastighet = float(h.get("fart_jakt", 40)) * 0.95
	o.framme.connect(_framme_nerfor, CONNECT_ONE_SHOT)
	main.varld.flytta_npc(str(h.get("offer", "offret")), mal)
	main.varld.flytta_npc(str(h.get("brakare", "brakaren")), mal + Vector2i(0, -1))
	if main.hud.visible:
		main.hud.visa_bubbla(o, str(h.get("offret_springer", "Lägg av! LÄGG AV!")), 2.0)
	if upptackt:
		main.get_tree().create_timer(1.0).timeout.connect(main._kamrat_sager.bind(str(h.get("kamrat_jakt", ""))))


func _framme_nerfor() -> void:
	if brakare_lage != "jagar":
		return
	var b := _brakare()
	var o := _offret()
	b.stanna()
	o.vand_mot(b.global_position)
	b.vand_mot(o.global_position)
	brakare_lage = "slass"
	_fas_t = randf_range(float(h.get("slass_min_s", 12)), float(h.get("slass_max_s", 18)))


func _slag(b: Aktor, o: Aktor) -> void:
	var mal: Aktor = o if brakare_lage == "sparkar" or randf() < 0.65 else b
	var ljud: Array = h.get("ljud_sparkar" if brakare_lage == "sparkar" else "ljud_slag", ["SMACK"])
	if main.hud.visible:
		main.hud.visa_ljud(mal, str(ljud.pick_random()), 0.8, 30.0)
	# Liten knuff i bilden.
	var slagare: Aktor = b if mal == o else o
	var fram: Vector2 = (mal.global_position - slagare.global_position).normalized() * 3.0
	var tw := slagare.create_tween()
	tw.tween_property(slagare, "position", slagare.position + fram, 0.08)
	tw.tween_property(slagare, "position", slagare.position, 0.12)


func _upptack_slagsmal() -> void:
	upptackt = true
	Spel.satt_fakta({"slagsmal_upptackt": true})
	main._markera_upptackt(h)
	main._larm_har_skett = true
	main.snack.pausa(600.0)
	main.radio.krok("upptackt")
	main.varld.satt_larm(str(h.get("brakare", "brakaren")))
	main._kamrat_sager(str(h.get("kamrat", "")))
	main.varld.kollega.vand_mot(_brakare().global_position)
	visa_knappar()


## Han slår ner offret: offret ligger, blöder, och han börjar sparka.
func _slar_ner() -> void:
	var o := _offret()
	brakare_lage = "sparkar"
	offret_lage = "nere"
	o.stanna()
	o.vaxla_still = true
	main.varld.byt_bilder(o, str(h.get("offer_ligger", "civil_ligger")))
	main.hud.visa_ljud(o, "BONK", 1.3, 30.0)
	main._blodstank(o)
	var blod: Sprite2D = main.varld.lagg_dekal("blod", o.cell)
	blod.modulate.a = 0.0
	blod.create_tween().tween_property(blod, "modulate:a", 1.0, 1.5)
	Spel.satt_fakta({"offret_nere": true})
	_fas_t = randf_range(float(h.get("sparkar_min_s", 4)), float(h.get("sparkar_max_s", 6)))
	if upptackt:
		main.get_tree().create_timer(0.8).timeout.connect(main._kamrat_sager.bind(str(h.get("kamrat_nere", ""))))
	visa_knappar()


## Han springer till skogs (efter sparkarna, eller när vi ropar/skjuter).
func _flyr(orsak: String) -> void:
	if brakare_lage in ["flyr", "borta", "skjuten"]:
		return
	var b := _brakare()
	var stoppad_tidigt := brakare_lage in ["brak", "jagar", "slass"] or (brakare_lage == "stannat" and offret_lage != "nere")
	if brakare_lage == "stannat":
		main.varld.byt_bilder(b, "yxman_utan")
		b.vaxla_still = false
	brakare_lage = "flyr"
	_offret().stanna()
	Spel.satt_fakta({"angrepp_pagar": false, "angrepp_overhangande": false, "angrepp_pagar_ej": true})
	b.hastighet = float(h.get("fart_flykt", 46))
	var replik := str(h.get("brakare_flyr_" + orsak, h.get("brakare_flyr", "")))
	if replik != "" and main.hud.visible:
		main.hud.visa_bubbla(b, replik, 2.2)
	if stoppad_tidigt:
		# Slagsmålet bröts innan han slog ner honom: offret står kvar, omtumlad.
		offret_lage = "staende"
		var o := _offret()
		Spel.satt_fakta({"offret_lindrigt_skadat": true})
		main.get_tree().create_timer(1.6).timeout.connect(func() -> void:
			if main.hud.visible:
				main.hud.visa_bubbla(o, str(h.get("offret_tack", "")), 3.0))
		# Han muttrar och går in i stugan igen i stället för att bli stående på vägen.
		main.get_tree().create_timer(float(h.get("offret_stannar_s", 9.0))).timeout.connect(_offret_gar_in)
	b.framme.connect(_brakare_borta, CONNECT_ONE_SHOT)
	main.varld.flytta_npc(str(h.get("brakare", "brakaren")), main.varld.punkt(h.get("flykt", "kant_nordost")))
	if upptackt:
		main.get_tree().create_timer(1.4).timeout.connect(main._kamrat_sager.bind(str(h.get("kamrat_flyr", ""))))
	visa_knappar()


func _offret_gar_in() -> void:
	if offret_lage != "staende":
		return
	var o := _offret()
	offret_lage = "gar_in"
	o.hastighet = 26.0
	if main.hud.visible:
		main.hud.visa_bubbla(o, str((h.get("offret_muttrar", ["…"]) as Array).pick_random()), 2.5)
	o.framme.connect(func() -> void:
		if offret_lage == "gar_in":
			offret_lage = "inne"
			Spel.satt_fakta({"offret_inne": true})
			o.visible = false
			visa_knappar(), CONNECT_ONE_SHOT)
	main.varld.flytta_npc(str(h.get("offer", "offret")), main.varld.punkt(h.get("hem", "stuga_dorr")))
	visa_knappar()


func _brakare_borta() -> void:
	if brakare_lage != "flyr":
		return
	brakare_lage = "borta"
	_brakare().visible = false
	Spel.satt_fakta({"brakare_flytt": true})
	_slagsmal_slut()
	main.varld.satt_larm("")
	main._avsluta_handelse(h)
	Spel.satt_fakta({"angrepp_pagar": false, "angrepp_overhangande": false, "angrepp_pagar_ej": true})
	visa_knappar()


## Slagsmålet är över: en stund senare (lite fippel, lite radiotrafik) kommer smygaren.
var _slut_meddelat := false


func _slagsmal_slut() -> void:
	if _slut_meddelat:
		return
	_slut_meddelat = true
	var ms: Dictionary = main._vantande_smygare
	var sek := float(ms.get("efter_slagsmalet_s", 30)) if not ms.is_empty() else 30.0
	main.get_tree().create_timer(sek).timeout.connect(main._starta_vantande_smygare)


## Fakta för bedömningen följer slagsmålet (gäller när målet är slagsmålet).
func _uppdatera_fakta() -> void:
	if _aktuellt_mal() != "brakare":
		return
	Spel.satt_fakta({
		"angrepp_pagar": brakare_lage in AKTIVA,
		"angrepp_pagar_ej": not brakare_lage in AKTIVA,
		"angrepp_overhangande": brakare_lage in AKTIVA,
		"hot_svarare_vald": brakare_lage == "sparkar",
	})


# ------------------------------------------------------------ Smygaren --

## Startas av huvudskriptet (händelse 2) en stund efter att slagsmålet börjat.
func starta_smygare(p_h: Dictionary) -> void:
	smyg_h = p_h
	var n := _smygaren()
	if n == null:
		return
	main._valj_variant(smyg_h)
	smyg_lage = "gar_dit"
	n.visible = true
	n.vila_aktiv = false
	n.hastighet = float(smyg_h.get("fart", 26))
	n.framme.connect(_smygare_framme, CONNECT_ONE_SHOT)
	main.varld.flytta_npc(str(smyg_h.get("npc", "smygaren")), main.varld.punkt(smyg_h.get("mal", "skylt_ute")))
	# Han kan upptäckas redan när han kommer ur skogen.
	main._starta_upptackt(smyg_h, n, str(smyg_h.get("npc", "smygaren")))


func _smygare_framme() -> void:
	if smyg_lage != "gar_dit":
		return
	var n := _smygaren()
	smyg_lage = "jobbar"
	n.vand_mot(main.varld.cell_pos(main.varld.punkt(smyg_h.get("skylt", [26, 18]))))
	_jobb_t = float(smyg_h.get("jobbar_s", 7))


func _uppdatera_smygare(delta: float) -> void:
	var n := _smygaren()
	if n == null:
		return
	if smyg_lage == "jobbar":
		_smyg_t -= delta
		if _smyg_t <= 0.0:
			_smyg_t = 1.1
			var ljud := "KLICK KLICK" if Spel.variant == "foto" else "*skruv skruv*"
			# Skruvandet hörs bara på nära håll.
			var hors: bool = main.varld.avstand(main.varld.spelare.cell, n.cell) <= int(smyg_h.get("ljud_hors_inom", 8))
			if main.hud.visible and hors:
				main.hud.visa_ljud(n, ljud, 0.9, 30.0)
		_jobb_t -= delta
		if _jobb_t <= 0.0:
			if Spel.variant == "skylt":
				main.varld.ta_bort_skylt(main.varld.punkt(smyg_h.get("skylt", [26, 18])))
				Spel.satt_fakta({"skylt_stulen": true})
				if smyg_upptackt:
					Spel.satt_fakta({"skylt_stold_kand": true})
				# Han bär skylten under armen när han springer.
				var skylt := Sprite2D.new()
				skylt.name = "BurenSkylt"
				skylt.texture = load("res://assets/gfx/skylt.png")
				skylt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				skylt.scale = Vector2(0.55, 0.55)
				skylt.position = Vector2(7, -15)
				n.add_child(skylt)
			else:
				Spel.satt_fakta({"objekt_fotograferat": true})
			_smygare_flyr("klar")
	# Skylten saknas: upptäcks i efterhand när man kommer tillbaka.
	if bool(Spel.fakta.get("skylt_stulen", false)) and not smyg_upptackt and not _skylt_saknad_sagd \
			and not bool(Spel.fakta.get("skylt_tappad", false)):
		var c: Vector2i = main.varld.punkt(smyg_h.get("skylt", [26, 18]))
		if main.varld.avstand(main.varld.spelare.cell, c) <= 6 and main.hud.visible:
			_skylt_saknad_sagd = true
			Spel.satt_fakta({"skylt_saknas_upptackt": true, "skylt_stold_kand": true})
			main._kamrat_sager(str(smyg_h.get("kamrat_skylt_borta", "")))


func _smygare_flyr(orsak: String) -> void:
	if smyg_lage in ["flyr", "borta", "skjuten", "vantar"]:
		return
	var n := _smygaren()
	var tidigt := smyg_lage != "jobbar" or _jobb_t > 0.0
	if orsak == "drar":
		tidigt = false
	if smyg_lage == "jobbar" and orsak != "klar" and Spel.variant == "skylt":
		Spel.satt_fakta({"skylt_raddad": true})
	smyg_lage = "flyr"
	n.hastighet = float(smyg_h.get("fart_flykt", 48))
	if orsak != "klar" and main.hud.visible and tidigt:
		main.hud.visa_bubbla(n, str(smyg_h.get("replik_flyr", "")), 2.0)
	n.framme.connect(func() -> void:
		if smyg_lage == "flyr":
			smyg_lage = "borta"
			n.visible = false
			if main._upptackt.get("nod") == n:
				main._upptackt = {}
			main._avsluta_handelse(smyg_h)
			visa_knappar(), CONNECT_ONE_SHOT)
	main.varld.flytta_npc(str(smyg_h.get("npc", "smygaren")), main.varld.punkt(smyg_h.get("flykt", "kant_nordost")))
	visa_knappar()


## Han tappar skylten i flykten: den blir liggande på marken.
func _tappa_skylten() -> void:
	var n := _smygaren()
	if n == null or not n.has_node("BurenSkylt"):
		return
	n.get_node("BurenSkylt").queue_free()
	main.varld.lagg_foremal("skylt", n.cell)
	Spel.satt_fakta({"skylt_raddad": true, "skylt_tappad": true})
	if main.hud.visible:
		main.hud.visa_ljud(n, "*klonk*", 1.0, 20.0)
		main.hud.visa_bubbla(n, str(smyg_h.get("replik_tappar", "Fan!")), 1.8)
	main.get_tree().create_timer(1.6).timeout.connect(main._kamrat_sager.bind(str(smyg_h.get("kamrat_tappar", ""))))


## Kamraten har sett smygaren (huvudskriptets upptäckt).
func smygare_upptackt() -> void:
	smyg_upptackt = true
	Spel.satt_fakta({"smygare_sedd": true})
	if bool(Spel.fakta.get("skylt_stulen", false)):
		Spel.satt_fakta({"skylt_stold_kand": true})
	visa_knappar()


# ------------------------------------------------------------ Knappar --

## Det hot som är närmast spelaren: "brakare", "smygare" eller "".
func _aktuellt_mal() -> String:
	var kandidater: Array = []
	if upptackt and brakare_lage in AKTIVA + ["stannat", "flyr"]:
		kandidater.append(["brakare", _brakare()])
	if smyg_upptackt and smyg_lage in ["gar_dit", "jobbar", "stannat", "flyr"]:
		kandidater.append(["smygare", _smygaren()])
	var basta := ""
	var minst := 9999
	for k: Array in kandidater:
		var a: int = main.varld.avstand(main.varld.spelare.cell, (k[1] as Aktor).cell)
		if a < minst:
			minst = a
			basta = str(k[0])
	return basta


func hanterar() -> bool:
	return upptackt or smyg_upptackt


func visa_knappar() -> void:
	var val: Array = []
	var mal := _aktuellt_mal()
	if mal != "":
		if not _halt_givet.has(mal):
			val.append({"id": "halt", "text": "Halt-order", "tangent": "H", "farg": "barnsten"})
		if not _varn_givet.has(mal):
			val.append({"id": "varningsskott", "text": "Varningsskott", "tangent": "V", "farg": "barnsten"})
		val.append({"id": "verkanseld", "text": "Verkanseld", "tangent": "F", "farg": "rosa"})
	var skadad := offret_lage in ["nere", "staende", "gar_in"] or brakare_lage == "skjuten" or smyg_lage == "skjuten"
	if skadad and not bool(Spel.fakta.get("forsta_hjalp_given", false)):
		val.append({"id": "forsta_hjalpen", "text": "Första hjälpen", "tangent": "J", "farg": "gron"})
	main.hud.satt_situationer(val)


func situation(id: String) -> void:
	var mal := _aktuellt_mal()
	match id:
		"halt":
			if mal == "" or _halt_givet.has(mal):
				return
			_halt_givet[mal] = true
			_halt(mal)
			visa_knappar()
		"varningsskott":
			if mal == "" or _varn_givet.has(mal):
				return
			_varn_givet[mal] = true
			_varningsskott(mal)
		"verkanseld":
			_verkanseld(mal)
		"forsta_hjalpen":
			_forsta_hjalpen()


## Fakta för det mål vi agerar mot, innan beslutet bedöms.
func _fakta_for(mal: String) -> void:
	# Varning och varningsskott räknas per person.
	Spel.satt_fakta({"varning_given": _halt_givet.has(mal), "varningsskott_foregick": _varn_givet.has(mal)})
	if mal == "brakare":
		_uppdatera_fakta()
		var avst: int = main.varld.avstand(main.varld.spelare.cell, _brakare().cell)
		Spel.satt_fakta({"skott_utan_risk": avst <= int(h.get("sakert_skjutavstand", 6)),
			"mal_inom_skyddsobjekt": false})
	elif mal == "smygare":
		Spel.satt_fakta({"angrepp_pagar": false, "angrepp_overhangande": false, "hot_svarare_vald": false,
			"skott_utan_risk": false, "mal_inom_skyddsobjekt": true})


func _halt(mal: String) -> void:
	_fakta_for(mal)
	Spel.utfor("halt_order", "Ropade: ”Halt! Militär skyddsvakt! Halt eller jag skjuter skarpt!”" +
		(" (mot mannen vid skylten)" if mal == "smygare" else " (mot slagsmålet)" if mal == "brakare" else ""))
	main.hud.visa_bubbla(main.varld.spelare, "HALT! MILITÄR SKYDDSVAKT! HALT ELLER JAG SKJUTER SKARPT!", 3.5)
	if mal == "brakare" and brakare_lage in AKTIVA:
		main.get_tree().create_timer(1.2).timeout.connect(_flyr.bind("halt"))
	elif mal == "smygare" and smyg_lage in ["gar_dit", "jobbar"]:
		main.get_tree().create_timer(0.9).timeout.connect(_smygare_flyr.bind("halt"))
	elif mal == "smygare" and smyg_lage == "flyr":
		# Halt-ordern får honom att tappa skylten (han springer vidare).
		main.get_tree().create_timer(0.7).timeout.connect(_tappa_skylten)


func _varningsskott(mal: String) -> void:
	if mal == "":
		return
	_fakta_for(mal)
	Spel.utfor("varningsskott", "Avlossade varningsskott" +
		(" mot mannen vid skylten" if mal == "smygare" else " mot slagsmålet på vägen"))
	main._skott(1)
	# Ibland stannar de tvärt (och reagerar kraftigt), annars springer de.
	if mal == "brakare" and brakare_lage in AKTIVA:
		if randf() < float(h.get("chans_stanna_varningsskott", 0.5)):
			main.get_tree().create_timer(0.5).timeout.connect(_brakare_stannar)
		else:
			main.get_tree().create_timer(0.6).timeout.connect(_flyr.bind("skott"))
	elif mal == "smygare" and smyg_lage == "flyr":
		if randf() < float(smyg_h.get("chans_tappa_varningsskott", 0.5)):
			main.get_tree().create_timer(0.4).timeout.connect(_tappa_skylten)
	elif mal == "smygare" and smyg_lage in ["gar_dit", "jobbar"]:
		if randf() < float(smyg_h.get("chans_stanna_varningsskott", 0.5)):
			main.get_tree().create_timer(0.4).timeout.connect(_smygare_stannar)
		else:
			main.get_tree().create_timer(0.5).timeout.connect(_smygare_flyr.bind("skott"))
	visa_knappar()


## Varningsskottet fick honom att tvärstanna: händerna upp, skräckslagen.
func _brakare_stannar() -> void:
	if not brakare_lage in AKTIVA:
		return
	var b := _brakare()
	var o := _offret()
	brakare_lage = "stannat"
	if offret_lage != "nere":
		Spel.satt_fakta({"offret_lindrigt_skadat": true})
	b.stanna()
	o.stanna()
	b.vaxla_still = true
	main.varld.byt_bilder(b, "yxman_upp")
	Spel.satt_fakta({"angrepp_pagar": false, "angrepp_overhangande": false, "angrepp_pagar_ej": true,
		"motpart_gett_upp": true, "brakare_stannat": true})
	if main.hud.visible:
		main.hud.visa_bubbla(b, str(h.get("brakare_stannar", "SKJUT INTE!")), 3.5)
		if offret_lage != "nere":
			main.get_tree().create_timer(2.0).timeout.connect(func() -> void:
				if main.hud.visible:
					main.hud.visa_bubbla(o, str(h.get("offret_skott", "Herregud… skjuter de?!")), 2.5))
	main.get_tree().create_timer(2.2).timeout.connect(main._kamrat_sager.bind(str(h.get("kamrat_stannat", "Han stannade. Händerna upp!"))))
	# En stund senare tar han chansen och drar.
	main.get_tree().create_timer(float(h.get("stannar_s", 14))).timeout.connect(func() -> void:
		if brakare_lage == "stannat":
			if main.hud.visible:
				main.hud.visa_bubbla(b, str(h.get("brakare_drar", "Jag drar!")), 2.0)
			_flyr("drar"))
	visa_knappar()


func _smygare_stannar() -> void:
	if not smyg_lage in ["gar_dit", "jobbar"]:
		return
	var n := _smygaren()
	if smyg_lage == "jobbar":
		Spel.satt_fakta({"skylt_raddad": true})
	smyg_lage = "stannat"
	n.stanna()
	if main.hud.visible:
		main.hud.visa_bubbla(n, str(smyg_h.get("replik_stannar", "SKJUT INTE!")), 3.5)
	main.get_tree().create_timer(float(smyg_h.get("stannar_s", 10))).timeout.connect(func() -> void:
		if smyg_lage == "stannat":
			_smygare_flyr("drar"))
	visa_knappar()


func _verkanseld(mal: String) -> void:
	if mal == "":
		return
	_fakta_for(mal)
	Spel.utfor("verkanseld", "Avgav verkanseld" +
		(" mot mannen vid skylten" if mal == "smygare" else " mot mannen i slagsmålet"))
	main._skott(1)
	var n: Aktor = _brakare() if mal == "brakare" else _smygaren()
	var avst: int = main.varld.avstand(main.varld.spelare.cell, n.cell)
	# Långt håll i mörker: inte säkert att det träffar.
	if randf() > clampf(1.0 - float(avst - 4) * 0.06, 0.35, 0.95):
		if mal == "brakare":
			_flyr("skott")
		else:
			_smygare_flyr("skott")
		return
	Spel.satt_fakta({"brakare_skjuten" if mal == "brakare" else "smygare_skjuten": true})
	if mal == "brakare":
		brakare_lage = "skjuten"
		_slagsmal_slut()
	else:
		if smyg_lage == "jobbar" and _jobb_t > 0.0:
			Spel.satt_fakta({"skylt_raddad": true})
		smyg_lage = "skjuten"
	n.stanna()
	n.vaxla_still = true
	main.varld.byt_bilder(n, "yxman_ligger" if mal == "brakare" else "smygare_ligger")
	main._blodstank(n)
	var blod: Sprite2D = main.varld.lagg_dekal("blod", n.cell)
	blod.modulate.a = 0.0
	blod.create_tween().tween_property(blod, "modulate:a", 1.0, 1.5)
	main.hud.visa_ljud(n, "UHHH…", 1.4, 30.0)
	Spel.satt_fakta({"motpart_skjuten": true, "angrepp_pagar": false, "angrepp_pagar_ej": true})
	main.get_tree().create_timer(1.6).timeout.connect(main._kamrat_sager.bind(
		str(h.get("kamrat_skjuten_" + mal, h.get("kamrat_skjuten", "")))))
	main.radio.krok("motpart_skjuten")
	visa_knappar()


## Första hjälpen till den som ligger närmast (vi går dit).
func _forsta_hjalpen() -> void:
	var kandidater: Array = []
	if offret_lage in ["nere", "staende", "gar_in"]:
		kandidater.append(_offret())
	if brakare_lage == "skjuten":
		kandidater.append(_brakare())
	if smyg_lage == "skjuten":
		kandidater.append(_smygaren())
	if kandidater.is_empty():
		return
	kandidater.sort_custom(func(a: Aktor, b: Aktor) -> bool:
		return main.varld.avstand(main.varld.spelare.cell, a.cell) < main.varld.avstand(main.varld.spelare.cell, b.cell))
	var n: Aktor = kandidater[0]
	# Offret som klarade sig lindrigt tackar nej (på ryska, engelska och svenska) och går hem.
	if n == _offret() and offret_lage in ["staende", "gar_in"]:
		Spel.utfor("forsta_hjalpen", "Erbjöd första hjälpen – mannen avböjde")
		main.hud.visa_bubbla(main.varld.spelare, "Är du skadad? Behöver du hjälp?", 2.5)
		main.get_tree().create_timer(1.8).timeout.connect(func() -> void:
			if main.hud.visible and n.visible:
				main.hud.visa_bubbla(n, str((h.get("offret_nej_tack", ["Нет, спасибо. No thank you. Nej tack!"]) as Array).pick_random()), 3.0))
		visa_knappar()
		return
	Spel.utfor("forsta_hjalpen", "Gav första hjälpen")
	main.varld.ga_till(n.cell)
	main.hud.visa_bubbla(main.varld.spelare, str(h.get("forsta_hjalpen_replik", "Ligg still, hjälp är på väg.")), 3.0)
	visa_knappar()


# ------------------------------------------------------------ Posten --

## Lämnar stridsparet skyddsobjektet medan det pågår något? (Avledning.)
func _bevaka_posten() -> void:
	if _lamnat_rapporterat or not upptackt:
		return
	var grind: Vector2i = main.varld.punkt("grind")
	if main.varld.avstand(main.varld.spelare.cell, grind) > int(h.get("posten_radie", 9)) \
			and main.varld.avstand(main.varld.kollega.cell, grind) > int(h.get("posten_radie", 9)):
		_lamnat_rapporterat = true
		Spel.utfor("lamnade_posten", "Lämnade skyddsobjektet (båda) för att gå till slagsmålet")
