class_name Varld
extends Node2D
## Den isometriska världen: byggs upp från kartan i scenariofilen.
##
## Marken är ett TileMapLayer (isometriska rutor 32x16 px). Objekt som staket,
## byggnader och träd är sprites som y-sorteras. Spelaren går dit man klickar
## (AStarGrid2D över rutnätet).

signal npc_klickad(npc_id: String)
signal spelare_framme
signal kamrat_klickad

const RUTSTORLEK := Vector2i(32, 16)
const ZOOM := 2.0
## Mark-tecken -> två varianter i rutatlasen (rutor.png), växlas i schackmönster.
const MARKRUTOR := {".": [0, 1], "i": [2, 3], "g": [4, 5], "a": [6, 6], "d": [7, 7], "p": [8, 9], "w": [10, 11]}
## Marktyper som inte går att gå på.
const MARK_HINDER := ["w"]
## Objekt: tecken -> sprite (ankare). Blockerade rutor utan egen bild listas i OBJEKT_HINDER.
const OBJEKT_SPRITES := {"K": "vaktkur", "T": "gran", "t": "gran_liten", "L": "lykta", "C": "bil",
	"H": "hus_rod", "I": "hus_gul", "A": "lada", "R": "sten", "U": "buske", "M": "brevlada", "Q": "lastbil"}
const OBJEKT_HINDER := ["F", "S", "K", "T", "t", "L", "C", "H", "h", "I", "i", "A", "j", "R", "U", "M",
	"Q", "q"]
const RIKTNINGAR := [[Vector2i(1, 0), "xp"], [Vector2i(-1, 0), "xn"], [Vector2i(0, 1), "yp"], [Vector2i(0, -1), "yn"]]

var mark: TileMapLayer
var dekal_lager: Node2D
var objekt_lager: Node2D
var astar := AStarGrid2D.new()        ## för spelaren (grinden går att passera)
var astar_npc := AStarGrid2D.new()    ## för övriga figurer (grinden stängd)
var storlek := Vector2i.ZERO
var skyddsomrade := Rect2i()
var invid_avstand := 3
## Stridsparskamraten följer spelaren när detta är sant.
var kamrat_folj := false
var _spar: Array[Vector2i] = []
var anchors: Dictionary = {}
var punkter: Dictionary = {}
var spelare: Aktor
var kollega: Aktor
var npcer: Dictionary = {}
var interaktion_aktiv := false
var kamera: Camera2D

var _spelar_start := Vector2i.ZERO
var _kollega_start := Vector2i.ZERO
var _hover: Sprite2D
var _malmarkor: Sprite2D
var _larmmarkor: Sprite2D
var _utrop: Sprite2D
var _larm_npc := ""
var _grindceller: Array[Vector2i] = []
var _bom_stangd: Array[Sprite2D] = []
var _bom_uppe: Sprite2D
var _grind_oppen := false
var _mark_hinder: Array[Vector2i] = []

const GRIND_AVSTAND := 2  ## grinden öppnas när spelaren är så här nära (rutor)


