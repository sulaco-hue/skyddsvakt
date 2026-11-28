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
	await _spela_dronaren_dold_pilot(true)
	await _spela_dronaren_dold_pilot(false)
	await _spela_missad_handelse()
	# Steg: tal = svarsalternativ, text = åtgärd i åtgärdsraden.
	await _spela_hantverkaren("arlig", ["begara_identitet", 0, 0, 0, 0],
		{"begara_identitet": "ok", "neka_tilltrade": "ok", "dokumentera": "ok"})
	await _spela_hantverkaren("arlig", ["avvisa"], {"avvisa": "bad"})
	await _spela_hantverkaren("arlig", [2], {"slappa_in": "bad"})
	await _spela_hantverkaren("oriktig", ["begara_identitet", "be_om_legitimation", "avvisa"],
		{"be_om_legitimation": "ok", "avvisa": "ok"})
	await _spela_hantverkaren("oriktig", ["undersoka_fordon", "avvisa"], {"avvisa": "ok"})
	await _spela_hantverkaren("rekognosering", ["undersoka_fordon", "beslag", "gripa", "skyddsvisitera"],
		{"undersoka_fordon": "ok", "beslag": "ok", "gripa": "ok", "skyddsvisitera": "ok"})
	await _spela_hantverkaren("rekognosering", ["gripa"], {"gripa": "bad"})
	await _spela_yxmannen_ger_upp()
	await _spela_yxmannen_skarp()
	await _spela_slagsmal("stannar")
	await _spela_slagsmal("lamnar")
	await _spela_slagsmal("smygare")
	await _spela_slagsmal("smygare_flykt")
	await _spela_demonstration("dialog")
	await _spela_demonstration("vald")
	await _spela_lamna_posten()
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
	kontakt.call("_valj", 1)  # Notera och låt gå
	await _vanta(2)
	kontakt.call("_stang")
	await _vanta(3)
	main.call("_visa_debriefing")
	await _vanta(3)
	_forvanta({"be_landa": "ok", "dokumentera": "ok", "slutkrav_rapportera_vaktchef": "bad"})
	main.queue_free()
	await _vanta(3)


## Mannen i skogskanten (invid): landa, beslag, uppgifter, avvisning – eller så går han själv.
func _spela_dronaren_dold_pilot(kontakt_tas: bool) -> void:
	print("--- Scenario: Drönaren (dold pilot, %s) ---" % ("kontakt" if kontakt_tas else "ingen kontakt"))
	var main = await _starta_dronaren("dold_pilot")
	var pilot: Aktor = main.varld.npcer.get("dronpiloten")
	if pilot == null or not pilot.visible:
		_fel("piloten i skogskanten syns inte")
		main.queue_free()
		return
	if main.varld.npcer.get("piloten").visible:
		_fel("Mats syns trots variant dold_pilot")
	if not kontakt_tas:
		if not await _vanta_tills(func() -> bool: return bool(Spel.fakta.get("pilot_gick", false)), 120.0):
			_fel("piloten gick aldrig därifrån")
		else:
			_ok("piloten tog ner drönaren och gick; lägesrapport: " + str(main.call("_lagestext")))
		main.queue_free()
		await _vanta(3)
		return
	main.call("_oppna_kontakt", "dronpiloten")
	await _vanta(3)
	var kontakt: Kontakt = main.kontakt
	kontakt.call("_valj", 0)  # Be honom landa
	await _vanta(2)
	for atg in ["begara_identitet", "be_om_legitimation", "beslag"]:
		if not kontakt.valj_atgard(atg):
			_fel("åtgärden %s saknas (steg %s)" % [atg, kontakt._nod_id])
		await _vanta(2)
	if not kontakt.valj_atgard("avvisa"):
		_fel("åtgärden avvisa saknas (steg %s)" % kontakt._nod_id)
	await _vanta(2)
	kontakt.call("_stang")
	await _vanta(3)
	_ok("lägesrapport: " + str(main.call("_lagestext")))
	main.call("_visa_debriefing")
	await _vanta(3)
	_forvanta({"be_landa": "ok", "begara_identitet": "ok", "be_om_legitimation": "ok", "beslag": "ok", "avvisa": "ok"})
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
	if await _vanta_radio("skogsstigen"):
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
	for steg in val:
		if steg is String:
			if not kontakt.valj_atgard(str(steg)):
				_fel("åtgärden %s fanns inte (steg %s)" % [steg, kontakt._nod_id])
		else:
			kontakt.call("_valj", int(steg))
		await _vanta(2)
	kontakt.call("_stang")
	await _vanta(3)
	main.call("_visa_debriefing")
	await _vanta(3)
	_forvanta(forvantat)
	main.queue_free()
	await _vanta(3)


