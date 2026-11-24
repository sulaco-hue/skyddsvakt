class_name Aktor
extends Node2D
## En figur i världen (skyddsvakt, kollega, civilperson) som går längs en väg av rutor.

signal framme
signal steg(cell: Vector2i)
signal blixt

var cell := Vector2i.ZERO
var hastighet := 56.0
var varld: Varld

var _vag: Array[Vector2i] = []
var _sprite: Sprite2D
var _bilder: Array[Texture2D] = []
var _anim_t := 0.0
var _blixt: Sprite2D
var _blixt_t := 0.0
var _fotograferar := false

## Viloanimationer (bara för figurer som har bilder "<bas>_vila_*.png").
## Varje steg: [bild ("bas" = grundbilden), sekunder, effekt ("", "rok" eller "anga")]
const VILA := {
	"titta": [["titta_v", 1.2, ""], ["bas", 0.4, ""], ["titta_h", 1.2, ""], ["bas", 0.3, ""]],
	"fippla": [["fippla_radio", 0.7, ""], ["bas", 0.3, ""], ["fippla_radio", 0.7, ""], ["bas", 0.4, ""],
		["fippla_hjalm", 0.9, ""]],
	"kaffe": [["kaffe_lag", 1.0, "anga"], ["kaffe_dricker", 1.4, ""], ["kaffe_lag", 1.2, "anga"],
		["kaffe_dricker", 1.2, ""], ["kaffe_lag", 0.8, "anga"]],
	"roka": [["roka_ner", 1.2, ""], ["roka_hand", 1.2, ""], ["roka_ner", 1.6, "rok"], ["roka_hand", 1.2, ""],
		["roka_ner", 1.4, "rok"]],
}
## Sannolikhetsvikter för vilken viloanimation som väljs.
const VILA_VIKT := {"titta": 35, "fippla": 30, "kaffe": 20, "roka": 15}

var vila_aktiv := true
var _bas := ""
var _vila_bilder: Dictionary = {}
var _vila_steg: Array = []
var _vila_t := 0.0
var _vila_vant := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_varld: Varld, bas: String, start: Vector2i, anchor: Array) -> void:
	varld = p_varld
	cell = start
	_bilder = [load("res://assets/gfx/%s_0.png" % bas), load("res://assets/gfx/%s_1.png" % bas)]
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _bilder[0]
	_sprite.offset = -Vector2(float(anchor[0]), float(anchor[1]))
	add_child(_sprite)
	position = varld.cell_pos(cell)
	_bas = bas
	_rng.randomize()
	_vila_vant = _rng.randf_range(2.0, 7.0)
	for namn: String in VILA:
		for steg in VILA[namn]:
			var bild := str(steg[0])
			var sokvag := "res://assets/gfx/%s_vila_%s.png" % [bas, bild]
			if bild != "bas" and not _vila_bilder.has(bild) and ResourceLoader.exists(sokvag):
				_vila_bilder[bild] = load(sokvag)


## Byter figurens bilder (t.ex. "yxman_upp" när personen räcker upp händerna).
func byt_bilder(bas: String, anchor: Array) -> void:
	_bilder = [load("res://assets/gfx/%s_0.png" % bas), load("res://assets/gfx/%s_1.png" % bas)]
	_sprite.texture = _bilder[0]
	_sprite.offset = -Vector2(float(anchor[0]), float(anchor[1]))
	_bas = bas
	_vila_bilder.clear()


## Växlar mellan bild 0 och 1 även när figuren står still (darrande händer, andning).
var vaxla_still := false


func ga_langs(vag: Array[Vector2i]) -> void:
	_vag.assign(vag)
	if not _vag.is_empty() and _vag[0] == cell:
		_vag.remove_at(0)
	if _vag.is_empty():
		framme.emit()


func stanna() -> void:
	_vag.clear()
	position = varld.cell_pos(cell)


func ar_i_rorelse() -> bool:
	return not _vag.is_empty()


func vand_mot(punkt: Vector2) -> void:
	_sprite.flip_h = punkt.x < position.x


func traffar(punkt: Vector2) -> bool:
	var r := Rect2(position + _sprite.offset, _sprite.texture.get_size()).grow(4.0)
	return r.has_point(punkt)