func bygg(karta: Dictionary) -> void:
	anchors = Datafil.las_json("res://assets/gfx/anchors.json")
	punkter = karta.get("punkter", {})
	var mark_rader: Array = karta.get("mark", [])
	var obj_rader: Array = karta.get("objekt", [])
	storlek = Vector2i(str(mark_rader[0]).length(), mark_rader.size())
	var so: Array = karta.get("skyddsomrade", [0, 0, 0, 0])
	skyddsomrade = Rect2i(int(so[0]), int(so[1]), int(so[2]) - int(so[0]) + 1, int(so[3]) - int(so[1]) + 1)
	invid_avstand = int(karta.get("invid_avstand", 3))

	_skapa_mark(mark_rader)
	dekal_lager = Node2D.new()
	add_child(dekal_lager)
	objekt_lager = Node2D.new()
	objekt_lager.y_sort_enabled = true
	add_child(objekt_lager)

	astar.region = Rect2i(Vector2i.ZERO, storlek)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	astar_npc.region = astar.region
	astar_npc.cell_size = astar.cell_size
	astar_npc.diagonal_mode = astar.diagonal_mode
	astar_npc.default_compute_heuristic = astar.default_compute_heuristic
	astar_npc.default_estimate_heuristic = astar.default_estimate_heuristic
	astar_npc.update()

	_skapa_objekt(obj_rader)
	_skapa_figurer()
	_skapa_markorer()
	_skapa_kamera()

	var skymning := CanvasModulate.new()
	# Dagsljus i scenarier med "dagsljus": true, natt med "natt": true, annars skymning.
	skymning.color = Color(1, 1, 1) if bool(Spel.scenario.get("dagsljus", false)) else Color(0.80, 0.84, 0.97)
	# Natt: mörkare och blåare.
	if bool(Spel.scenario.get("natt", false)):
		skymning.color = Color(0.58, 0.64, 0.86)
	add_child(skymning)


# ------------------------------------------------------------------ Mark --

func _skapa_mark(rader: Array) -> void:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = RUTSTORLEK
	var kalla := TileSetAtlasSource.new()
	kalla.texture = load("res://assets/gfx/rutor.png")
	kalla.texture_region_size = RUTSTORLEK
	for i in int(kalla.texture.get_width() / float(RUTSTORLEK.x)):
		kalla.create_tile(Vector2i(i, 0))
	ts.add_source(kalla, 0)

	mark = TileMapLayer.new()
	mark.tile_set = ts

	# Kartplattans sidor (dioramakänsla) ritas under rutorna.
	var v := mark.map_to_local(Vector2i(0, storlek.y - 1)) + Vector2(-RUTSTORLEK.x / 2.0, 0)
	var n := mark.map_to_local(Vector2i(storlek.x - 1, storlek.y - 1)) + Vector2(0, RUTSTORLEK.y / 2.0)
	var h := mark.map_to_local(Vector2i(storlek.x - 1, 0)) + Vector2(RUTSTORLEK.x / 2.0, 0)
	var djup := Vector2(0, 14)
	var vanster := Polygon2D.new()
	vanster.polygon = PackedVector2Array([v, n, n + djup, v + djup])
	vanster.color = Color8(70, 52, 38)
	add_child(vanster)
	var hoger := Polygon2D.new()
	hoger.polygon = PackedVector2Array([n, h, h + djup, n + djup])
	hoger.color = Color8(52, 38, 28)
	add_child(hoger)

	add_child(mark)
	for y in storlek.y:
		var rad := str(rader[y])
		for x in storlek.x:
			var varianter: Array = MARKRUTOR.get(rad[x], [0, 1])
			mark.set_cell(Vector2i(x, y), 0, Vector2i(int(varianter[(x + y) % 2]), 0))
			if rad[x] in MARK_HINDER:
				_mark_hinder.append(Vector2i(x, y))


# ---------------------------------------------------------------- Objekt --

