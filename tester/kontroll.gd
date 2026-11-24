extends Node
## Automatisk kontroll som körs i GitHub Actions (utan grafik):
##   godot --headless --path . res://tester/kontroll.tscn
##
## 1. Laddar alla skript (fångar tolkningsfel).
## 2. Läser alla JSON-filer och kontrollerar dialogens kopplingar mot lagrum.json.
## 3. Spelar igenom scenario 1 automatiskt: startar passet, forcerar händelse 1,
##    tar kontakt, väljer "begär identitet" -> "kräv igen" -> "omhänderta",
##    och kontrollerar debriefingens bedömningar.
## Avslutar med felkod = antal fel, så att arbetsflödet misslyckas vid fel.

var fel := 0


func _ready() -> void:
	Engine.time_scale = 8.0
	print("=== Halt, militär skyddsvakt!: automatisk kontroll ===")
	Spel.titel_visad = true
	_kontrollera_skript()
	_kontrollera_data()
	await _spela_scenario_1()
	await _spela_dronaren_med_pilot()
	await _spela_dronaren_utan_pilot()
	await _spela_missad_handelse()
	await _spela_hantverkaren("oriktig", [0, 2], {"begara_identitet": "ok", "avvisa": "ok"})
	await _spela_hantverkaren("arlig", [0, 0, 1], {"rapportera_vaktchef": "ok", "avvisa": "bad"})
	await _spela_yxmannen_ger_upp()
	await _spela_yxmannen_skarp()
	await _spela_yxmannen_for_tidigt()
	await _spela_yxmannen_nar_fram()
	await _bygg_alla_objekttyper()
	print("--- Kompakt läge (pekskärm) ---")
	UiKit.kompakt = true
	await _spela_scenario_1()
	UiKit.kompakt = false
	Engine.time_scale = 1.0
	if fel == 0:
		print("=== RESULTAT: OK ===")
	else:
		printerr("=== RESULTAT: %d FEL ===" % fel)
	get_tree().quit(fel)


func _fel(text: String) -> void:
	fel += 1
	printerr("FEL: " + text)


func _ok(text: String) -> void:
	print("ok   " + text)


func _kontrollera_skript() -> void:
	for sokvag in _filer("res://scripts", ".gd"):
		var s: Script = load(sokvag)
		if s == null or not s.can_instantiate():
			_fel("kunde inte ladda skript " + sokvag)
		else:
			_ok(sokvag)


func _kontrollera_data() -> void:
	var lagrum := Datafil.las_json("res://data/lagrum.json")
	var snack := Datafil.las_json("res://data/kamratsnack.json")
	var karta := Datafil.las_json("res://data/kartor/granasen.json")
	var brus := Datafil.las_json("res://data/radiobrus.json")
	for par in [["lagrum.json", lagrum], ["kamratsnack.json", snack], ["granasen.json", karta], ["radiobrus.json", brus]]:
		if (par[1] as Dictionary).is_empty():
			_fel("tom eller ogiltig JSON: " + str(par[0]))
	var handlingar: Dictionary = lagrum.get("handlingar", {})
	for sc in Spel.scenarier():
		_kontrollera_scenario(str(sc["sokvag"]), handlingar, karta)
	if Spel.scenarier().size() < 2:
		_fel("färre än två scenarier i index.json")


