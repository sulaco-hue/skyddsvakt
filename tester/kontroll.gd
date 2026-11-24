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
	Datafil.anvand_redigerat = false
	_kontrollera_skript()
	_kontrollera_data()
	await _kontrollera_redigeraren()
	await _spela_scenario_1()
	await _spela_dronaren_med_pilot()
	await _spela_dronaren_utan_pilot()
	await _spela_missad_handelse()
	await _spela_hantverkaren("oriktig", [0, 1], {"begara_identitet": "ok", "avvisa": "ok"})
	await _spela_hantverkaren("arlig", [0, 0, 0], {"begara_identitet": "ok", "undersoka_fordon": "ok"})
	await _spela_yxmannen_ger_upp()
	await _spela_yxmannen_skarp()
	await _spela_yxmannen_for_tidigt()
	await _spela_yxmannen_nar_fram()
	await _spela_zombies(true)
	await _spela_zombies(false)
	await _spela_zombies_dodsfall()
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


## Textredigeraren: filerna ska kunna sparas tillbaka exakt som de ser ut i repot
## (annars blir det onödiga ändringar när man klistrar in på GitHub), och en
## redigering på enheten ska användas när spelet läser filen.
func _kontrollera_redigeraren() -> void:
	print("--- Textredigeraren ---")
	var filer := ["res://data/kamratsnack.json", "res://data/radiobrus.json", "res://data/samband.json",
		"res://data/lagrum.json", "res://data/lagstodskort.json"]
	for f in DirAccess.get_files_at("res://data/scenarier"):
		if f.ends_with(".json"):
			filer.append("res://data/scenarier/" + f)
	var olika: Array = []
	for f: String in filer:
		var t := Datafil.las_text(f, true)
		if Datafil.till_text(JSON.parse_string(t)) != t:
			olika.append(f.get_file())
	if olika.is_empty():
		_ok("alla %d datafiler sparas tillbaka tecken för tecken lika" % filer.size())
	else:
		_fel("datafiler som inte sparas tillbaka likadant (kör om formateringen): " + ", ".join(PackedStringArray(olika)))
	# Redigering på enheten används, och kan återställas.
	var prov := "res://data/samband.json"
	var fanns := Datafil.har_redigering(prov)
	var gammal := Datafil.las_text(prov) if fanns else ""
	Datafil.anvand_redigerat = true
	var d := Datafil.las_json(prov, true)
	d["kommentar"] = "PROV"
	Datafil.spara_redigering(prov, Datafil.till_text(d))
	if str(Datafil.las_json(prov).get("kommentar", "")) != "PROV":
		_fel("redigeringen används inte när filen läses")
	else:
		_ok("redigering på enheten används")
	Datafil.ta_bort_redigering(prov)
	if Datafil.har_redigering(prov) or str(Datafil.las_json(prov).get("kommentar", "")) == "PROV":
		_fel("återställning till originalet fungerar inte")
	if fanns:
		Datafil.spara_redigering(prov, gammal)
	Datafil.anvand_redigerat = false
	# Redigeraren kan öppna alla filer och bygga formuläret utan fel.
	var red := Redigerare.new()
	add_child(red)
	red.bygg(filer[0])
	for f: String in filer:
		if f.get_file() == "index.json":
			continue
		red.call("_oppna", f)
		await get_tree().process_frame
	red.call("_oppna", "res://data/scenarier/fotografen.json")
	await get_tree().process_frame
	red.call("_hoppa", "visar")
	await get_tree().process_frame
	_ok("redigeraren öppnade alla filer")
	red.queue_free()
	await get_tree().process_frame


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
	for val in Datafil.las_json("res://data/samband.json").get("val", []):
		var h := str(val.get("handling", ""))
		if h != "" and not handlingar.has(h):
			_fel("samband.json pekar på okänd handling '%s'" % h)
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
	# Han står invid och har överträtt avbildningsförbudet: avvisning har stöd i 12 §.
	if not spar.contains("LAGSTÖD") or spar.contains("SAKNAR"):
		_fel("debugspåret för Avvisa: " + spar)
	else:
		_ok("debug visar spåret: Avvisa " + spar)
	# Skyddsvisitation utan frihetsberövande saknar lagstöd; efter gripande har den stöd.
	var sv := str(kontakt.call("_spar", {"handling": "skyddsvisitera", "replik": "x"}))
	Spel.satt_fakta({"gripande_genomfort": true})
	var sv2 := str(kontakt.call("_spar", {"handling": "skyddsvisitera", "replik": "x"}))
	Spel.satt_fakta({"gripande_genomfort": false})
	Spel.satt_fakta({"avlagsnande_genomfort": true})
	var sv3 := str(kontakt.call("_spar", {"handling": "skyddsvisitera", "replik": "x"}))
	Spel.satt_fakta({"avlagsnande_genomfort": false})
	if sv3.contains("SAKNAR"):
		_fel("skyddsvisitation vid avlägsnande borde ha lagstöd (PL 29 § 2 st.): " + sv3)
	if not sv.contains("SAKNAR") or sv2.contains("SAKNAR") or not sv2.contains("LAGSTÖD"):
		_fel("skyddsvisitation bedöms fel: före gripande %s, efter %s" % [sv, sv2])
	else:
		_ok("skyddsvisitation: %s utan frihetsberövande, %s efter gripande" % [sv, sv2])
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
	if not kontakt.valj_atgard("envarsgripande"):
		_fel("åtgärden Envarsgripande saknas hos yxmannen")
	await _vanta(2)
	kontakt.call("_stang")
	await _vanta(3)
	# Polis begärs via uppropet till CQ.
	main.hud.radio_anropa()
	main.hud.radio_valj("polis")
	main.hud.radio_avsluta()
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
	elif not "forsta_hjalpen" in main.hud.situationer():
		_fel("knappen Första hjälpen visas inte efter verkanseld")
	else:
		_ok("verkanseld: mannen ligger, knappen Första hjälpen visas")
	if not str(main.call("_lagestext")).contains("verkanseld"):
		_fel("lägestexten nämner inte verkanselden: " + str(main.call("_lagestext")))
	# Sjukvård begärs via uppropet till CQ.
	main.hud.radio_anropa()
	main.hud.radio_valj("sjukvard")
	main.hud.radio_avsluta()
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
	# Nedbrottad och klagar på armen: ambulans är rimligt.
	main.call("_pa_hud_handling", "larma_sjukvard", "Begär sjukvård (samband med CQ)")
	await _avsluta_yxmannen(main, {"angrepp_nadde_fram": "bad", "larma_sjukvard": "ok"})