func _skapa_objekt(rader: Array) -> void:
	var staket: Dictionary = {}
	var skyltar: Array[Vector2i] = []
	var byggceller: Array[Vector2i] = []
	for y in storlek.y:
		var rad := str(rader[y])
		for x in storlek.x:
			var c := Vector2i(x, y)
			var tecken := rad[x]
			match tecken:
				"F", "S":
					staket[c] = "F"
					if tecken == "S":
						skyltar.append(c)
				"G":
					staket[c] = "G"
				"B":
					byggceller.append(c)
				"L":
					_sprite("lykta", c)
					var ljus := _sprite("ljus", c, dekal_lager)
					var mat := CanvasItemMaterial.new()
					mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
					ljus.material = mat
				"P":
					_spelar_start = c
				"V":
					_kollega_start = c
			if OBJEKT_SPRITES.has(tecken) and tecken != "L":
				objektsprites[c] = _sprite(str(OBJEKT_SPRITES[tecken]), c)
			if tecken in OBJEKT_HINDER or c in _mark_hinder:
				astar.set_point_solid(c)
			if tecken in OBJEKT_HINDER or tecken == "G" or c in _mark_hinder:
				astar_npc.set_point_solid(c)
			if tecken == "G":
				_grindceller.append(c)

	for c: Vector2i in staket:
		var typ: String = staket[c]
		if typ == "F":
			_sprite("staket_stolpe", c)
		for r in RIKTNINGAR:
			var granne: Vector2i = c + r[0]
			if staket.has(granne):
				var bit := _sprite(("bom_" if typ == "G" else "staket_") + str(r[1]), c)
				if typ == "G":
					_bom_stangd.append(bit)
	for c in skyltar:
		skyltsprites[c] = _sprite("skylt", c)

	# Bommens gångjärn: grindrutan med störst y (bilden förutsätter grind längs y-axeln).
	if not _grindceller.is_empty():
		var led := _grindceller[0]
		for c in _grindceller:
			if c.y > led.y:
				led = c
		_sprite("bom_fot", led)
		_bom_uppe = _sprite("bom_uppe", led)
		_bom_uppe.visible = false

	_placera_skyddsobjekt(byggceller)


## Ställer ut skyddsobjektet (Spel.objekttyp) på objektytan (B-rutorna i kartan).
func _placera_skyddsobjekt(yta: Array[Vector2i]) -> void:
	if yta.is_empty():
		return
	var minsta := yta[0]
	var ankare := yta[0]
	for c in yta:
		minsta = Vector2i(mini(minsta.x, c.x), mini(minsta.y, c.y))
		if c.x + c.y > ankare.x + ankare.y or (c.x + c.y == ankare.x + ankare.y and c.x > ankare.x):
			ankare = c
	var hinder: Array[Vector2i] = []
	match Spel.objekttyp:
		"lastbil":
			_sprite("lastbil", minsta + Vector2i(3, 1))
			for dx in 4:
				hinder.append(minsta + Vector2i(dx, 1))
		"radiomast":
			_sprite("radiomast", minsta + Vector2i(1, 1))
			_sprite("teknikbod", minsta + Vector2i(3, 2))
			hinder.append(minsta + Vector2i(1, 1))
			hinder.append(minsta + Vector2i(3, 2))
		"vapenforrad":
			_sprite("vapenforrad", ankare)
			hinder.assign(yta)
		_:
			_sprite("byggnad", ankare)
			hinder.assign(yta)
	for c in hinder:
		astar.set_point_solid(c)
		astar_npc.set_point_solid(c)