func _kontrollera_scenario(sokvag: String, handlingar: Dictionary, karta: Dictionary) -> void:
	var scenario := Datafil.las_json(sokvag)
	if scenario.is_empty():
		_fel("tom eller ogiltig JSON: " + sokvag)
		return
	var punkter: Dictionary = karta.get("punkter", {})
	for id in scenario.get("npc", {}):
		var start: Variant = scenario["npc"][id].get("start", [])
		if start is String and not punkter.has(start):
			_fel("%s: npc %s har okänd startpunkt '%s'" % [sokvag, id, start])
	var dialog: Dictionary = scenario.get("dialog", {})
	for nod_id in dialog:
		for alt in dialog[nod_id].get("alternativ", []):
			var h := str(alt.get("handling", ""))
			if h != "" and not handlingar.has(h):
				_fel("dialog '%s' pekar på okänd handling '%s'" % [nod_id, h])
			var nasta := str(alt.get("nasta", ""))
			if nasta != "" and not dialog.has(nasta):
				_fel("dialog '%s' pekar på okänd nod '%s'" % [nod_id, nasta])
	# Åtgärdsraden: scenariots standardreaktioner och nodernas egna.
	var reaktioner: Array = [["atgarder", scenario.get("atgarder", {})]]
	for nod_id in dialog:
		var egna: Variant = dialog[nod_id].get("atgarder", {})
		if egna is Dictionary:
			reaktioner.append([nod_id, egna])
	for par in reaktioner:
		for h: String in par[1]:
			if h == "kommentar":
				continue
			if not handlingar.has(h):
				_fel("%s: åtgärd '%s' finns inte i lagrum.json" % [par[0], h])
			var nasta := str(par[1][h].get("nasta", ""))
			if nasta != "" and not dialog.has(nasta):
				_fel("%s: åtgärd '%s' pekar på okänd nod '%s'" % [par[0], h, nasta])
			if nasta == "" and not par[1][h].has("replik"):
				_fel("%s: åtgärd '%s' saknar både nasta och replik" % [par[0], h])
	for val in scenario.get("sambandsval", []):
		var h := str(val.get("handling", ""))
		if h != "" and not handlingar.has(h):
			_fel("sambandsval pekar på okänd handling '%s'" % h)
	_kontrollera_radio(scenario, handlingar, sokvag)
	_ok("data och dialogkopplingar: " + sokvag.get_file())


## Radiokrokarna: kända krokar, kända handlingar och varianter, och att
## varje inslag har meddelanden med avsändare och text.
const RADIOKROKAR := ["upptackt", "kontakt_start", "kontakt_slut", "npc_lamnar", "dronare_flyger_bort",
	"dronare_landar", "motpart_ger_upp", "motpart_skjuten", "angrepp_nadde_fram", "motpart_omhandertagen"]


func _kontrollera_radio(scenario: Dictionary, handlingar: Dictionary, sokvag: String) -> void:
	var radio: Dictionary = scenario.get("radio", {})
	var varianter: Dictionary = scenario.get("varianter", {})
	for krok: String in radio:
		if krok == "kommentar":
			continue
		if krok.begins_with("handling:"):
			if not handlingar.has(krok.substr(9)):
				_fel("%s: radiokrok för okänd handling '%s'" % [sokvag, krok])
		elif not krok in RADIOKROKAR:
			_fel("%s: okänd radiokrok '%s'" % [sokvag, krok])
		for d in radio[krok]:
			for nyckel in ["om_ej_handling", "om_handling"]:
				var h := str(d.get(nyckel, ""))
				if h != "" and not handlingar.has(h):
					_fel("%s: radio %s har okänd handling '%s'" % [sokvag, krok, h])
			var v: Variant = d.get("variant", "")
			for namn in (v if v is Array else [v]):
				if str(namn) != "" and not varianter.has(str(namn)):
					_fel("%s: radio %s har okänd variant '%s'" % [sokvag, krok, namn])
			var med: Array = d.get("meddelanden", [])
			if med.is_empty():
				_fel("%s: radio %s saknar meddelanden" % [sokvag, krok])
			for mm in med:
				if str(mm.get("fran", "")) == "" or str(mm.get("text", "")) == "":
					_fel("%s: radio %s har meddelande utan avsändare eller text" % [sokvag, krok])


## Väntar (högst max_s sekunder speltid) på att en radiorad som innehåller text dyker upp.
func _vanta_radio(text: String, max_s := 60.0) -> bool:
	var t := 0.0
	while t < max_s:
		for rad in Spel.samband:
			if str(rad.get("text", "")).contains(text):
				return true
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	return false


