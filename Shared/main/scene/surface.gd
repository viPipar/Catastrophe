extends Node

@onready var blackjack_layer := $BlackjackLayer
@onready var svc := $BlackjackLayer/SubViewportContainer
@onready var sv := $BlackjackLayer/SubViewportContainer/SubViewport
@onready var player := $main_character

var BlackjackScene := preload("res://scene/nyoba_scene.tscn")
@onready var blackjack_instance:= $BlackjackLayer/SubViewportContainer/SubViewport/Blackjack
var blackjack_active := false
var saved_player_state := {}


func _input(event):
	if event.is_action_pressed("flashback") and not blackjack_active:
		_open_blackjack()

func _open_blackjack():
	# 1) Simpan state penting (posisi, velocity, dsb) biar baliknya mulus
	saved_player_state = {
		"position": player.position,
		"velocity": player.get("velocity") if player.has_method("get") else Vector2.ZERO
	}
	 # 2) Nonaktifkan kontrol player & sistem lain yang tak perlu
	player.set_process_input(false)
	player.set_physics_process(false)
	get_tree().paused = true
	# 3) Buat instance blackjack ke dalam SubViewport
	
	# 4) Connect signal hasil
	
	blackjack_instance.connect("game_finished", Callable(self, "_on_blackjack_finished"))

	# 5) Tampilkan overlay + mulai game
	blackjack_layer.visible = true
	blackjack_active = true
	if blackjack_instance.has_method("start_game"):
		blackjack_instance.start_game()

func _on_blackjack_finished(outcome):
	# 1) Sembunyikan overlay
	blackjack_layer.visible = false
	blackjack_active = false

	# 2) Ambil hasil & terapkan efek ke main
	_apply_blackjack_result(outcome)

	# 3) Bersihkan instance blackjack
	if is_instance_valid(blackjack_instance):
		blackjack_instance.queue_free()
	blackjack_instance = null

	# 4) Pulihkan kontrol & state player
	# (kalau pakai pause tree, unpause dulu)
	# get_tree().paused = false
	player.position = saved_player_state.get("position", player.position)
	player.set("velocity", saved_player_state.get("velocity", Vector2.ZERO))
	player.set_process_input(true)
	player.set_physics_process(true)

func _apply_blackjack_result(outcome: String):
	match outcome:
		"win":
			# contoh efek: tambah attack 20% selama 30 dtk
			print("menang rek")
			get_tree().paused = false
		"lose":
			# contoh efek: kurangi HP 10
			print("ajg kalah")
			get_tree().paused = false

	
