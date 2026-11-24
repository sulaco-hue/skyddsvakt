extends Node
## Autoload "Spel": håller scenario, fakta, speltid och beslutslogg.

signal logg_ny(post: Dictionary)
signal samband_ny(rad: Dictionary)

const LAGRUM_SOKVAG := "res://data/lagrum.json"
const SCENARIO_INDEX := "res://data/scenarier/index.json"

var regelmotor := Regelmotor.new()
var scenario: Dictionary = {}
var scenario_sokvag := ""
## Kartan (från scenariots "karta": en sökväg till en kartfil eller kartan direkt).
var karta: Dictionary = {}
var variant := ""
## Vilket skyddsobjekt som står innanför staketet (slumpas vid varje genomförande).
var objekttyp := ""
## Startskärmen visas bara en gång per session.
var titel_visad := false
var _bedomning_override: Dictionary = {}
## Händelser som stridsparet aldrig upptäckte (läggs till vid debriefing).
var missade: Array = []
var fakta: Dictionary = {}
var logg: Array = []
var samband: Array = []
var klocka_s := 0.0
var klocka_igang := false


## Versionsnummer: data/version.json skrivs av bygget (antal commits). Lokalt "dev".
var version := "dev"


func _ready() -> void:
	regelmotor.ladda(LAGRUM_SOKVAG)
	var v := Datafil.las_json("res://data/version.json") if FileAccess.file_exists("res://data/version.json") else {}
	if v.has("version"):
		version = "v%d" % int(v["version"])
	_visa_version()
	# Pekskärm (t.ex. iPhone/iPad i Safari): mindre basupplösning = större text och knappar.
	# "-- --kompakt" på kommandoraden tvingar mobilläget (för skärmdumpar).
	if DisplayServer.is_touchscreen_available() or "--kompakt" in OS.get_cmdline_user_args():
		UiKit.kompakt = true
		get_tree().root.content_scale_size = Vector2i(800, 450)


## Versionsnumret i nedre högra hörnet, ovanpå allt.
func _visa_version() -> void:
	var lager := CanvasLayer.new()
	lager.layer = 100
	add_child(lager)
	var l := Label.new()
	l.text = version
	l.add_theme_font_override("font", load("res://assets/fonts/VT323-Regular.ttf"))
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85, 0.55))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_right = -6
	l.offset_bottom = -2
	lager.add_child(l)


## Alla scenarier i data/scenarier/index.json: [{sokvag, namn, ingress}]
func scenarier() -> Array:
	var ut: Array = []
	var index := Datafil.las_json(SCENARIO_INDEX)
	for fil in index.get("scenarier", []):
		var sokvag := "res://data/scenarier/" + str(fil)
		var sc := Datafil.las_json(sokvag)
		if not sc.is_empty():
			ut.append({"sokvag": sokvag, "namn": sc.get("namn", fil), "ingress": sc.get("ingress", "")})
	return ut


## Läser in scenariot på nytt (samma som förut om sokvag är tom). Tom sokvag och
## inget valt scenario ger ett tomt scenario (scenariovalet visas då).
func nollstall(sokvag: String = "", tvinga_objekttyp: String = "") -> void:
	if sokvag != "":
		scenario_sokvag = sokvag
	regelmotor.ladda(LAGRUM_SOKVAG)
	scenario = Datafil.las_json(scenario_sokvag) if scenario_sokvag != "" else {}
	var k: Variant = scenario.get("karta", {})
	karta = Datafil.las_json(str(k)) if k is String else (k if k is Dictionary else {})
	_valj_objekttyp(tvinga_objekttyp)
	variant = ""
	missade = []
	var bed: Dictionary = scenario.get("bedomning", {})
	_bedomning_override = bed.duplicate(true)
	var start_fakta: Dictionary = scenario.get("fakta", {})
	fakta = start_fakta.duplicate(true)
	logg = []
	var start_samband: Array = scenario.get("samband", [])
	samband = start_samband.duplicate(true)
	klocka_s = Datafil.tid_till_s(str(scenario.get("starttid", "18:00")))
	klocka_igang = false


