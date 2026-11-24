class_name Datafil
extends RefCounted
## Hjälpfunktioner för att läsa datafiler och hantera speltid.


## Redigerade datafiler (från redigeraren i spelet) sparas här, på den här enheten,
## och används i stället för originalen i res://data/.
const REDIGERAT := "user://redigerat/"
## Av i testerna, så att lokala redigeringar inte påverkar dem.
static var anvand_redigerat := true


static func las_json(sokvag: String, original := false) -> Dictionary:
	var text := las_text(sokvag, original)
	if text == "":
		push_error("Kunde inte öppna %s" % sokvag)
		return {}
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Ogiltig JSON i %s" % sokvag)
		return {}
	return data


## Filens text: den redigerade versionen om det finns en (och original = false).
static func las_text(sokvag: String, original := false) -> String:
	var s := sokvag
	if not original and anvand_redigerat and har_redigering(sokvag):
		s = redigerad_sokvag(sokvag)
	var f := FileAccess.open(s, FileAccess.READ)
	return f.get_as_text() if f else ""


static func redigerad_sokvag(sokvag: String) -> String:
	return REDIGERAT + sokvag.trim_prefix("res://").replace("/", "__")


static func har_redigering(sokvag: String) -> bool:
	return FileAccess.file_exists(redigerad_sokvag(sokvag))


## Sparar en redigerad version. Är texten samma som originalet tas redigeringen bort.
static func spara_redigering(sokvag: String, text: String) -> void:
	var orig := las_text(sokvag, true)
	if text == orig:
		ta_bort_redigering(sokvag)
		return
	DirAccess.make_dir_recursive_absolute(REDIGERAT)
	var f := FileAccess.open(redigerad_sokvag(sokvag), FileAccess.WRITE)
	if f == null:
		push_error("Kunde inte spara %s" % redigerad_sokvag(sokvag))
		return
	f.store_string(text)
	f.close()
	# Originalets kontrollsumma, så att vi kan varna om originalet ändras senare.
	var b := FileAccess.open(redigerad_sokvag(sokvag) + ".bas", FileAccess.WRITE)
	if b:
		b.store_string(orig.md5_text())


static func ta_bort_redigering(sokvag: String) -> void:
	for s in [redigerad_sokvag(sokvag), redigerad_sokvag(sokvag) + ".bas"]:
		if FileAccess.file_exists(s):
			DirAccess.remove_absolute(s)


## Sant om originalet har ändrats (t.ex. på GitHub) sedan redigeringen gjordes.
static func original_andrat(sokvag: String) -> bool:
	var b := FileAccess.open(redigerad_sokvag(sokvag) + ".bas", FileAccess.READ)
	return b != null and b.get_as_text().strip_edges() != las_text(sokvag, true).md5_text()


## Alla redigerade filer (som res://-sökvägar).
static func redigerade() -> Array:
	var ut: Array = []
	var d := DirAccess.open(REDIGERAT)
	if d == null:
		return ut
	for namn in d.get_files():
		if not namn.ends_with(".bas"):
			ut.append("res://" + namn.replace("__", "/"))
	return ut


## JSON som text i samma format som filerna i repot (2 blanksteg, å/ä/ö som de är).
static func till_text(v: Variant) -> String:
	return _json(v, "") + "\n"


static func _json(v: Variant, indrag: String) -> String:
	var inre := indrag + "  "
	match typeof(v):
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if d.is_empty():
				return "{}"
			var delar: PackedStringArray = []
			for k in d:
				delar.append(inre + JSON.stringify(str(k)) + ": " + _json(d[k], inre))
			return "{\n" + ",\n".join(delar) + "\n" + indrag + "}"
		TYPE_ARRAY:
			var a: Array = v
			if a.is_empty():
				return "[]"
			var delar: PackedStringArray = []
			for x in a:
				delar.append(inre + _json(x, inre))
			return "[\n" + ",\n".join(delar) + "\n" + indrag + "]"
		TYPE_FLOAT:
			var f: float = v
			if is_equal_approx(f, roundf(f)) and absf(f) < 1e15:
				return str(int(roundf(f)))
			return JSON.stringify(f)
		_:
			return JSON.stringify(v)


static func tid_till_s(tid: String) -> float:
	var delar := tid.split(":")
	if delar.size() < 2:
		return 0.0
	return float(int(delar[0]) * 3600 + int(delar[1]) * 60)


static func s_till_tid(sekunder: float) -> String:
	var s := int(sekunder)
	return "%02d:%02d" % [floori(s / 3600.0) % 24, floori(s / 60.0) % 60]


static func cell(v: Variant) -> Vector2i:
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i.ZERO
