class_name Radiotrafik
extends Node
## Levande radiotrafik: scenariot beskriver vad CQ och andra enheter säger
## när något händer ("radio" i scenariofilen). Varje krok är en lista med
## inslag som spelas högst en gång:
##
##   "radio": {
##     "upptackt": [ { "efter_s": 25, "om_ej_handling": "rapportera_vaktchef",
##                     "variant": "med_pilot", "om_fakta": {"x": true},
##                     "meddelanden": [ {"fran": "CQ", "text": "…", "efter": 0}, … ] } ],
##     "handling:anmala_polis": [ … ],
##     …
##   }
##
## Krokar som spelet utlöser: upptackt, kontakt_start, kontakt_slut,
## npc_lamnar, dronare_flyger_bort, dronare_landar, motpart_ger_upp,
## motpart_skjuten, angrepp_nadde_fram samt "handling:<id>" för varje beslut
## i loggen. Inslagen väntar tills kanalen är ledig så att CQ inte pratar
## i munnen på vår egen växling.

const MAX_VANTAN_S := 20.0

var _radio: Dictionary = {}
var _spelade: Dictionary = {}
var _ko: Array = []  # [{inslag, vantat}]
var ersattningar: Callable  ## -> Dictionary, t.ex. {"lage": …}
## Sant medan kontaktläget är öppet: inslagen väntar tills det stängs.
var vanta := false
## Antal inslag som spelats (används av testerna).
var antal_spelade := 0


func setup(scenario: Dictionary) -> void:
	_radio = scenario.get("radio", {})
	Spel.logg_ny.connect(_pa_logg)


func _pa_logg(post: Dictionary) -> void:
	krok("handling:" + str(post.get("handling", "")))


## Utlöser en krok. Inslag med "efter_s" köas med fördröjning.
func krok(namn: String) -> void:
	var inslag: Array = _radio.get(namn, [])
	for i in inslag.size():
		var nyckel := "%s#%d" % [namn, i]
		if _spelade.has(nyckel):
			continue
		var d: Dictionary = inslag[i]
		if not _variant_passar(d):
			continue
		_spelade[nyckel] = true
		var efter := float(d.get("efter_s", 0.0))
		if efter > 0.0:
			get_tree().create_timer(efter).timeout.connect(_koa.bind(d))
		else:
			_koa(d)


func _variant_passar(d: Dictionary) -> bool:
	var v: Variant = d.get("variant", "")
	if v is Array:
		return Spel.variant in v
	return str(v) == "" or str(v) == Spel.variant


func _koa(d: Dictionary) -> void:
	_ko.append({"inslag": d, "vantat": 0.0})


func _process(delta: float) -> void:
	if _ko.is_empty() or not Spel.klocka_igang or vanta:
		return
	var forsta: Dictionary = _ko[0]
	forsta["vantat"] = float(forsta["vantat"]) + delta
	# Vår egen trafik eller annan pågående växling: vänta (högst MAX_VANTAN_S).
	# Öppen linje med CQ: vänta tills samtalet är slut (ingen tidsgräns).
	if Spel.samtal_oppet:
		forsta["vantat"] = 0.0
		return
	if Spel.kanal_upptagen() and float(forsta["vantat"]) < MAX_VANTAN_S:
		return
	_ko.pop_front()
	var d: Dictionary = forsta["inslag"]
	if not _villkor_uppfyllda(d):
		return
	antal_spelade += 1
	var byt: Dictionary = ersattningar.call() if ersattningar.is_valid() else {}
	Spel.spela_samband(d.get("meddelanden", []), byt, false)
	# Inslaget kan sätta fakta (t.ex. att polis är underrättad).
	Spel.satt_fakta(d.get("satt_fakta", {}))


## Villkoren prövas när inslaget ska spelas, inte när kroken utlöstes:
## "CQ efterfrågar lägesrapport" spelas bara om rapporten fortfarande saknas.
func _villkor_uppfyllda(d: Dictionary) -> bool:
	var ej := str(d.get("om_ej_handling", ""))
	if ej != "" and Spel.handling_utford(ej):
		return false
	var maste := str(d.get("om_handling", ""))
	if maste != "" and not Spel.handling_utford(maste):
		return false
	var f: Dictionary = d.get("om_fakta", {})
	for k in f:
		if bool(Spel.fakta.get(k, false)) != bool(f[k]):
			return false
	return true


func status() -> String:
	return "radio: %d spelade, %d i kö" % [antal_spelade, _ko.size()]