## Gäller alla scenarier: går båda långt från objektet blir det en bedömning.
func _spela_lamna_posten() -> void:
	print("--- Lämna posten (fotografen) ---")
	Spel.nollstall("res://data/scenarier/fotografen.json")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _vanta(5)
	main.call("_starta_pass")
	await _vanta(3)
	main.varld.ga_till(main.varld.punkt("yx_syd"))
	if not await _vanta_tills(func() -> bool: return Spel.logg.any(func(p: Dictionary) -> bool:
			return p.get("handling", "") == "lamnade_posten"), 120.0):
		_fel("att stridsparet lämnade objektet registrerades inte")
	main.call("_visa_debriefing")
	await _vanta(3)
	_forvanta({"lamnade_posten": "warn"})
	main.queue_free()
	await _vanta(3)


# ------------------------------------------------------------ Slagsmålet --

## stannar: vid posten, halt-order och varningsskott mot slagsmålet (knytnävar: inget svårare våld).
## lamnar: båda går till slagsmålet (lämnar objektet).
## smygare: smygaren vid skylten, halt och verkanseld mot honom.
func _spela_slagsmal(fall: String) -> void:
	print("--- Scenario: Slagsmålet (%s) ---" % fall)
	Spel.nollstall("res://data/scenarier/slagsmalet.json")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _vanta(5)
	main.call("_starta_pass")
	await _vanta(3)
	main.call("_forcera_handelse", "1")
	if not await _vanta_tills(func() -> bool: return main._slagsmal != null and main._slagsmal.upptackt, 30.0):
		_fel("slagsmålet upptäcktes aldrig")
		main.queue_free()
		return
	_ok("slagsmålet upptäckt, knappar: %s" % ", ".join(PackedStringArray(main.hud.situationer())))
	var sm: Slagsmal = main._slagsmal
	match fall:
		"stannar":
			main.call("_pa_situation", "halt")
			await _vanta(0.5)
			main.call("_pa_situation", "varningsskott")
			if not await _vanta_tills(func() -> bool: return sm.brakare_lage in ["flyr", "borta", "stannat"], 10.0):
				_fel("bråkaren varken flydde eller stannade efter halt och varningsskott")
			else:
				_ok("bråkaren efter halt + varningsskott: %s (offret: %s)" % [sm.brakare_lage, sm.offret_lage])
			var lt := str(main.call("_lagestext"))
			if lt.contains("skylt") or not (lt.contains("slagsmål") or lt.contains("slåss")):
				_fel("lägesrapporten följer inte läget: " + lt)
			else:
				_ok("lägesrapport: " + lt)
			await _avsluta_yxmannen(main, {"halt_order": "ok", "varningsskott": "bad"})
		"lamnar":
			main.varld.ga_till(main.varld.punkt("slagsmal_mal") + Vector2i(-1, 0))
			if await _vanta_tills(func() -> bool: return sm.brakare_lage == "slass", 40.0):
				var d: int = main.varld.avstand(sm._brakare().cell, sm._offret().cell)
				if d > 1:
					_fel("slagskämparna står %d rutor isär när de slåss" % d)
				else:
					_ok("slagskämparna står intill varandra nere vid vägen")
			if not await _vanta_tills(func() -> bool: return Spel.logg.any(func(p: Dictionary) -> bool:
					return p.get("handling", "") == "lamnade_posten"), 40.0):
				_fel("att båda lämnade posten registrerades inte")
			await _vanta_tills(func() -> bool: return sm.offret_lage == "nere" and sm.brakare_lage in ["flyr", "borta"], 40.0)
			main.call("_pa_situation", "forsta_hjalpen")
			await _vanta(2)
			Spel.satt_fakta({"skylt_stulen": true})
			main.call("_visa_debriefing")
			await _vanta(1)
			var lp: Array = Spel.logg.filter(func(p: Dictionary) -> bool: return p.get("handling", "") == "lamnade_posten")
			if lp.is_empty() or not str(lp[0].get("kommentar", "")).contains("skylten"):
				_fel("debriefingen om lämnad post nämner inte den stulna skylten")
			await _avsluta_yxmannen(main, {"lamnade_posten": "warn", "forsta_hjalpen": "ok"})
		"smygare":
			main.call("_forcera_handelse", "2:skylt")
			if not await _vanta_tills(func() -> bool: return sm.smyg_lage == "jobbar", 40.0):
				_fel("smygaren kom aldrig fram till skylten (läge %s)" % sm.smyg_lage)
			sm.smygare_upptackt()
			if sm._aktuellt_mal() != "smygare":
				_fel("närmaste mål borde vara smygaren, var '%s'" % sm._aktuellt_mal())
			main.call("_pa_situation", "verkanseld")
			await _vanta(2)
			if bool(Spel.fakta.get("skylt_stulen", false)) and sm.smyg_lage == "skjuten":
				_fel("skylten stals trots att smygaren sköts")
			var lt2 := str(main.call("_lagestext"))
			var sk := str(main.call("_radio_ersattningar").get("skadade", ""))
			_ok("lägesrapport: %s · ambulans: %s" % [lt2, sk])
			if sm.smyg_lage == "skjuten" and not (lt2.contains("staketet") and sk.contains("skottskada")):
				_fel("rapporterna nämner inte den skjutne vid staketet")
			await _avsluta_yxmannen(main, {"verkanseld": "bad"})
		"smygare_flykt":
			# Han tar skylten och springer; varningsskott i flykten får honom alltid att tappa den.
			main.call("_forcera_handelse", "2:skylt")
			if not await _vanta_tills(func() -> bool: return sm.smyg_lage == "flyr", 60.0):
				_fel("smygaren flydde aldrig med skylten (läge %s)" % sm.smyg_lage)
			sm.smygare_upptackt()
			if sm._aktuellt_mal() != "smygare":
				_fel("närmaste mål borde vara smygaren, var '%s'" % sm._aktuellt_mal())
			main.call("_pa_situation", "varningsskott")
			await _vanta_tills(func() -> bool: return bool(Spel.fakta.get("skylt_tappad", false)), 5.0)
			if not bool(Spel.fakta.get("skylt_tappad", false)):
				_fel("smygaren tappade inte skylten efter varningsskott i flykten (läge %s, bär skylt %s, halt %s, stulen %s)" % [
					sm.smyg_lage, main.varld.npcer["smygaren"].has_node("BurenSkylt"), str(sm._halt_givet), Spel.fakta.get("skylt_stulen")])
			else:
				_ok("smygaren tappade skylten; lägesrapport: " + str(main.call("_lagestext")))
			await _avsluta_yxmannen(main, {"varningsskott": "bad"})


