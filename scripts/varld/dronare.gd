class_name Dronare
extends Node2D
## En drönare som flyger fritt över kartan (inte i rutnätet).
##
## Noden står på marken under drönaren; själva bilden lyfts upp med `hojd`.
## Skuggan ritas på marken. Ljud ("bzzzz", "KRASCH") skickas som signal så
## att HUD kan visa dem som text ovanför drönaren.

signal framme
signal ljud(text: String)

const FART := 70.0           ## px/s i sidled
const STIGFART := 30.0       ## px/s i höjdled
const FLYGHOJD := 46.0

var hojd := 0.0
var lage := "marken"  ## marken, flyger, svavar, cirklar, landad, kraschar, vrak
var ljudpunkt := Node2D.new()

var _sprite: Sprite2D
var _skugga: Sprite2D
var _bilder: Array[Texture2D] = []
var _mal := Vector2.ZERO
var _mal_hojd := 0.0
var _centrum := Vector2.ZERO
var _vinkel := 0.0
var _t := 0.0
var _bzz := 1.0
var _fall := 0.0


func setup(markplats: Vector2, skugglager: Node2D) -> void:
	position = markplats
	_bilder = [load("res://assets/gfx/dronare_0.png"), load("res://assets/gfx/dronare_1.png")]
	_sprite = Sprite2D.new()
	_sprite.texture = _bilder[0]
	_sprite.z_index = 40
	add_child(_sprite)
	_skugga = Sprite2D.new()
	_skugga.texture = load("res://assets/gfx/dronare_skugga.png")
	skugglager.add_child(_skugga)
	add_child(ljudpunkt)
	_uppdatera_bild()


func flyg_till(markplats: Vector2, till_hojd := FLYGHOJD) -> void:
	_mal = markplats
	_mal_hojd = till_hojd
	lage = "flyger"


func cirkla(centrum: Vector2) -> void:
	_centrum = centrum
	_vinkel = (position - centrum).angle()
	lage = "cirklar"


func landa_vid(markplats: Vector2) -> void:
	flyg_till(markplats, 0.0)


func krascha() -> void:
	if lage in ["vrak", "kraschar"]:
		return
	lage = "kraschar"
	_fall = 0.0


func i_luften() -> bool:
	return lage in ["flyger", "svavar", "cirklar"] and hojd > 1.0


func _process(delta: float) -> void:
	_t += delta
	match lage:
		"flyger":
			var diff := _mal - position
			var steg := FART * delta
			if diff.length() <= steg:
				position = _mal
			else:
				position += diff.normalized() * steg
			hojd = move_toward(hojd, _mal_hojd, STIGFART * delta)
			if position == _mal and is_equal_approx(hojd, _mal_hojd):
				lage = "landad" if _mal_hojd <= 0.0 else "svavar"
				framme.emit()
		"cirklar":
			_vinkel += delta * 0.7
			position = _centrum + Vector2(cos(_vinkel) * 38.0, sin(_vinkel) * 19.0)
			hojd = move_toward(hojd, FLYGHOJD + sin(_t * 1.3) * 3.0, STIGFART * delta)
		"svavar":
			hojd = _mal_hojd + sin(_t * 2.0) * 1.5
		"kraschar":
			_fall += 220.0 * delta
			hojd = maxf(0.0, hojd - _fall * delta)
			_sprite.rotation += delta * 9.0
			if hojd <= 0.0:
				lage = "vrak"
				_sprite.rotation = 0.0
				_sprite.texture = load("res://assets/gfx/dronare_vrak.png")
				ljud.emit("krasch")
	if i_luften():
		_bzz -= delta
		if _bzz <= 0.0:
			_bzz = 2.4
			ljud.emit("bzzzz")
	_uppdatera_bild()


func _uppdatera_bild() -> void:
	_sprite.position = Vector2(0, -hojd - 3.0)
	ljudpunkt.position = Vector2(0, -hojd - 4.0)
	if lage != "vrak" and lage != "kraschar":
		_sprite.texture = _bilder[int(_t * 2.5) % 2] if hojd > 0.5 else _bilder[1]
	_skugga.global_position = global_position
	_skugga.visible = lage != "vrak"
	var s := clampf(1.0 - hojd / 120.0, 0.5, 1.0)
	_skugga.scale = Vector2(s, s)


func _exit_tree() -> void:
	if is_instance_valid(_skugga):
		_skugga.queue_free()
