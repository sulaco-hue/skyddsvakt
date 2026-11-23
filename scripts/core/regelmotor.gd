class_name Regelmotor
extends RefCounted
## Bedömer spelarens handlingar mot lagstödet i data/lagrum.json.
##
## Varje handling har en lista med krav (fakta som alla måste vara sanna i
## scenariot) och eventuellt "krav_nagon" (minst ett måste vara sant). Är alla krav uppfyllda blir utfallet "ok", annars det som
## anges i "vid_brist" ("warn" = diskutabelt, "bad" = saknar lagstöd).
## Följdkrav (t.ex. anmälan till polis enligt 17 § skyddslagen) kontrolleras
## när passet är slut. Ett följdkrav kan ha "om_fakta": det gäller då bara om
## det faktumet är sant (t.ex. att ett beslag faktiskt genomfördes).

const OK := "ok"
const DISKUTABELT := "warn"
const SAKNAR_STOD := "bad"

var meta: Dictionary = {}
var handlingar: Dictionary = {}


func ladda(sokvag: String) -> bool:
	var data := Datafil.las_json(sokvag)
	if data.is_empty():
		return false
	meta = data.get("meta", {})
	handlingar = data.get("handlingar", {})
	return true


func ar_granskad() -> bool:
	return bool(meta.get("granskad", false))


func bedom(handling_id: String, fakta: Dictionary) -> Dictionary:
	var h: Dictionary = handlingar.get(handling_id, {})
	if h.is_empty():
		return {
			"handling": handling_id,
			"namn": handling_id,
			"utfall": DISKUTABELT,
			"lagrum": "[saknas i lagrum.json]",
			"kommentar": "Handlingen '%s' finns inte i lagstödsfilen." % handling_id,
			"diskutera": "",
			"saknade_krav": [],
		}
	var saknas: Array = []
	for krav in h.get("krav", []):
		if not bool(fakta.get(krav, false)):
			saknas.append(krav)
	# "krav_nagon": minst ett av dessa fakta måste vara sant.
	var nagon: Array = h.get("krav_nagon", [])
	if not nagon.is_empty():
		var nagot_sant := false
		for k in nagon:
			if bool(fakta.get(k, false)):
				nagot_sant = true
		if not nagot_sant:
			saknas.append(" eller ".join(PackedStringArray(nagon)))
	var uppfyllt := saknas.is_empty()
	return {
		"handling": handling_id,
		"namn": str(h.get("namn", handling_id)),
		"utfall": OK if uppfyllt else str(h.get("vid_brist", DISKUTABELT)),
		"lagrum": str(h.get("lagrum", "")),
		"kommentar": str(h.get("text_ok", "")) if uppfyllt else str(h.get("text_brist", "")),
		"diskutera": str(h.get("diskutera", "")),
		"saknade_krav": saknas,
	}


func satter_fakta(handling_id: String) -> Dictionary:
	var h: Dictionary = handlingar.get(handling_id, {})
	return h.get("satter_fakta", {})


## Returnerar extra loggposter för följdkrav som inte uppfyllts.
func kontrollera_foljdkrav(logg: Array, fakta: Dictionary) -> Array:
	var extra: Array = []
	var redan: Dictionary = {}
	for post in logg:
		var h: Dictionary = handlingar.get(post.get("handling", ""), {})
		for fk in h.get("foljdkrav", []):
			var nyckel := str(fk.get("fakta", ""))
			var villkor := str(fk.get("om_fakta", ""))
			if villkor != "" and not bool(fakta.get(villkor, false)):
				continue
			if nyckel == "" or bool(fakta.get(nyckel, false)) or redan.has(nyckel):
				continue
			redan[nyckel] = true
			extra.append({
				"tid": "Efter",
				"handling": "foljdkrav_" + nyckel,
				"namn": "Uteblivet följdkrav",
				"beskrivning": "Uteblev: " + str(fk.get("text", nyckel)),
				"utfall": SAKNAR_STOD,
				"lagrum": str(fk.get("lagrum", "")),
				"kommentar": str(fk.get("text", "")) + " Det gjordes inte under passet.",
				"diskutera": "Hur och via vem gör du anmälan i praktiken?",
				"saknade_krav": [nyckel],
			})
	return extra
