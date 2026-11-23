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
##
## Graderade krav: "krav_utfall" ({krav: "warn"/"bad"}) och "grupp_utfall"
## (ett utfall per grupp i krav_grupper) anger hur allvarlig en viss brist är.
## Det allvarligaste saknade kravet avgör utfallet. "text_krav" ({krav: text})
## ger en egen kommentar för det allvarligaste saknade kravet (t.ex. att
## angreppet redan hade upphört när skottet avlossades).

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
	var vid_brist := str(h.get("vid_brist", DISKUTABELT))
	var krav_utfall: Dictionary = h.get("krav_utfall", {})
	var text_krav: Dictionary = h.get("text_krav", {})
	var varst := ""
	var varst_text := ""
	# "krav": alla måste vara sanna.
	for krav in h.get("krav", []):
		if bool(fakta.get(krav, false)):
			uppfyllda.append(lasbar(krav))
		else:
			saknas.append(lasbar(krav))
			var u := str(krav_utfall.get(krav, vid_brist))
			if _grad(u) > _grad(varst):
				varst = u
				varst_text = str(text_krav.get(krav, ""))
	# "krav_grupper": i varje grupp måste minst ett vara sant (t.ex. grunderna i 12 §).
	var grupper: Array = h.get("krav_grupper", [])
	if h.has("krav_nagon"):
		grupper = grupper + [h["krav_nagon"]]
	var grupp_utfall: Array = h.get("grupp_utfall", [])
	for gi in grupper.size():
		var grupp: Array = grupper[gi]
		var sanna: Array = []
		for k in grupp:
			if bool(fakta.get(k, false)):
				sanna.append(lasbar(k))
		if sanna.is_empty():
			var alla := PackedStringArray()
			for k in grupp:
				alla.append(lasbar(k))
			saknas.append(" ELLER ".join(alla))
			var u := str(grupp_utfall[gi]) if gi < grupp_utfall.size() else vid_brist
			if _grad(u) > _grad(varst):
				varst = u
				varst_text = str(text_krav.get(str(grupp[0]), ""))
		else:
			uppfyllda.append_array(sanna)
	var uppfyllt := saknas.is_empty()
	return {
		"handling": handling_id,
		"namn": str(h.get("namn", handling_id)),
		"utfall": OK if uppfyllt else varst,
		"lagrum": str(h.get("lagrum", "")),
		"kommentar": str(h.get("text_ok", "")) if uppfyllt else (varst_text if varst_text != "" else str(h.get("text_brist", ""))),
		"diskutera": str(h.get("diskutera", "")),
		"saknade_krav": saknas,
		"uppfyllda_krav": uppfyllda,
	}


func _grad(utfall: String) -> int:
	return {DISKUTABELT: 1, SAKNAR_STOD: 2}.get(utfall, 0)


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
