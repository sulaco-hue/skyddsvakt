class_name Regelmotor
extends RefCounted
## Bedömer spelarens handlingar mot lagstödet i data/lagrum.json.
##
## Varje handling har en lista med krav (fakta som alla måste vara sanna i
## scenariot) och "krav_grupper" (i varje grupp måste minst ett vara sant). Är alla krav uppfyllda blir utfallet "ok", annars det som
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


## override: scenariots/variantens ändringar per handling (t.ex. annan vid_brist eller text).
func bedom(handling_id: String, fakta: Dictionary, override: Dictionary = {}) -> Dictionary:
	var h: Dictionary = handlingar.get(handling_id, {})
	if override.has(handling_id) and not h.is_empty():
		h = h.duplicate(true)
		var andring: Dictionary = override[handling_id]
		for k in andring:
			h[k] = andring[k]
	if h.is_empty():
		return {
			"handling": handling_id,
			"namn": handling_id,
			"utfall": DISKUTABELT,
			"lagrum": "[saknas i lagrum.json]",
			"kommentar": "Handlingen '%s' finns inte i lagstödsfilen." % handling_id,
			"diskutera": "",
			"saknade_krav": [],
			"uppfyllda_krav": [],
		}
	var saknas: Array = []
	var uppfyllda: Array = []
	# "krav": alla måste vara sanna.
	for krav in h.get("krav", []):
		if bool(fakta.get(krav, false)):
			uppfyllda.append(lasbar(krav))
		else:
			saknas.append(lasbar(krav))
	# "krav_grupper": i varje grupp måste minst ett vara sant (t.ex. grunderna i 12 §).
	var grupper: Array = h.get("krav_grupper", [])
	if h.has("krav_nagon"):
		grupper = grupper + [h["krav_nagon"]]
	for grupp in grupper:
		var sanna: Array = []
		for k in grupp:
			if bool(fakta.get(k, false)):
				sanna.append(lasbar(k))
		if sanna.is_empty():
			var alla := PackedStringArray()
			for k in grupp:
				alla.append(lasbar(k))
			saknas.append(" ELLER ".join(alla))
		else:
			uppfyllda.append_array(sanna)
	var uppfyllt := saknas.is_empty()
	return {
		"handling": handling_id,
		"namn": str(h.get("namn", handling_id)),
		"utfall": OK if uppfyllt else str(h.get("vid_brist", DISKUTABELT)),
		"lagrum": str(h.get("lagrum", "")),
		"kommentar": str(h.get("text_ok", "")) if uppfyllt else str(h.get("text_brist", "")),
		"diskutera": str(h.get("diskutera", "")),
		"saknade_krav": saknas,
		"uppfyllda_krav": uppfyllda,
	}


## Rekvisitets namn i klartext (meta.rekvisit i lagrum.json).
func lasbar(nyckel: String) -> String:
	var r: Dictionary = meta.get("rekvisit", {})
	return str(r.get(nyckel, nyckel.replace("_", " ")))


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
				"saknade_krav": [lasbar(nyckel)],
				"uppfyllda_krav": [],
			})
	return extra