func _sprite(namn: String, c: Vector2i, lager: Node2D = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/gfx/%s.png" % namn)
	s.centered = false
	var a: Array = anchors.get(namn, [0, 0])
	s.offset = -Vector2(float(a[0]), float(a[1]))
	s.position = cell_pos(c)
	(lager if lager else objekt_lager).add_child(s)
	return s


func _skapa_figurer() -> void:
	spelare = _ny_aktor("vakt", _spelar_start)
	spelare.framme.connect(_pa_spelare_framme)
	kollega = _ny_aktor("vakt", _kollega_start)
	kollega.hastighet = spelare.hastighet * 1.1
	_spar = [spelare.cell]
	spelare.steg.connect(_pa_spelare_steg)
	kollega.vand_mot(kollega.position + Vector2(-10, 0))


func _pa_spelare_framme() -> void:
	_malmarkor.visible = false
	spelare_framme.emit()


func _pa_spelare_steg(c: Vector2i) -> void:
	_spar.append(c)
	if _spar.size() > 12:
		_spar.remove_at(0)


func _ny_aktor(bas: String, start: Vector2i) -> Aktor:
	var a := Aktor.new()
	a.setup(self, bas, start, anchors.get(bas + "_0", [4, 12]))
	objekt_lager.add_child(a)
	return a


## Byter en figurs bilder (t.ex. till "yxman_ligger").
func byt_bilder(a: Aktor, bas: String) -> void:
	a.byt_bilder(bas, anchors.get(bas + "_0", [4, 12]))


## Lägger en bild på marken under figurerna (t.ex. en blodpöl).
func lagg_dekal(namn: String, c: Vector2i) -> Sprite2D:
	return _sprite(namn, c, dekal_lager)


## Lägger en lös sprite (t.ex. en tappad yxa) på en ruta.
func lagg_foremal(namn: String, c: Vector2i) -> Sprite2D:
	return _sprite(namn, c)


func skapa_npc(npc_id: String, data: Dictionary) -> Aktor:
	var a := _ny_aktor(str(data.get("sprite", "civil")), punkt(data.get("start", [0, 0])))
	a.visible = bool(data.get("synlig_fran_start", false))
	npcer[npc_id] = a
	return a


func _skapa_markorer() -> void:
	_hover = _sprite("markor_hover", Vector2i.ZERO, dekal_lager)
	_hover.visible = false
	_malmarkor = _sprite("markor_mal", Vector2i.ZERO, dekal_lager)
	_malmarkor.visible = false
	_larmmarkor = _sprite("markor_larm", Vector2i.ZERO, dekal_lager)
	_larmmarkor.visible = false
	_utrop = Sprite2D.new()
	_utrop.texture = load("res://assets/gfx/utrop.png")
	_utrop.centered = false
	var ua: Array = anchors.get("utrop", [2, 13])
	_utrop.offset = -Vector2(float(ua[0]), float(ua[1]))
	_utrop.visible = false
	_utrop.z_index = 10
	add_child(_utrop)


func _skapa_kamera() -> void:
	kamera = Camera2D.new()
	kamera.zoom = Vector2(ZOOM, ZOOM)
	# Begränsa kameran till kartan (plus marginal för träd och plattans kant).
	var topp := mark.map_to_local(Vector2i(0, 0))
	var vanster := mark.map_to_local(Vector2i(0, storlek.y - 1))
	var hoger := mark.map_to_local(Vector2i(storlek.x - 1, 0))
	var botten := mark.map_to_local(storlek - Vector2i.ONE)
	kamera.limit_left = int(vanster.x - RUTSTORLEK.x * 2)
	kamera.limit_right = int(hoger.x + RUTSTORLEK.x * 2)
	kamera.limit_top = int(topp.y - 90)
	kamera.limit_bottom = int(botten.y + 60)
	kamera.position_smoothing_enabled = true
	kamera.position_smoothing_speed = 5.0
	kamera.position = spelare.position if spelare else Vector2.ZERO
	add_child(kamera)
	kamera.make_current()
	kamera.reset_smoothing()


# --------------------------------------------------------------- Hjälp --

func cell_pos(c: Vector2i) -> Vector2:
	return mark.position + mark.map_to_local(c)


## En plats: namn på en punkt i kartfilen ("sjo_pilot") eller [x, y].
func punkt(v: Variant) -> Vector2i:
	if v is String:
		return Datafil.cell(punkter.get(v, [0, 0]))
	return Datafil.cell(v)


## Rutan under en position i världen.
func cell_av(pos: Vector2) -> Vector2i:
	return mark.local_to_map(mark.to_local(pos))


func cell_vid_mus() -> Vector2i:
	return mark.local_to_map(mark.get_local_mouse_position())


func ar_fri(c: Vector2i) -> bool:
	return astar.region.has_point(c) and not astar.is_point_solid(c)


func ar_inom_skyddsomrade(c: Vector2i) -> bool:
	return skyddsomrade.has_point(c)


## "pa" = på/inom skyddsobjektet, "invid" = invid (bedömningsfråga), annars "utanfor".
## Avstånd i rutor från cellen till skyddsområdet (0 = på objektet).
func avstand_till_objekt(c: Vector2i) -> int:
	if skyddsomrade.has_point(c):
		return 0
	var dx := maxi(maxi(skyddsomrade.position.x - c.x, c.x - skyddsomrade.end.x + 1), 0)
	var dy := maxi(maxi(skyddsomrade.position.y - c.y, c.y - skyddsomrade.end.y + 1), 0)
	return maxi(dx, dy)


func zon(c: Vector2i) -> String:
	if skyddsomrade.has_point(c):
		return "pa"
	var dx := maxi(maxi(skyddsomrade.position.x - c.x, c.x - skyddsomrade.end.x + 1), 0)
	var dy := maxi(maxi(skyddsomrade.position.y - c.y, c.y - skyddsomrade.end.y + 1), 0)
	return "invid" if maxi(dx, dy) <= invid_avstand else "utanfor"


## Närmaste fria ruta inom radie 3 från mal, i första hand nära spelaren.
func narmaste_fria(mal: Vector2i, fran: Vector2i) -> Vector2i:
	if ar_fri(mal):
		return mal
	var bast := Vector2i(-1, -1)
	var bast_poang := INF
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c := mal + Vector2i(dx, dy)
			if not ar_fri(c):
				continue
			var poang := Vector2(c - mal).length() * 10.0 + Vector2(c - fran).length()
			if poang < bast_poang:
				bast_poang = poang
				bast = c
	return bast


func vag(fran: Vector2i, till: Vector2i, npc := false) -> Array[Vector2i]:
	var a := astar_npc if npc else astar
	if not a.region.has_point(till) or a.is_point_solid(till):
		return []
	return a.get_id_path(fran, till)


func ga_till(c: Vector2i) -> bool:
	var v := vag_mot(spelare.cell, c)
	if v.is_empty():
		return false
	var mal: Vector2i = v[v.size() - 1]
	_malmarkor.position = cell_pos(mal)
	_malmarkor.visible = mal != spelare.cell
	spelare.ga_langs(v)
	return true


## Väg till mal, eller till närmaste nåbara ruta (inom 3 rutor) om mal är blockerad
## eller ligger på andra sidan staketet.
func vag_mot(fran: Vector2i, mal: Vector2i, npc := false) -> Array[Vector2i]:
	var a := astar_npc if npc else astar
	var kandidater: Array = []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c := mal + Vector2i(dx, dy)
			if a.region.has_point(c) and not a.is_point_solid(c):
				kandidater.append([Vector2(c - mal).length() * 10.0 + Vector2(c - fran).length(), c])
	kandidater.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in kandidater:
		var v := vag(fran, k[1], npc)
		if not v.is_empty():
			return v
	return []


func avstand(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func flytta_npc(npc_id: String, till: Vector2i) -> void:
	var n: Aktor = npcer.get(npc_id)
	if n == null:
		return
	n.ga_langs(vag_mot(n.cell, till, true))


## Bommen fälls upp automatiskt när spelaren närmar sig grinden.
func _uppdatera_grind() -> void:
	if spelare == null or _grindceller.is_empty():
		return
	var nara := false
	for c in _grindceller:
		if avstand(spelare.cell, c) <= GRIND_AVSTAND or (kollega and avstand(kollega.cell, c) <= GRIND_AVSTAND):
			nara = true
			break
	if nara == _grind_oppen:
		return
	_grind_oppen = nara
	for bit in _bom_stangd:
		bit.visible = not nara
	if _bom_uppe:
		_bom_uppe.visible = nara


## Kamraten går till rutan bakom spelaren (spelarens förra ruta), eller till
## närmaste fria grannruta om spelaren står still sedan start.
func _uppdatera_kamrat() -> void:
	if not kamrat_folj or kollega == null or kollega.ar_i_rorelse():
		return
	var mal := Vector2i(-1, -1)
	if _spar.size() >= 2:
		mal = _spar[_spar.size() - 2]
	if mal.x < 0 or mal == spelare.cell or not ar_fri(mal):
		mal = _fri_granne(spelare.cell)
	if mal.x < 0 or mal == kollega.cell:
		return
	if avstand(kollega.cell, spelare.cell) <= 1 and not spelare.ar_i_rorelse():
		return
	var v := vag(kollega.cell, mal)
	if v.size() > 1:
		var nasta_steg: Array[Vector2i] = [v[0], v[1]]
		kollega.ga_langs(nasta_steg)


func _fri_granne(c: Vector2i) -> Vector2i:
	var bast := Vector2i(-1, -1)
	var bast_d := INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if n == c or not ar_fri(n):
				continue
			var d := Vector2(n - kollega.cell).length()
			if d < bast_d:
				bast_d = d
				bast = n
	return bast


## Ställer ut ett fordon (sprite) på en ruta och gör rutan till hinder.
## Ljussken på marken (samma som under lyktorna), t.ex. från fönster och dörr.
func lagg_ljussken(c: Vector2i, farg := Color(1.0, 0.85, 0.55), skala := 1.0) -> Sprite2D:
	var ljus := _sprite("ljus", c, dekal_lager)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ljus.material = mat
	ljus.modulate = farg
	ljus.scale = Vector2(skala, skala)
	return ljus


## Objekten på kartan (cell -> sprite), t.ex. för att tända fönstren i en stuga.
var objektsprites: Dictionary = {}


## Byter bild på objektet i cellen (samma förankring). Sant om det fanns ett.
func byt_objektbild(c: Vector2i, namn: String) -> bool:
	var s: Variant = objektsprites.get(c)
	if s == null or not is_instance_valid(s):
		return false
	var ny := _sprite(namn, c)
	(s as Node).queue_free()
	objektsprites[c] = ny
	return true


## Skyltarna på staketet (cell -> sprite), så att en kan skruvas ner och tas.
var skyltsprites: Dictionary = {}


## Tar bort skylten vid cellen (stulen). Sant om det fanns en.
func ta_bort_skylt(c: Vector2i) -> bool:
	var s: Variant = skyltsprites.get(c)
	if s == null or not is_instance_valid(s):
		return false
	(s as Node).queue_free()
	skyltsprites.erase(c)
	return true


func placera_fordon(namn: String, c: Vector2i) -> Sprite2D:
	var s := _sprite(namn, c)
	astar.set_point_solid(c)
	astar_npc.set_point_solid(c)
	return s


func ta_bort_fordon(s: Sprite2D, c: Vector2i) -> void:
	if is_instance_valid(s):
		s.queue_free()
	astar.set_point_solid(c, false)
	astar_npc.set_point_solid(c, false)


func satt_larm(npc_id: String) -> void:
	_larm_npc = npc_id


func _process(_delta: float) -> void:
	if kamera and spelare:
		kamera.position = spelare.position + Vector2(0, -12)
	_uppdatera_grind()
	_uppdatera_kamrat()
	var larm_aktor: Aktor = npcer.get(_larm_npc)
	var visa := larm_aktor != null and larm_aktor.visible
	_larmmarkor.visible = visa
	_utrop.visible = visa and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.7
	if visa:
		var n: Aktor = npcer[_larm_npc]
		_larmmarkor.position = n.position
		_utrop.position = n.position + Vector2(0, -30)


func _unhandled_input(event: InputEvent) -> void:
	if not interaktion_aktiv:
		_hover.visible = false
		return
	if event is InputEventMouseMotion:
		var c := cell_vid_mus()
		_hover.visible = astar.region.has_point(c)
		_hover.position = cell_pos(c)
	elif UiKit.ar_klick(event):
		var c := cell_vid_mus()
		var mus := get_global_mouse_position()
		if kollega and (kollega.cell == c or kollega.traffar(mus)):
			kamrat_klickad.emit()
			get_viewport().set_input_as_handled()
			return
		for id: String in npcer:
			var n: Aktor = npcer[id]
			if n.visible and (n.cell == c or n.traffar(mus)):
				npc_klickad.emit(id)
				get_viewport().set_input_as_handled()
				return
		if astar.region.has_point(c):
			ga_till(c)
			get_viewport().set_input_as_handled()
