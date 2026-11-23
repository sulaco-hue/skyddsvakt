extends Node
## Autoload "Musik": spelar bakgrundsmusiken som en slinga. M slår av/på.

signal andrad(pa: bool)

const SOKVAG := "res://assets/ljud/grindpostens_marsch.ogg"
const VOLYM_DB := -10.0

var _spelare: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_spelare = AudioStreamPlayer.new()
	_spelare.stream = load(SOKVAG)
	_spelare.volume_db = VOLYM_DB
	add_child(_spelare)
	_spelare.finished.connect(_spelare.play)
	_spelare.play()


func vaxla() -> void:
	_spelare.stream_paused = not _spelare.stream_paused
	andrad.emit(ar_pa())


func ar_pa() -> bool:
	return not _spelare.stream_paused


func _unhandled_input(event: InputEvent) -> void:
	var tangent := event as InputEventKey
	if tangent != null and tangent.pressed and not tangent.echo and tangent.keycode == KEY_M:
		vaxla()
		get_viewport().set_input_as_handled()