func _process(delta: float) -> void:
	if klocka_igang:
		klocka_s += delta * float(scenario.get("tidsfaktor", 1))


func klockstrang() -> String:
	return Datafil.s_till_tid(klocka_s)


## Sant när debugraden visas (kontaktläget visar då vart valen leder).
var debug := false


## Bedömer en handling utan att logga den (debug: "vilket spår är vi på").
## extra_fakta läggs ovanpå nuvarande fakta, som när ett val sätter fakta.
func forhandsbedom(handling_id: String, extra_fakta: Dictionary = {}) -> Dictionary:
	var f := fakta.duplicate()
	f.merge(extra_fakta, true)
	return regelmotor.bedom(handling_id, f, _bedomning_override)


## Utför en handling: bedöms av regelmotorn och läggs i beslutsloggen.
func utfor(handling_id: String, beskrivning: String = "") -> Dictionary:
	var post := regelmotor.bedom(handling_id, fakta, _bedomning_override)
	# Samma beslut igen direkt efter (t.ex. en knapp som hamras på) loggas inte en gång till.
	if not logg.is_empty():
		var forra: Dictionary = logg[-1]
		if str(forra.get("handling", "")) == handling_id and str(forra.get("utfall", "")) == str(post.get("utfall", "")):
			return forra
	post["tid"] = klockstrang()
	post["beskrivning"] = beskrivning if beskrivning != "" else str(post["namn"])
	logg.append(post)
	satt_fakta(regelmotor.satter_fakta(handling_id))
	logg_ny.emit(post)
	return post


## Slumpar skyddsobjekt bland kartans objekttyper och anpassar scenariots texter:
## {objekt} = objektets namn, {objekt_bestamd} = t.ex. "masten".
func _valj_objekttyp(tvinga: String) -> void:
	var typer: Dictionary = karta.get("objekttyper", {})
	if typer.is_empty():
		objekttyp = ""
		return
	var nycklar := typer.keys()
	objekttyp = tvinga if typer.has(tvinga) else str(nycklar[randi() % nycklar.size()])
	var info: Dictionary = typer[objekttyp]
	scenario = _ersatt(scenario, {
		"{objekt}": str(info.get("namn", "")),
		"{objekt_bestamd}": str(info.get("bestamd", "objektet")),
	})
	scenario["objekt"] = str(info.get("namn", scenario.get("objekt", "")))
	var b: Dictionary = scenario.get("briefing", {})
	b["objektinfo"] = str(info.get("beskrivning", "")) + " " + str(b.get("objektinfo", ""))


func _ersatt(v: Variant, byten: Dictionary) -> Variant:
	if v is String:
		var s: String = v
		for nyckel in byten:
			s = s.replace(nyckel, byten[nyckel])
		return s
	if v is Dictionary:
		var ut := {}
		for k in v:
			ut[k] = _ersatt(v[k], byten)
		return ut
	if v is Array:
		var ut2: Array = []
		for x in v:
			ut2.append(_ersatt(x, byten))
		return ut2
	return v


## Väljer en variant av scenariot (t.ex. "utan_pilot"): egna fakta och bedömningar.
func satt_variant(namn: String) -> void:
	variant = namn
	var varianter: Dictionary = scenario.get("varianter", {})
	var v: Dictionary = varianter.get(namn, {})
	satt_fakta(v.get("fakta", {}))
	var b: Dictionary = v.get("bedomning", {})
	for k in b:
		_bedomning_override[k] = b[k]


## Tillbaka till scenariovalet.
func avsluta_scenario() -> void:
	scenario_sokvag = ""
	nollstall()


func satt_fakta(nya: Dictionary) -> void:
	for k in nya:
		fakta[k] = nya[k]


func lagg_till_samband(fran: String, text: String) -> void:
	var rad := {"tid": klockstrang(), "fran": fran, "text": text}
	samband.append(rad)
	samband_ny.emit(rad)


## Radiokanalen: vår egen trafik har företräde. När vi anropar avbryts brus
## (trafik mellan andra enheter) som redan är på gång, och inget nytt brus
## startar förrän vår växling är klar.
var _brus_generation := 0
var _kanal_upptagen_till_ms := 0


