extends Node
## Autoload "Spel": håller scenario, fakta, speltid och beslutslogg.

signal logg_ny(post: Dictionary)
signal samband_ny(rad: Dictionary)

const LAGRUM_SOKVAG := "res://data/lagrum.json"
const SCENARIO_SOKVAG := "res://data/scenarier/fotografen.json"

var regelmotor := Regelmotor.new()
var scenario: Dictionary = {}
var fakta: Dictionary = {}
var logg: Array = []
var samband: Array = []
var klocka_s := 0.0
var klocka_igang := false


func _ready() -> void:
	nollstall()


func nollstall() -> void:
	regelmotor.ladda(LAGRUM_SOKVAG)
	scenario = Datafil.las_json(SCENARIO_SOKVAG)
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


## Utför en handling: bedöms av regelmotorn och läggs i beslutsloggen.
func utfor(handling_id: String, beskrivning: String = "") -> Dictionary:
	var post := regelmotor.bedom(handling_id, fakta)
	post["tid"] = klockstrang()
	post["beskrivning"] = beskrivning if beskrivning != "" else str(post["namn"])
	logg.append(post)
	satt_fakta(regelmotor.satter_fakta(handling_id))
	logg_ny.emit(post)
	return post


func satt_fakta(nya: Dictionary) -> void:
	for k in nya:
		fakta[k] = nya[k]


func lagg_till_samband(fran: String, text: String) -> void:
	var rad := {"tid": klockstrang(), "fran": fran, "text": text}
	samband.append(rad)
	samband_ny.emit(rad)


## Spelar upp en radioväxling: varje meddelande har "fran", "text" och
## "efter" (sekunder från start). {nyckel} i texten ersätts från ersattningar.
func spela_samband(meddelanden: Array, ersattningar: Dictionary = {}) -> void:
	for m in meddelanden:
		var text := str(m.get("text", ""))
		for k in ersattningar:
			text = text.replace("{%s}" % k, str(ersattningar[k]))
		var fran := str(m.get("fran", ""))
		var efter := float(m.get("efter", 0.0))
		if efter <= 0.0:
			lagg_till_samband(fran, text)
		else:
			get_tree().create_timer(efter).timeout.connect(func() -> void: lagg_till_samband(fran, text))


func handling_utford(handling_id: String) -> bool:
	for post in logg:
		if post.get("handling", "") == handling_id:
			return true
	return false


## Beslutsloggen plus eventuella uteblivna följdkrav.
func slutlogg() -> Array:
	return logg + regelmotor.kontrollera_foljdkrav(logg, fakta)


## Sparar debriefingen som JSON för instruktören. Returnerar sökvägen.
func spara_logg() -> String:
	var tid := Time.get_datetime_string_from_system().replace(":", "-")
	var sokvag := "user://debriefing_%s_%s.json" % [scenario.get("id", "scenario"), tid]
	var f := FileAccess.open(sokvag, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify({
		"scenario": scenario.get("namn", ""),
		"objekt": scenario.get("objekt", ""),
		"sparad": Time.get_datetime_string_from_system(),
		"lagstod_granskat": regelmotor.ar_granskad(),
		"fakta_vid_slut": fakta,
		"beslut": slutlogg(),
	}, "  "))
	return ProjectSettings.globalize_path(sokvag)