# ------------------------------------------------------- Demonstrationen --

## dialog: grinden hålls, talespersonen går med på att sitta utanför, polis begärs.
## vald: halt, handgemäng mot en som trycker på, varningsskott; den som kommit in bärs ut.
func _spela_demonstration(fall: String) -> void:
	print("--- Scenario: Demokratiska rättigheter? (%s) ---" % fall)
	Spel.nollstall("res://data/scenarier/demonstrationen.json")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _vanta(5)
	main.call("_starta_pass")
	await _vanta(3)
	main.varld.ga_till(main.varld.punkt("grind"))
	main.call("_forcera_handelse", "1")
	if not await _vanta_tills(func() -> bool: return main._demo != null and main._demo.upptackt, 60.0):
		_fel("demonstrationen upptäcktes aldrig")
		main.queue_free()
		return
	var dm: Demonstration = main._demo
	_ok("demonstrationen upptäckt, knappar: %s" % ", ".join(PackedStringArray(main.hud.situationer())))
	match fall:
		"dialog":
			# Rapport till CQ och förstärkning direkt när gruppen syns.
			main.hud.radio_anropa()
			main.hud.radio_valj("lagesrapport")
			main.hud.radio_valj("forstarkning")
			main.hud.radio_avsluta()
			await _vanta_tills(func() -> bool: return dm.fas != "kommer", 60.0)
			# Klick på vilken demonstrant som helst: talespersonen kliver fram.
			main.call("_pa_npc_klickad", "demo_5")
			await _vanta_tills(func() -> bool: return main.kontakt.visible, 30.0)
			if not main.kontakt.visible or str(main.kontakt.get_meta("npc", "")) != "talespersonen":
				_fel("klick på en demonstrant öppnade inte samtalet med talespersonen")
				main.call("_oppna_kontakt", "talespersonen")
			await _vanta(3)
			var kontakt: Kontakt = main.kontakt
			kontakt.call("_valj", 0)
			await _vanta(2)
			kontakt.call("_valj", 0)
			await _vanta(2)
			kontakt.call("_stang")
			await _vanta(3)
			if not bool(Spel.fakta.get("demo_sitter_utanfor", false)):
				_fel("gruppen gick inte med på att sitta utanför")
			main.call("_pa_npc_klickad", "demo_2")
			await _vanta(3)
			if main.kontakt.visible:
				_fel("dialogen öppnades igen fast samtalet var avslutat")
				main.kontakt.call("_stang")
			else:
				_ok("avslutat samtal: personen lyssnar inte längre")
			# De nöjer sig inte länge: någon reser sig och trycker på igen.
			if not await _vanta_tills(func() -> bool: return dm.demonstranter.any(func(d: Dictionary) -> bool:
					return bool(d.get("otalig", false))), 120.0):
				_fel("ingen demonstrant tröttnade på att sitta utanför")
			else:
				_ok("en demonstrant reste sig och tryckte på igen")
			await _vanta(30)
			main.hud.radio_anropa()
			main.hud.radio_valj("polis")
			main.hud.radio_avsluta()
			if not await _vanta_tills(func() -> bool: return bool(Spel.fakta.get("forstarkning_pa_plats", false)), 90.0):
				_fel("QRF:en kom aldrig fram till grinden")
			else:
				_ok("QRF:en på plats bakom grinden")
			if not await _vanta_tills(func() -> bool: return dm._avslutad, 200.0):
				var lagen: Array = dm.demonstranter.map(func(d: Dictionary) -> String: return str(d["lage"]))
				_fel("demonstrationen tog aldrig slut efter polis (fas %s, lägen %s)" % [dm.fas, str(lagen)])
			else:
				_ok("polisen kom, demonstranterna gick; lägesrapport: " + str(main.call("_lagestext")))
			await _avsluta_yxmannen(main, {"neka_tilltrade": "ok", "anmala_polis": "ok", "rapportera_vaktchef": "ok",
				"begar_forstarkning": "ok"})
			if Spel.slutlogg().any(func(p: Dictionary) -> bool: return str(p.get("handling", "")) in ["sen_rapport", "ingen_forstarkning", "sen_forstarkning"]):
				_fel("tidig rapport och förstärkning fick ändå kritik: rapport %.0f s, förstärkning %.0f s, bråk %.0f s efter upptäckt" % [
					dm.rapport_s - dm.upptackt_s, dm.forstarkning_s - dm.upptackt_s, dm.brak_s - dm.upptackt_s])
		"vald":
			main.call("_pa_situation", "halt")
			if not await _vanta_tills(func() -> bool: return not dm._tryckande().is_empty(), 90.0):
				_fel("ingen demonstrant tryckte på i grinden (spelaren %s, kamraten %s)" % [main.varld.spelare.cell, main.varld.kollega.cell])
			else:
				_ok("demonstranter trycker på mot stridsparet i grinden")
				# Handgemäng mot den som trycker – han står intill.
				var d: Dictionary = dm._tryckande()[0]
				main.varld.spelare.stanna()
				if main.varld.avstand(main.varld.spelare.cell, (d["n"] as Aktor).cell) <= 2:
					main.call("_pa_situation", "handgemang")
			await _vanta(2)
			main.call("_pa_situation", "varningsskott")
			# Någon tar sig in (vi kliver ur grinden) och bärs ut.
			main.varld.ga_till(main.varld.punkt("objekt_mitt") + Vector2i(2, 3))
			if not await _vanta_tills(func() -> bool: return not dm._inne().is_empty(), 90.0):
				_fel("ingen demonstrant kom in trots öppen grind")
			else:
				main.call("_pa_situation", "avlagsna")
				if not await _vanta_tills(func() -> bool: return Spel.handling_utford("avlagsna") and dm._bar_ut.is_empty(), 60.0):
					_fel("demonstranten bars aldrig ut")
				else:
					_ok("en demonstrant bars ut")
			var forv := {"halt_order": "ok", "varningsskott": "bad", "avlagsna": "ok", "ingen_forstarkning": "bad"}
			if Spel.handling_utford("handgemang"):
				forv["handgemang"] = "ok"
			await _avsluta_yxmannen(main, forv)


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
	if not await _vanta_tills(func() -> bool: return "verkanseld" in main.hud.situationer(), 150.0):
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
	await _vanta_tills(func() -> bool: return main.call("_avstand_angripare") <= 12, 150.0)
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
	await _vanta_tills(func() -> bool: return main.call("_avstand_angripare") <= 5, 150.0)
	main.call("_varningsskott")
	if str(main._angripare.get("lage", "")) != "anfaller":
		_fel("yxmannen slutade anfalla trots variant skarp")
	await _vanta_tills(func() -> bool: return main.call("_avstand_angripare") <= 3, 150.0)
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
	if not await _vanta_tills(func() -> bool: return "verkanseld" in main.hud.situationer(), 150.0):
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