func _spela_scenario_1() -> void:
	print("--- Scenario: Fotografen ---")
	Spel.nollstall("res://data/scenarier/fotografen.json")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _vanta(5)
	main.call("_starta_pass")
	await _vanta(10)
	if not main.varld.kamrat_folj:
		_fel("kamraten följer inte efter passstart")
	main.call("_forcera_handelse", "1")
	var npc: Aktor = main.varld.npcer.get("fotografen")
	if npc == null or not npc.visible:
		_fel("fotografen syns inte efter forcerad händelse 1")
		return
	# Vänta tills fotografen är framme (max ~10 s speltid).
	var t := 0
	while npc.ar_i_rorelse() and t < 600:
		await get_tree().process_frame
		t += 1
	if npc.ar_i_rorelse():
		_fel("fotografen kom aldrig fram")
	else:
		_ok("fotografen framme vid " + str(npc.cell))
	main.call("_oppna_kontakt", "fotografen")
	await _vanta(3)
	var kontakt: Kontakt = main.kontakt
	if not kontakt.visible:
		_fel("kontaktläget öppnades inte")
		return
	# Debug visar spåret; en åtgärd med egen replik låter samtalet stå kvar.
	Spel.debug = true
	kontakt.visa_nod("start")
	var spar := str(kontakt.call("_spar", {"handling": "avvisa", "replik": "x"}))
	if not spar.contains("SAKNAR LAGSTÖD"):
		_fel("debugspåret för Avvisa: " + spar)
	else:
		_ok("debug visar spåret: Avvisa " + spar)
	kontakt.valj_atgard("avvisa")
	await _vanta(2)
	if not kontakt.visible or kontakt._nod_id != "start":
		_fel("Avvisa med egen replik borde lämna samtalet i samma steg")
	Spel.debug = false
	kontakt.visa_nod("start")
	if not kontakt.valj_atgard("begara_identitet"):  # Åtgärdsraden: Begär uppgifter
		_fel("åtgärden Begär uppgifter saknas i kontaktläget")
	await _vanta(2)
	kontakt.call("_valj", 1)  # "Gör som jag säger." -> vägrar
	await _vanta(2)
	if not kontakt.valj_atgard("tillfalligt_omhanderta"):
		_fel("åtgärden Omhänderta saknas i kontaktläget")
	await _vanta(2)
	kontakt.call("_stang")
	await _vanta(3)
	if not str(main.call("_lagestext")).contains("kontakt tagen"):
		_fel("lägestexten följer inte händelsen efter kontakt: " + str(main.call("_lagestext")))
	else:
		_ok("lägestext efter kontakt")
	main.call("_visa_debriefing")
	await _vanta(3)

	var logg: Array = Spel.slutlogg()
	var forvantat := {"begara_identitet": "ok", "tillfalligt_omhanderta": "warn", "foljdkrav_anmalan_polis": "bad"}
	for handling in forvantat:
		var hittad := false
		for post in logg:
			if post.get("handling", "") == handling:
				hittad = true
				if post.get("utfall", "") != forvantat[handling]:
					_fel("%s bedömdes '%s', väntat '%s'" % [handling, post.get("utfall"), forvantat[handling]])
				else:
					_ok("%s bedömd '%s'" % [handling, forvantat[handling]])
		if not hittad:
			_fel("hittade inte %s i debriefingen" % handling)
	if main.debriefing == null:
		_fel("debriefingen visades inte")
	else:
		var sokvag := Spel.spara_logg()
		if sokvag == "":
			_fel("kunde inte spara logg")
		else:
			_ok("logg sparad")
	main.queue_free()
	await _vanta(3)


func _starta_dronaren(variant: String) -> Variant:
	Spel.nollstall("res://data/scenarier/dronaren.json")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _vanta(5)
	main.call("_starta_pass")
	await _vanta(5)
	main.call("_forcera_handelse", "1:" + variant)
	await _vanta(2)
	if main.dronare == null:
		_fel("ingen drönare efter forcerad händelse (%s)" % variant)
		return main
	var t := 0
	while main.dronare.lage != "cirklar" and t < 900:
		await get_tree().process_frame
		t += 1
	if main.dronare.lage != "cirklar":
		_fel("drönaren började aldrig cirkla (läge %s)" % main.dronare.lage)
	else:
		_ok("drönaren cirklar över objektet (%s)" % variant)
	return main


