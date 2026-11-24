class_name Kamratsnack
extends Node
## Stridsparskamratens småprat (data/kamratsnack.json).
##
## Kamraten säger då och då något om sport, elpriser, datorspel osv.
## Ettan (du) kan sucka, svara eller inget göra. Med "Tyst nu" [T]
## tystnar kamraten en stund. Pratet pausas under kontakt och efter händelser.

const SOKVAG := "res://data/kamratsnack.json"

var hud: Hud
var varld: Varld
var aktiv := false

var _data: Dictionary = {}
var _inst: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _tyst_kvar := 0.0
var _senaste: Array[int] = []
## Scenariots väderläge, t.ex. ["regn", "kallt"]. Repliker med "nar" kräver att
## alla deras villkor finns här.
var _vader: Array = []


func setup(p_hud: Hud, p_varld: Varld, scenario: Dictionary = {}) -> void:
	_vader = scenario.get("vaderlag", [])
	hud = p_hud
	varld = p_varld
	_rng.randomize()
	_data = Datafil.las_json(SOKVAG)
	_inst = _data.get("installningar", {})
	_timer = float(_inst.get("forsta_efter_s", 12))


func _process(delta: float) -> void:
	if not aktiv or _data.is_empty():
		return
	if _tyst_kvar > 0.0:
		_tyst_kvar -= delta
		return
	_timer -= delta
	if _timer <= 0.0:
		_prata()
		_timer = _rng.randf_range(float(_inst.get("intervall_min_s", 25)), float(_inst.get("intervall_max_s", 60)))


## Pausa pratet i sek sekunder (t.ex. efter att en händelse upptäckts).
func pausa(sek: float) -> void:
	_tyst_kvar = maxf(_tyst_kvar, sek)


## Ettan säger åt tvåan att vara tyst.
func tysta() -> void:
	if not aktiv:
		return
	hud.visa_bubbla(varld.spelare, _slumpa(_data.get("tyst_repliker", ["Tyst nu."])), 3.5)
	_tyst_kvar = float(_inst.get("tystnad_s", 120))
	get_tree().create_timer(2.0).timeout.connect(_kamrat_tystnar)


func status() -> String:
	if not aktiv:
		return "pausat"
	if _tyst_kvar > 0.0:
		return "tyst i %.0f s till" % _tyst_kvar
	return "nästa om %.0f s" % _timer


func _kamrat_tystnar() -> void:
	if aktiv:
		hud.visa_bubbla(varld.kollega, _slumpa(_data.get("kamrat_tystnad", ["Okej."])), 3.0)


func _prata() -> void:
	var lista: Array = _data.get("snack", [])
	if lista.is_empty():
		return
	# Repliker som passar vädret prioriteras (40 %); andra med villkor hoppas över.
	var mojliga: Array[int] = []
	var vader_rader: Array[int] = []
	for i in lista.size():
		var nar: Array = lista[i].get("nar", [])
		var passar := true
		for v in nar:
			if not v in _vader:
				passar = false
		if not passar:
			continue
		mojliga.append(i)
		if not nar.is_empty():
			vader_rader.append(i)
	if mojliga.is_empty():
		return
	var pool := mojliga
	if not vader_rader.is_empty() and _rng.randf() < float(_inst.get("chans_vaderreplik", 0.4)):
		pool = vader_rader
	var idx := pool[_rng.randi_range(0, pool.size() - 1)]
	var forsok := 0
	while idx in _senaste and forsok < 10:
		idx = pool[_rng.randi_range(0, pool.size() - 1)]
		forsok += 1
	_senaste.append(idx)
	if _senaste.size() > mini(8, lista.size() - 1):
		_senaste.remove_at(0)
	var rad: Dictionary = lista[idx]
	hud.visa_bubbla(varld.kollega, str(rad.get("kamrat", "")), 5.5)
	get_tree().create_timer(float(_inst.get("reaktion_efter_s", 3.5))).timeout.connect(_reagera.bind(rad))


func _reagera(rad: Dictionary) -> void:
	if not aktiv or _tyst_kvar > 0.0:
		return
	var r := _rng.randf()
	var suck := float(_inst.get("chans_suck", 0.3))
	var svar := float(_inst.get("chans_svar", 0.4))
	if r < suck:
		hud.visa_ljud(varld.spelare, _slumpa(_data.get("suckar", ["suck"])), 1.8)
	elif r < suck + svar:
		var egna: Array = rad.get("svar", [])
		var text := _slumpa(egna) if not egna.is_empty() and _rng.randf() < 0.75 else _slumpa(_data.get("allmanna_svar", ["Mm."]))
		hud.visa_bubbla(varld.spelare, text, 3.5)


func _slumpa(lista: Array) -> String:
	if lista.is_empty():
		return ""
	return str(lista[_rng.randi_range(0, lista.size() - 1)])
