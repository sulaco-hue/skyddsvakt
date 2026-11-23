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
		_sprite.texture = _bilder[0]
		return
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
			framme.emit()
			return
	else:
		position += diff.normalized() * steglangd
	_anim_t += delta
	_sprite.texture = _bilder[int(_anim_t * 6.0) % 2]