func _forvanta(forvantat: Dictionary) -> void:
	var logg: Array = Spel.slutlogg()
	for handling in forvantat:
		var hittad := false
		for post in logg:
			if post.get("handling", "") == handling:
				hittad = true
				if post.get("utfall", "") != forvantat[handling]:
					_fel("%s bedömdes '%s', väntat '%s'" % [handling, post.get("utfall"), forvantat[handling]])
				else:
					_ok("%s bedömd '%s'" % [handling, forvantat[handling]])
		if not hittad:
			_fel("hittade inte %s i debriefingen" % handling)


func _spela_dronaren_med_pilot() -> void:
	print("--- Scenario: Drönaren (med pilot) ---")
	var main = await _starta_dronaren("med_pilot")
	var pilot: Aktor = main.varld.npcer.get("piloten")
	if pilot == null or not pilot.visible:
		_fel("piloten syns inte")
	main.call("_oppna_kontakt", "piloten")
	await _vanta(3)
	var kontakt: Kontakt = main.kontakt
	kontakt.call("_valj", 0)  # Be honom landa
	await _vanta(2)
	if main.dronare and main.dronare.lage == "cirklar":
		_fel("drönaren landade inte efter uppmaning")
	kontakt.call("_valj", 2)  # Notera och låt gå
	await _vanta(2)
	kontakt.call("_stang")
	await _vanta(3)
	main.call("_visa_debriefing")
	await _vanta(3)
	_forvanta({"be_landa": "ok", "dokumentera": "ok", "slutkrav_rapportera_vaktchef": "bad"})
	main.queue_free()
	await _vanta(3)


func _spela_dronaren_utan_pilot() -> void:
	print("--- Scenario: Drönaren (utan pilot) ---")
	var main = await _starta_dronaren("utan_pilot")
	var pilot: Aktor = main.varld.npcer.get("piloten")
	if pilot and pilot.visible:
		_fel("piloten syns trots variant utan pilot")
	main.call("_bekampa_dronare")
	var t := 0
	while main.dronare and main.dronare.lage != "vrak" and t < 300:
		await get_tree().process_frame
		t += 1
	if main.dronare == null or main.dronare.lage != "vrak":
		_fel("drönaren kraschade inte efter bekämpning")
	else:
		_ok("drönaren nedskjuten och kraschad")
	var byt: Dictionary = main.call("_radio_ersattningar")
	if not str(byt.get("lage", "")).contains("nedskjuten") or not str(byt.get("polis", "")).contains("bekämpats") \
			or str(byt.get("svar", "")).contains("Ingen vapeninsats"):
		_fel("radiotexterna följer inte att drönaren skjutits ner: " + str(byt))
	else:
		_ok("lägesrapport och polisbegäran säger att drönaren är nedskjuten")
	main.call("_visa_debriefing")
	await _vanta(3)
	_forvanta({"vald_mot_farkost": "warn"})
	main.queue_free()
	await _vanta(3)


func _vanta(rutor: int) -> void:
	for i in rutor:
		await get_tree().process_frame


func _filer(mapp: String, andelse: String) -> PackedStringArray:
	var ut := PackedStringArray()
	var d := DirAccess.open(mapp)
	if d == null:
		return ut
	for f in d.get_files():
		if f.ends_with(andelse):
			ut.append(mapp.path_join(f))
	for undermapp in d.get_directories():
		ut.append_array(_filer(mapp.path_join(undermapp), andelse))
	return ut


