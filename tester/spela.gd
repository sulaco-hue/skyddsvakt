extends Node
## Spelar spelet efter ett manus och tar skärmdumpar, så att spelet kan provas
## utan att någon sitter vid skärmen. Körs med grafik (t.ex. under xvfb):
##
##   godot --path . res://tester/spela.tscn -- --manus=manus.json --ut=/tmp/bilder [--kompakt]
##
## Manuset är en lista med steg, t.ex.
##   {"scenario": "fotografen.json", "objekt": "lastbil"}   startar ett scenario (briefing visas)
##   {"bild": "briefing"}                                    skärmdump
##   {"starta": true}                                        startar passet
##   {"forcera": "1"} eller {"forcera": "1:arlig"}           forcerar en händelse
##   {"vanta": 3}                                            väntar sekunder (speltid)
##   {"vanta_upptackt": true}                                väntar tills kamraten reagerat
##   {"ga": [30, 22]} / {"ga_punkt": "grind"}                går till en ruta eller kartpunkt
##   {"kontakt": "fotografen"}                               tar kontakt
##   {"valj": 0} / {"atgard": "avvisa"} / {"stang": true}    val i kontaktläget
##   {"anropa": "_halt_order"}                               anropar en funktion i main
##   {"tangent": "R"}                                        trycker en tangent
##   {"samband": 1}                                          väljer i sambandsmenyn
##   {"debriefing": true}                                    avslutar passet
##   {"titel": true} / {"scenarioval": true}                 startskärm / scenarioval
##   {"debug": true}                                         slår på debugraden
##   {"tidsfaktor": 4}                                       snabbar upp väntan

var ut := "/tmp/bilder"
var main: Node = null
var logg: Array[String] = []


func _ready() -> void:
	var manus_fil := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--manus="):
			manus_fil = a.substr(8)
		elif a.begins_with("--ut="):
			ut = a.substr(5)
	DirAccess.make_dir_recursive_absolute(ut)
	var manus: Variant = JSON.parse_string(FileAccess.get_file_as_string(manus_fil))
	if not manus is Array:
		printerr("Kunde inte läsa manus: " + manus_fil)
		get_tree().quit(1)
		return
	await _vanta(0.5)
	for steg: Dictionary in manus:
		await _utfor(steg)
	# Beslutsloggen och samband som text
	var f := FileAccess.open(ut.path_join("logg.txt"), FileAccess.WRITE)
	for rad in logg:
		f.store_line(rad)
	f.store_line("--- Beslutslogg ---")
	for post in Spel.slutlogg():
		f.store_line("%s  %s  %s  %s" % [post.get("tid", ""), post.get("utfall", ""), post.get("handling", ""), post.get("beskrivning", "")])
	f.store_line("--- Samband ---")
	for rad in Spel.samband:
		f.store_line("%s: %s" % [rad.get("fran", ""), rad.get("text", "")])
	f.close()
	get_tree().quit(0)


func _vanta(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ny_main() -> void:
	if main:
		main.queue_free()
		await get_tree().process_frame
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _vanta(0.5)


func _utfor(steg: Dictionary) -> void:
	logg.append(JSON.stringify(steg))
	if steg.has("tidsfaktor"):
		Engine.time_scale = float(steg["tidsfaktor"])
	if steg.has("titel"):
		Spel.nollstall()
		Spel.titel_visad = false
		await _ny_main()
	if steg.has("scenarioval"):
		Spel.nollstall()
		Spel.titel_visad = true
		await _ny_main()
	if steg.has("scenario"):
		Spel.titel_visad = true
		Spel.nollstall("res://data/scenarier/" + str(steg["scenario"]), str(steg.get("objekt", "")))
		await _ny_main()
	if steg.has("starta"):
		main.call("_starta_pass")
		await _vanta(1.0)
	if steg.has("debug"):
		main.hud._debug.visible = bool(steg["debug"])
	if steg.has("forcera"):
		main.call("_forcera_handelse", str(steg["forcera"]))
		await _vanta(0.5)
	if steg.has("vanta"):
		await _vanta(float(steg["vanta"]))
	if steg.has("vanta_upptackt"):
		for i in 600:
			if main._larm_har_skett:
				break
			await _vanta(0.1)
		await _vanta(1.0)
	if steg.has("ga") or steg.has("ga_punkt"):
		var mal: Vector2i = main.varld.punkt(str(steg["ga_punkt"])) if steg.has("ga_punkt") else Vector2i(steg["ga"][0], steg["ga"][1])
		main.varld.ga_till(mal)
		for i in 300:
			if main.varld.spelare._vag.is_empty():
				break
			await _vanta(0.1)
	if steg.has("kontakt"):
		main.call("_oppna_kontakt", str(steg["kontakt"]))
		await _vanta(1.0)
	if steg.has("valj"):
		main.kontakt.call("_valj", int(steg["valj"]))
		await _vanta(1.0)
	if steg.has("atgard"):
		if not main.kontakt.valj_atgard(str(steg["atgard"])):
			logg.append("  (åtgärden fanns inte)")
		await _vanta(1.0)
	if steg.has("stang"):
		main.kontakt.call("_stang")
		await _vanta(1.0)
	if steg.has("anropa"):
		main.call(str(steg["anropa"]))
		await _vanta(0.5)
	if steg.has("tangent"):
		var e := InputEventKey.new()
		e.keycode = OS.find_keycode_from_string(str(steg["tangent"]))
		e.pressed = true
		Input.parse_input_event(e)
		await _vanta(0.3)
	if steg.has("samband"):
		main.hud.call("_pa_sambandsval", Spel.scenario.get("sambandsval", [])[int(steg["samband"])])
		await _vanta(0.5)
	if steg.has("debriefing"):
		main.call("_visa_debriefing")
		await _vanta(1.0)
	if steg.has("bild"):
		await RenderingServer.frame_post_draw
		var bild := get_viewport().get_texture().get_image()
		var fil := ut.path_join(str(steg["bild"]) + ".png")
		bild.save_png(fil)
		logg.append("  bild: " + fil)
