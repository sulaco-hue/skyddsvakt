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
	var scenario := Datafil.las_json("res://data/scenarier/fotografen.json")
	var snack := Datafil.las_json("res://data/kamratsnack.json")
	for par in [["lagrum.json", lagrum], ["fotografen.json", scenario], ["kamratsnack.json", snack]]:
		if (par[1] as Dictionary).is_empty():
			_fel("tom eller ogiltig JSON: " + str(par[0]))
	var handlingar: Dictionary = lagrum.get("handlingar", {})
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
	_ok("data och dialogkopplingar")


func _spela_scenario_1() -> void:
	Spel.nollstall()
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