## Bygger världen med varje typ av skyddsobjekt och kontrollerar att objektet
## blockerar rutor och att inga platshållare finns kvar i texterna.
func _bygg_alla_objekttyper() -> void:
	print("--- Skyddsobjekt ---")
	for typ in ["byggnad", "lastbil", "vapenforrad", "radiomast"]:
		Spel.nollstall("res://data/scenarier/dronaren.json", typ)
		if Spel.objekttyp != typ:
			_fel("objekttyp %s valdes inte" % typ)
		if JSON.stringify(Spel.scenario).contains("{objekt"):
			_fel("platshållare kvar i texterna (%s)" % typ)
		var main = load("res://scenes/main.tscn").instantiate()
		add_child(main)
		await _vanta(3)
		var yta: Array = Spel.karta.get("objektyta", [0, 0, 0, 0])
		var blockerade := 0
		for y in range(int(yta[1]), int(yta[3]) + 1):
			for x in range(int(yta[0]), int(yta[2]) + 1):
				if not main.varld.ar_fri(Vector2i(x, y)):
					blockerade += 1
		if blockerade == 0:
			_fel("skyddsobjektet %s blockerar inga rutor" % typ)
		else:
			_ok("%s (%s) blockerar %d rutor" % [typ, Spel.scenario.get("objekt", ""), blockerade])
		main.queue_free()
		await _vanta(3)


## Stridsparet står långt bort (vid sjön) medan fotografen kommer och går:
## händelsen ska visas som missad i debriefingen.
func _spela_missad_handelse() -> void:
	print("--- Missad händelse ---")
	Spel.nollstall("res://data/scenarier/fotografen.json")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _vanta(5)
	main.call("_starta_pass")
	await _vanta(3)
	var sjo: Vector2i = main.varld.punkt("sjo_pilot")
	main.varld.kamrat_folj = false
	for a in [main.varld.spelare, main.varld.kollega]:
		a.cell = sjo
		a.stanna()
	main.call("_forcera_handelse", "1")
	var npc: Aktor = main.varld.npcer.get("fotografen")
	var t := 0
	while npc.visible and t < 6000:
		await get_tree().process_frame
		t += 1
	if npc.visible:
		_fel("fotografen gick aldrig iväg")
	else:
		_ok("fotografen gav sig av utan kontakt")
	if await _vanta_radio("Granåsvägen"):
		_ok("Norra grinden rapporterar bilen som åker")
	else:
		_fel("radioinslaget när fotografen lämnar spelades inte")
	main.call("_visa_debriefing")
	await _vanta(3)
	_forvanta({"missad_1": "bad"})
	main.queue_free()
	await _vanta(3)


## Hantverkaren vid grinden: spelar en given väg genom dialogen.
func _spela_hantverkaren(variant: String, val: Array, forvantat: Dictionary) -> void:
	print("--- Scenario: Hantverkaren (%s) ---" % variant)
	Spel.nollstall("res://data/scenarier/hantverkaren.json")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _vanta(5)
	main.call("_starta_pass")
	await _vanta(3)
	main.call("_forcera_handelse", "1:" + variant)
	var npc: Aktor = main.varld.npcer.get("hantverkaren")
	var t := 0
	while npc.ar_i_rorelse() and t < 900:
		await get_tree().process_frame
		t += 1
	if Spel.variant != variant:
		_fel("fel variant: %s" % Spel.variant)
	if not main._fordon.has("hantverkaren"):
		_fel("servicebilen ställdes inte ut")
	_ok("hantverkaren vid bommen %s" % str(npc.cell))
	main.call("_oppna_kontakt", "hantverkaren")
	await _vanta(3)
	var kontakt: Kontakt = main.kontakt
	for i in val:
		kontakt.call("_valj", int(i))
		await _vanta(2)
	kontakt.call("_stang")
	await _vanta(3)
	main.call("_visa_debriefing")
	await _vanta(3)
	_forvanta(forvantat)
	main.queue_free()
	await _vanta(3)


# ------------------------------------------------------------ Yxmannen --

## Väntar (högst max_s sekunder speltid) tills villkoret är sant.
func _vanta_tills(villkor: Callable, max_s := 60.0) -> bool:
	var t := 0.0
	while t < max_s:
		if villkor.call():
			return true
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	return bool(villkor.call())


func _starta_yxmannen(variant: String) -> Variant:
	print("--- Scenario: Yxmannen (%s) ---" % variant)
	Spel.nollstall("res://data/scenarier/yxmannen.json")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _vanta(5)
	main.call("_starta_pass")
	await _vanta(3)
	main.call("_forcera_handelse", "1:" + variant)
	await _vanta(2)
	if Spel.variant != variant:
		_fel("fel variant: %s" % Spel.variant)
	if not await _vanta_tills(func() -> bool: return "verkanseld" in main.hud.situationer()):
		_fel("situationsknapparna visades aldrig (avstånd %d)" % main.call("_avstand_angripare"))
	else:
		_ok("kamraten upptäcker yxmannen, knappar: %s (avstånd %d)" % [
			", ".join(PackedStringArray(main.hud.situationer())), main.call("_avstand_angripare")])
	return main


