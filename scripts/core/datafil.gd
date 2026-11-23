class_name Datafil
extends RefCounted
## Hjälpfunktioner för att läsa datafiler och hantera speltid.


static func las_json(sokvag: String) -> Dictionary:
	var f := FileAccess.open(sokvag, FileAccess.READ)
	if f == null:
		push_error("Kunde inte öppna %s" % sokvag)
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Ogiltig JSON i %s" % sokvag)
		return {}
	return data


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