func satt_fotograferar(pa: bool) -> void:
	_fotograferar = pa
	if pa and _blixt == null:
		_blixt = Sprite2D.new()
		_blixt.texture = load("res://assets/gfx/blixt.png")
		_blixt.position = Vector2(-6 if not _sprite.flip_h else 6, -18)
		add_child(_blixt)
	if _blixt:
		_blixt.visible = false


func _process(delta: float) -> void:
	if _fotograferar and _blixt:
		_blixt_t += delta
		var syns := fmod(_blixt_t, 2.2) < 0.12
		if syns and not _blixt.visible:
			blixt.emit()
		_blixt.visible = syns
	if _vag.is_empty():
		if vaxla_still:
			_anim_t += delta
			_sprite.texture = _bilder[int(_anim_t * 2.0) % 2]
			return
		_uppdatera_vila(delta)
		return
	_vila_steg.clear()
	var mal := varld.cell_pos(_vag[0])
	var diff := mal - position
	var steglangd := hastighet * delta
	if absf(diff.x) > 0.01:
		_sprite.flip_h = diff.x < 0.0
	if diff.length() <= steglangd:
		position = mal
		cell = _vag[0]
		_vag.remove_at(0)
		steg.emit(cell)
		if _vag.is_empty():
			_sprite.texture = _bilder[0]
			_vila_vant = _rng.randf_range(2.0, 6.0)
			framme.emit()
			return
	else:
		position += diff.normalized() * steglangd
	_anim_t += delta
	_sprite.texture = _bilder[int(_anim_t * 6.0) % 2]


# ------------------------------------------------------------ Vila --

func _uppdatera_vila(delta: float) -> void:
	if not vila_aktiv or _vila_bilder.is_empty() or _fotograferar:
		_vila_steg.clear()
		_sprite.texture = _bilder[0]
		return
	if _vila_steg.is_empty():
		_sprite.texture = _bilder[0]
		_vila_vant -= delta
		if _vila_vant <= 0.0:
			var sekvens: Array = VILA[_valj_vila()]
			_vila_steg = sekvens.duplicate()
			_vila_t = 0.0
		return
	_vila_t -= delta
	if _vila_t > 0.0:
		return
	var steg: Array = _vila_steg.pop_front()
	var bild := str(steg[0])
	_sprite.texture = _bilder[0] if bild == "bas" else _vila_bilder.get(bild, _bilder[0])
	_vila_t = float(steg[1])
	_effekt(str(steg[2]))
	if _vila_steg.is_empty():
		_vila_vant = _rng.randf_range(3.0, 9.0) + _vila_t


func _valj_vila() -> String:
	var summa := 0
	for namn: String in VILA_VIKT:
		summa += int(VILA_VIKT[namn])
	var r := _rng.randi_range(1, summa)
	for namn: String in VILA_VIKT:
		r -= int(VILA_VIKT[namn])
		if r <= 0:
			return namn
	return "titta"


## Liten rökpuff eller ånga som stiger och tonar bort. Puffarna lämnas kvar i
## världen där de släpptes (de följer inte med när gubben går vidare).
func _effekt(typ: String) -> void:
	if typ == "":
		return
	var antal := 3 if typ == "rok" else 2
	for i in antal:
		if i == 0:
			_puff(typ, i)
		else:
			get_tree().create_timer(i * 0.35).timeout.connect(_puff.bind(typ, i))


func _puff(typ: String, i: int) -> void:
	var varld_lager := get_parent()
	if varld_lager == null or not is_inside_tree():
		return
	var riktning := -1.0 if _sprite.flip_h else 1.0
	var s := Sprite2D.new()
	s.texture = load("res://assets/gfx/%s.png" % ("rok" if typ == "rok" else "anga"))
	var start := position + (Vector2(3.0 * riktning, -17.0) if typ == "rok" else Vector2(4.0 * riktning, -15.0))
	s.position = start
	s.modulate.a = 0.0
	s.z_index = 1
	varld_lager.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.9, 0.15)
	tw.parallel().tween_property(s, "position", start + Vector2(riktning * (2.0 + i), -14.0), 1.6)
	tw.tween_property(s, "modulate:a", 0.0, 0.5)
	tw.tween_callback(s.queue_free)