# ------------------------------------------------------------- Zombies --

## skjuter = true: halt, varningsskott och verkanseld mot varje zombie som
## kommer inom 5 rutor. false: inget görs – de når fram och knuffas omkull.
func _spela_zombies(skjuter: bool) -> void:
	print("--- Scenario: Zombieapokalypsen (%s) ---" % ("skjuter" if skjuter else "gör inget"))
	Spel.nollstall("res://data/scenarier/zombies.json")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _vanta(5)
	main.call("_starta_pass")
	await _vanta(3)
	main.call("_forcera_handelse", "1")
	if not await _vanta_tills(func() -> bool: return "verkanseld" in main.hud.situationer()):
		_fel("situationsknapparna visades aldrig i zombiescenariot")
		main.queue_free()
		return
	_ok("zombierna upptäckta, knappar: " + ", ".join(PackedStringArray(main.hud.situationer())))
	if skjuter:
		main.call("_halt_order")
		main._horde["patroner"] = 2  # så att omladdningen provas tidigt
	var varnat := false
	var klart := false
	var t := 0.0
	var slagen := ""
	while t < 240.0:
		if bool(Spel.fakta.get("horde_nere", false)):
			klart = true
			break
		if (main._horde["dod"] as Dictionary).has("spelare"):
			break
		if not skjuter:
			# Den som knuffats omkull ska resa sig igen.
			for id: String in main._horde["zombies"]:
				if str(main._horde["zombies"][id]["lage"]) == "slagen" and slagen == "":
					slagen = id
			if slagen != "" and str(main._horde["zombies"][slagen]["lage"]) == "gar":
				_ok("%s knuffades omkull och reste sig igen" % slagen)
				klart = true
				break
		var narmast := str(main._horde.get("narmast", ""))
		var avst: int = main.varld.avstand(main.varld.spelare.cell, main.varld.npcer[narmast].cell) if narmast != "" else 999
		if skjuter and not varnat and avst <= 6:
			main.call("_varningsskott")
			varnat = true
		elif skjuter and avst <= 6:
			main.call("_verkanseld")
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	if not klart:
		_fel("zombiescenariot blev aldrig klart (patroner %s, laddar om %s, lägen %s, träffar %s)" % [main._horde.get("patroner"), main._horde.get("laddar_om"),
			str((main._horde["zombies"] as Dictionary).values().map(func(z: Dictionary) -> String: return str(z["lage"]))), str(main._horde["traffar"]) + " skott %s träffar %s omladdn %s t %.1f" % [main._horde.get("skott"), main._horde.get("zträffar"), main._horde.get("omladdningar"), t]])
	elif skjuter:
		_ok("alla tolv nere (%d omladdningar)" % int(main._horde.get("omladdningar", 0)))
		if int(main._horde.get("omladdningar", 0)) < 1:
			_fel("magasinet tog aldrig slut – omladdningen provades inte")
	main.call("_visa_debriefing")
	await _vanta(3)
	if skjuter:
		if not "forsta_hjalpen" in main.hud.situationer():
			_fel("knappen Första hjälpen saknas när zombierna ligger")
		else:
			main.call("_forsta_hjalpen")
			main.call("_forsta_hjalpen")
			_ok("första hjälpen erbjuds (och avböjs)")
	_forvanta({"verkanseld": "ok", "halt_order": "ok", "varningsskott": "ok", "forsta_hjalpen": "ok"} if skjuter else {"angrepp_nadde_fram": "bad"})
	main.queue_free()
	await _vanta(3)


## Tre angrepp på kamraten: han dör (kritik). Sedan låter vi dem ta oss: GAME OVER.
func _spela_zombies_dodsfall() -> void:
	print("--- Scenario: Zombieapokalypsen (dödsfall) ---")
	Spel.nollstall("res://data/scenarier/zombies.json")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _vanta(5)
	main.call("_starta_pass")
	await _vanta(3)
	main.call("_forcera_handelse", "1")
	await _vanta_tills(func() -> bool: return (main._horde["zombies"] as Dictionary).size() >= 2)
	var id: String = (main._horde["zombies"] as Dictionary).keys()[0]
	for i in 3:
		main._horde["zombies"][id]["lage"] = "gar"
		main.call("_horde_nadde_fram", id, "kamrat")
	if not bool(Spel.fakta.get("kamrat_dod", false)):
		_fel("kamraten dog inte efter tredje angreppet")
	else:
		_ok("kamraten uppäten efter tredje angreppet")
	if not await _vanta_tills(func() -> bool: return main.debriefing != null, 240.0):
		_fel("spelet gick aldrig till debriefing efter att vi blev uppätna")
	else:
		_ok("GAME OVER: direkt till debriefingen")
	await _vanta(2)
	_forvanta({"kamrat_dod": "bad", "spelaren_dod": "bad"})
	main.queue_free()
	await _vanta(3)

