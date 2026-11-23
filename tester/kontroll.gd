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
	print("=== Skyddsvakt: automatisk kontroll ===")
	_kontrollera_skript()
	_kontrollera_data()
	await _spela_scenario_1()
	await _spela_dronaren_med_pilot()
	await _spela_dronaren_utan_pilot()
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
	for par in [["lagrum.json", lagrum], ["kamratsnack.json", snack], ["granasen.json", karta]]:
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
	for val in scenario.get("sambandsval", []):
		var h := str(val.get("handling", ""))
		if h != "" and not handlingar.has(h):
			_fel("sambandsval pekar på okänd handling '%s'" % h)
	_ok("data och dialogkopplingar: " + sokvag.get_file())


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
	kontakt.call("_valj", 2)  # Begär namn, födelsetid och hemvist
	await _vanta(2)
	kontakt.call("_valj", 1)  # "Gör som jag säger." -> vägrar
	await _vanta(2)
	kontakt.call("_valj", 1)  # Omhänderta tillfälligt
	await _vanta(2)
	kontakt.call("_stang")
	await _vanta(3)
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
