class_name VridOverlay
extends Control
## Ber spelaren vrida enheten till liggande läge (pekskärmar i stående läge).


func _ready() -> void:
	UiKit.helskarm(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := UiKit.ruta_farg(UiKit.BG, Vector2.ZERO)
	UiKit.helskarm(bg)
	add_child(bg)
	var mitt := CenterContainer.new()
	UiKit.helskarm(mitt)
	add_child(mitt)
	var v := UiKit.vbox(16)
	mitt.add_child(v)
	# en liggande "telefon" som symbol
	var tel := UiKit.panel(UiKit.GRON, Color(0, 0, 0, 0), 0, 0)
	tel.custom_minimum_size = Vector2(110, 60)
	tel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(tel)
	var t := UiKit.titel("Vrid enheten", 30, UiKit.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var u := UiKit.etikett("Spelet spelas i liggande läge.", 24, UiKit.DAMPAD)
	u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(u)
	visible = false


func _process(_delta: float) -> void:
	var s := get_viewport_rect().size
	visible = UiKit.kompakt and s.y > s.x