func _avsluta_yxmannen(main: Node, forvantat: Dictionary) -> void:
	main.call("_visa_debriefing")
	await _vanta(3)
	_forvanta(forvantat)
	main.queue_free()
	await _vanta(3)


func _spela_yxmannen_ger_upp() -> void:
	var main = await _starta_yxmannen("ger_upp")
	await _vanta_tills(func() -> bool: return main.call("_avstand_angripare") <= 12)
	main.call("_halt_order")
	if not await _vanta_tills(func() -> bool: return str(main._angripare.get("lage", "")) == "gett_upp", 10.0):
		_fel("yxmannen gav inte upp efter halt-order")
		main.queue_free()
		return
	_ok("yxmannen gav upp efter halt-order")
	if "halt" in main.hud.situationer():
		_fel("halt-knappen visas fortfarande efter given varning")
	main.call("_oppna_kontakt", "yxmannen")
	await _vanta(3)
	var kontakt: Kontakt = main.kontakt
	kontakt.call("_valj", 0)  # Grip honom (envarsgripande)
	await _vanta(2)
	kontakt.call("_valj", 0)  # Begär polis via CQ
	await _vanta(2)
	kontakt.call("_stang")
	await _vanta(3)
	if not str(main.call("_lagestext")).contains("gett upp"):
		_fel("lägestexten följer inte händelsen: " + str(main.call("_lagestext")))
	await _avsluta_yxmannen(main, {"halt_order": "ok", "envarsgripande": "ok", "anmala_polis": "ok",
		"slutkrav_rapportera_vaktchef": "bad"})


func _spela_yxmannen_skarp() -> void:
	var main = await _starta_yxmannen("skarp")
	main.call("_halt_order")
	await _vanta_tills(func() -> bool: return main.call("_avstand_angripare") <= 5)
	main.call("_varningsskott")
	if str(main._angripare.get("lage", "")) != "anfaller":
		_fel("yxmannen slutade anfalla trots variant skarp")
	await _vanta_tills(func() -> bool: return main.call("_avstand_angripare") <= 3)
	main.call("_verkanseld")
	if str(main._angripare.get("lage", "")) != "skjuten":
		_fel("yxmannen föll inte efter verkanseld")
	elif not "sjukvard" in main.hud.situationer():
		_fel("knappen Larma sjukvård visas inte efter verkanseld")
	else:
		_ok("verkanseld: mannen ligger, sjukvårdsknapp visas")
	if not str(main.call("_lagestext")).contains("verkanseld"):
		_fel("lägestexten nämner inte verkanselden: " + str(main.call("_lagestext")))
	main.call("_larma_sjukvard")
	await _avsluta_yxmannen(main, {"halt_order": "ok", "varningsskott": "ok", "verkanseld": "ok",
		"larma_sjukvard": "ok", "foljdkrav_skjutning_rapporterad": "bad"})


func _spela_yxmannen_for_tidigt() -> void:
	var main = await _starta_yxmannen("skarp")
	if main.call("_avstand_angripare") <= 6:
		_fel("yxmannen var redan nära vid upptäckt (%d)" % main.call("_avstand_angripare"))
	main.call("_verkanseld")
	await _avsluta_yxmannen(main, {"verkanseld": "bad"})


func _spela_yxmannen_nar_fram() -> void:
	var main = await _starta_yxmannen("skarp")
	if not await _vanta_tills(func() -> bool: return str(main._angripare.get("lage", "")) == "overmannad", 90.0):
		_fel("angreppet nådde aldrig fram (avstånd %d)" % main.call("_avstand_angripare"))
	await _avsluta_yxmannen(main, {"angrepp_nadde_fram": "bad"})