func kanal_upptagen() -> bool:
	return Time.get_ticks_msec() < _kanal_upptagen_till_ms


## Spelar upp en radioväxling: varje meddelande har "fran", "text" och
## "efter" (sekunder från start). {nyckel} i texten ersätts från ersattningar.
## brus = trafik mellan andra enheter (lägre prioritet).
func spela_samband(meddelanden: Array, ersattningar: Dictionary = {}, brus := false) -> void:
	var langst := 0.0
	for m in meddelanden:
		langst = maxf(langst, float(m.get("efter", 0.0)))
	if brus:
		if kanal_upptagen():
			return
	else:
		_brus_generation += 1
	_kanal_upptagen_till_ms = maxi(_kanal_upptagen_till_ms, Time.get_ticks_msec() + int((langst + 1.5) * 1000.0))
	var generation := _brus_generation
	for m in meddelanden:
		var text := str(m.get("text", ""))
		for k in ersattningar:
			text = text.replace("{%s}" % k, str(ersattningar[k]))
		var fran := str(m.get("fran", ""))
		var efter := float(m.get("efter", 0.0))
		if efter <= 0.0:
			lagg_till_samband(fran, text)
		elif brus:
			get_tree().create_timer(efter).timeout.connect(_brusrad.bind(fran, text, generation))
		else:
			get_tree().create_timer(efter).timeout.connect(func() -> void: lagg_till_samband(fran, text))


func _brusrad(fran: String, text: String, generation: int) -> void:
	if generation == _brus_generation:
		lagg_till_samband(fran, text)


## Sant om en åtgärd som kräver protokoll (16 §) genomförts utan att protokoll upprättats.
func protokoll_kravs() -> bool:
	if bool(fakta.get("protokoll_upprattat", false)):
		return false
	for k in ["omhandertagande_genomfort", "gripande_genomfort", "beslag_genomfort", "visitation_genomford",
			"dronare_nedskjuten"]:
		if bool(fakta.get(k, false)):
			return true
	return false


func handling_utford(handling_id: String) -> bool:
	for post in logg:
		if post.get("handling", "") == handling_id:
			return true
	return false


## Beslutsloggen plus eventuella uteblivna följdkrav.
func slutlogg() -> Array:
	var extra: Array = []
	for krav in scenario.get("slutkrav", []):
		var h := str(krav.get("handling", ""))
		if h != "" and not handling_utford(h):
			extra.append({
				"tid": "Efter",
				"handling": "slutkrav_" + h,
				"namn": "Uteblivet slutkrav",
				"beskrivning": "Uteblev: " + str(krav.get("text", h)),
				"utfall": "bad",
				"lagrum": str(krav.get("lagrum", "")),
				"kommentar": str(krav.get("text", "")),
				"diskutera": str(krav.get("diskutera", "Varför är det viktigt att detta görs?")),
				"saknade_krav": [],
			})
	return missade + logg + regelmotor.kontrollera_foljdkrav(logg, fakta) + extra


func lagg_till_missad(post: Dictionary) -> void:
	missade.append(post)


## Sparar debriefingen som JSON för instruktören. Returnerar sökvägen.
func spara_logg() -> String:
	var tid := Time.get_datetime_string_from_system().replace(":", "-")
	var sokvag := "user://debriefing_%s_%s.json" % [scenario.get("id", "scenario"), tid]
	var innehall := JSON.stringify({
		"scenario": scenario.get("namn", ""),
		"objekt": scenario.get("objekt", ""),
		"sparad": Time.get_datetime_string_from_system(),
		"lagstod_granskat": regelmotor.ar_granskad(),
		"fakta_vid_slut": fakta,
		"beslut": slutlogg(),
	}, "  ")
	# I webbläsaren: ladda ner filen i stället för att spara i webbläsarens interna lagring.
	if OS.has_feature("web"):
		var filnamn := sokvag.get_file()
		JavaScriptBridge.download_buffer(innehall.to_utf8_buffer(), filnamn, "application/json")
		return "nedladdad som " + filnamn
	var f := FileAccess.open(sokvag, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(innehall)
	return ProjectSettings.globalize_path(sokvag)
