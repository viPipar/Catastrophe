extends Node2D

var deck_queue: Array[String]  = []

# Layout & aset
var target_card_height: float = 200.0
var card_width: float = 100.0
var card_spacing: float = 70.0
var player_center := Vector2(0, 320)
var dealer_center := Vector2(0, -320)

const CARD_BACK_PATH := "res://assets/Card Deck/Back Card.png"
const CARD_TEXTURE_DIR := "res://assets/Card Deck/"
const RESTART_DELAY_SEC := 2.5  # jeda sebelum round baru
const MAX_LIVES := 5
const DEAL_ANIM_TIME := 0.35
const DEAL_ANIM_EASE := 0.85
const DEAL_ANIM_ROT_MAX := 0.18   # ~10.3° opsional

# ===== Dealer reactions =====
const REACT_FADE_TIME := 0.18
const REACT_SHOW_TIME_WIN := 1.6
const REACT_SHOW_TIME_LOSE := 1.6
const REACT_SHOW_TIME_DRAW := 1.2

const TAUNT_WHEN_WIN := [
	"What a fool!",
	"Fortune smileth upon me, and mocketh thee.",
	"Thou art but a lamb led unto slaughter.",
	"Ha! Thy wit is as frail as thy hand."
]

const ANGRY_WHEN_LOSE := [
	"By the jokers! This cannot be!",
	"Curse this wicked fate!",
	"Thou knave, thou shalt not best me again!",
	"The heavens betray me this day!"
]

const NEUTRAL_WHEN_DRAW := [
	"A draw? ’Tis but a hollow jest",
	"No victor? The game mocketh us both.",
	"So be it, yet the strife endureth.",
	"A stalemate most vexing."
]


# State kartu
var player_cards: Array[Sprite2D] = []
var dealer_cards: Array[Sprite2D] = []
var player_hole_card: Sprite2D = null
var dealer_hole_card: Sprite2D = null

# State ronde/turn
var current_turn := "player"      # "player" / "dealer"
var round_started := false
var player_stood: bool = false
var dealer_stood: bool = false
var game_over: bool = false
var player_lives: int = MAX_LIVES
var dealer_lives: int = MAX_LIVES
var winner: String = ""


# UI
@onready var turn_label: Label = $"Visible_Label/Turn_Label"
@onready var hit_button: Button = $Visible_Buttons/Hit_Button
@onready var stand_button: Button = $Visible_Buttons/Stand_Button
@onready var player_score_label: Label = $Visible_Label/Score_Player
@onready var dealer_score_label: Label = $Visible_Label/Score_Dealer
@onready var life_player: Label = $Visible_Label/Life_Player
@onready var life_dealer: Label = $Visible_Label/Life_Dealer
@onready var deck_anchor: Node2D = $DeckAnchor
@onready var dealer_react_label: Label = $Dialog_Dealer/Label
@onready var anim: AnimationPlayer = $AnimationPlayer
var _react_tween: Tween = null


var ui_locked: bool = false  # kunci sementara saat dealer lagi aksi/animasi
signal game_finished(outcome) # outcome: "win" | "lose" | "push"

signal finished(success: bool)  # success: true/false; data: payload bebas
# ===== Inisialisasi =====
func _ready():
	randomize()

	deck_queue = deck_shuffle()
	await get_tree().create_timer(1).timeout
	start_round()
	_update_turn_label()
	_update_controls()
	_update_lives_labels()


# ===== Util skor =====
func points_visible(cards: Array[Sprite2D]) -> int:
	var total := 0
	var aces := 0

	for c in cards:
		if c.get_meta("facedown") == true:
			continue  # skip kartu yang masih tertutup

		var code: String = c.get_meta("code")
		var rank := code.substr(0, code.length() - 1)

		match rank:
			"J", "Q", "K":
				total += 10
			"A":
				total += 11
				aces += 1
			_:
				total += int(rank)

	# Adjust nilai As supaya gak bust
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1

	return total

func _deck_origin() -> Vector2:
	return deck_anchor.global_position if deck_anchor else Vector2.ZERO

func _render_lives(lives: int) -> String:
	var s := ""
	for i in range(MAX_LIVES):
		s += "●" if i < lives else ""
	return s
	
func _update_lives_labels() -> void:
	life_player.text = _render_lives(player_lives)
	life_dealer.text = _render_lives(dealer_lives)

func calculate_points(cards: Array[Sprite2D]) -> int:
	var total := 0
	var aces := 0

	for c in cards:
		var code: String = c.get_meta("code")        # contoh: "10S", "AD"
		var rank := code.substr(0, code.length() - 1) # buang 1 huruf suit

		match rank:
			"J", "Q", "K":
				total += 10
			"A":
				total += 11
				aces += 1
			_:
				total += int(rank)

	# turunkan nilai A dari 11 -> 1 jika perlu biar tidak bust
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1

	return total

func format_score_label(cards: Array[Sprite2D]) -> String:
	var total_faceup := 0
	var aces_faceup := 0
	var has_facedown := false

	for c in cards:
		if c.get_meta("facedown") == true:
			has_facedown = true
			continue

		var code: String = c.get_meta("code")
		var rank := code.substr(0, code.length() - 1)
		match rank:
			"J", "Q", "K":
				total_faceup += 10
			"A":
				total_faceup += 11
				aces_faceup += 1
			_:
				total_faceup += int(rank)

	while total_faceup > 21 and aces_faceup > 0:
		total_faceup -= 10
		aces_faceup -= 1

	if has_facedown:
		return "? + %d" % total_faceup
	else:
		return str(total_faceup)

func update_score_labels():
	player_score_label.text = format_score_label(player_cards)
	dealer_score_label.text = format_score_label(dealer_cards)


# ===== Kontrol tombol =====
func _update_controls() -> void:
	var can_press := (current_turn == "player") and (not player_stood) and (not ui_locked) and (not game_over)
	hit_button.disabled = not can_press
	stand_button.disabled = not can_press

func _update_turn_label():
	if player_stood and dealer_stood:
		turn_label.text = "Reveal"
	else:
		turn_label.text = "%s turn" % current_turn.capitalize()

func _swap_turn():
	if current_turn == "player":
		if dealer_stood:
			# dealer sudah stand → tetap di player
			_update_turn_label()
			_update_controls()
			return
		current_turn = "Joker"
	else:
		if player_stood:
			# player sudah stand → tetap di dealer
			_update_turn_label()
			_update_controls()
			return
		current_turn = "player"

	_update_turn_label()
	_update_controls()

# ===== Dealer AI =====
func dealer_should_hit(points: int) -> bool:
	if points < 15:
		return true                   # <14 pasti hit
	elif points <= 17:
		return randf() < 0.5          # 40% chance hit untuk 14–17
	else:
		return randf() < 0.3          # 20% chance hit untuk >17

# ===== Deck =====
func deck_shuffle() -> Array[String]:
	var ranks: Array[String] = ["2","3","4","5","6","7","8","9","10","J","Q","K","A"]
	var suits: Array[String] = ["H","D","S","C"]
	var deck: Array[String] = []
	for s in suits:
		for r in ranks:
			deck.append("%s%s" % [r, s])
	deck.shuffle()
	return deck

func _draw_from_deck() -> String:
	if deck_queue.is_empty():
		push_warning("Deck empty, reshuffling…")
		deck_queue = deck_shuffle()
		if deck_queue.is_empty():
			push_error("No cards available.")
			return ""
	var raw = deck_queue.pop_front()
	return raw if raw != null else ""

# ===== Buat sprite kartu =====
func _make_card_sprite(card_code: String, face_down: bool) -> Sprite2D:
	var spr := Sprite2D.new()
	var tex: Texture2D = load(CARD_BACK_PATH) if face_down else load(CARD_TEXTURE_DIR + "%s.png" % card_code)
	spr.texture = tex
	var s: float = target_card_height / float(tex.get_height())
	spr.scale = Vector2(s, s)
	spr.set_meta("code", card_code)
	spr.set_meta("facedown", face_down)
	return spr

# ===== Deal kartu (dengan opsi paksa face up/down) =====
func _deal_to_with_anim(target: String, face_down: bool=false, force: bool=false) -> void:
	var code := _draw_from_deck()
	if code == "":
		return

	# Tentukan apakah kartu ini hole (tertutup) atau tidak
	var is_first_for_side := player_cards.is_empty() if target == "player" else dealer_cards.is_empty()
	var final_face_down := face_down if force else is_first_for_side

	# 1) Buat kartu asli (untuk logika/score), tapi sembunyikan dulu
	var real := _make_card_sprite(code, final_face_down)
	add_child(real)

	if target == "player":
		player_cards.append(real)
		_relayout(player_cards, player_center)
		if final_face_down:
			player_hole_card = real
	else:
		dealer_cards.append(real)
		_relayout(dealer_cards, dealer_center)
		if final_face_down:
			dealer_hole_card = real

	# Posisi akhir slot kartu (sesudah relayout)
	var final_pos := real.position
	var final_scale := real.scale
	var final_rot := 0.0

	# Sembunyikan kartu asli dulu supaya yang terlihat cuma ghost
	real.visible = false

	# 2) Siapkan ghost (sprite sementara yang dianimasikan)
	var ghost := Sprite2D.new()
	ghost.texture = load(CARD_BACK_PATH) if final_face_down else load(CARD_TEXTURE_DIR + "%s.png" % code)
	# Biar transisi scale-nya enak, mulai dari sedikit lebih kecil:
	var start_scale := final_scale * 0.8
	ghost.scale = start_scale
	ghost.rotation = randf_range(-DEAL_ANIM_ROT_MAX, DEAL_ANIM_ROT_MAX)
	add_child(ghost)

	# Mulai dari DeckAnchor (global), tapi karena parent sama-sama Node2D root, cukup local:
	ghost.position = _deck_origin()

	# 3) Tween gerak + scale + rotasi halus
	var tw := get_tree().create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ghost, "position", final_pos, DEAL_ANIM_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(ghost, "scale", final_scale, DEAL_ANIM_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(ghost, "rotation", final_rot, DEAL_ANIM_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw.finished

	# 4) Hapus ghost, tampilkan kartu asli
	ghost.queue_free()
	real.scale = final_scale * 1.1
	var t3 := get_tree().create_tween()
	t3.tween_property(real, "scale", final_scale, 0.1)
	real.visible = true

	# Update skor/UI (kartu asli sudah di tempat)
	update_score_labels()
	print("Dealt(anim) to %s: %s%s" % [target, code, " (facedown)" if final_face_down else ""])

# ===== Layout rata tengah =====
func _relayout(list: Array[Sprite2D], center: Vector2):
	if list.is_empty():
		return
	var w: float = list[0].texture.get_width() * list[0].scale.x
	var n := list.size()
	var total_w: float = n * w + (n - 1) * card_spacing
	var start_x: float = center.x - total_w / 2.0 + w / 2.0
	for i in range(n):
		list[i].position = Vector2(start_x + i * (w + card_spacing), center.y)

# ===== Reveal =====
func _reveal_card(s: Sprite2D):
	if s != null and s.get_meta("facedown") == true:
		var code: String = s.get_meta("code")
		s.texture = load(CARD_TEXTURE_DIR + "%s.png" % code)
		s.set_meta("facedown", false)

func _auto_restart_after_delay() -> void:
	ui_locked = true
	_update_controls()
	await get_tree().create_timer(RESTART_DELAY_SEC).timeout
	start_round()
	_update_turn_label()
	_update_controls()

func _evaluate_and_finish_round() -> void:
	# semua kartu sudah face-up sekarang
	var p := calculate_points(player_cards)
	var d := calculate_points(dealer_cards)

	var msg := ""
	var lose := "none"  # "player" / "dealer" / "none"
	# Aturan bust: >21 kalah
	if p > 21 and d > 21:
		msg = "Both bust — Draw"
		lose = "none"
	elif p > 21:
		msg = "Player bust — Joker wins"
		lose = "player"
	elif d > 21:
		msg = "Joker bust — Player wins"
		lose = "Joker"
	else:
		if p > d:
			msg = "Player wins (%d VS %d)" % [p, d]
			lose = "Joker"
		elif d > p:
			msg = "Joker wins (%d VS %d)" % [d, p]
			lose = "player"
		else:
			msg = "Draw (%d = %d)" % [p, d]
			lose = "none"

		# Terapkan pengurangan nyawa
	if lose == "player":
		player_lives = max(player_lives - 1, 0)
		_react_mock()
	elif lose == "Joker":
		dealer_lives = max(dealer_lives - 1, 0)
		_react_angry()
	else:
		_react_neutral()
	
		# Tampilkan hasil di turn_label + update tampilan nyawa
	turn_label.text = msg
	_update_lives_labels()
	# Cek akhir match?
	
	if player_lives == 0 or dealer_lives == 0:
		winner = "Joker" if player_lives == 0 else "Player"
		turn_label.text = "%s wins the match!" % winner
		ui_locked = true
		_update_controls()
		buff_or_debuff()
		#await get_tree().create_timer(RESTART_DELAY_SEC).timeout
		#_reset_match()         # reset nyawa & start ronde baru
	else:
		# lanjut ronde baru otomatis
		ui_locked = true
		_update_controls()
		await get_tree().create_timer(RESTART_DELAY_SEC).timeout
		start_round()
		ui_locked = false
		_update_turn_label()
		_update_controls()
	
func reveal_all_if_both_stand() -> void:
	if player_stood and dealer_stood:
		for c in player_cards: _reveal_card(c)
		for c in dealer_cards: _reveal_card(c)
		_update_turn_label()
		update_score_labels()
		await _evaluate_and_finish_round() 

# ===== Start/Reset Round =====
func start_round() -> void:
	# bersih-bersih
	for c in player_cards: c.queue_free()
	for c in dealer_cards: c.queue_free()
	player_cards.clear(); dealer_cards.clear()
	player_hole_card = null; dealer_hole_card = null
	player_stood = false; dealer_stood = false
	game_over = false
	ui_locked = false
	current_turn = "player"
	_update_turn_label()
	_update_controls()
	if dealer_react_label:
		dealer_react_label.text = ""
		dealer_react_label.visible = false
	
	if deck_queue.is_empty():
		deck_queue = deck_shuffle()

	# hole cards (keduanya tertutup, dipaksa)
	_deal_to_with_anim("player", true, true)
	_deal_to_with_anim("Joker", true, true)

	_update_turn_label()
	_update_controls()

func reset_round():
	start_round()

func _reset_match() -> void:
	player_lives = MAX_LIVES
	dealer_lives = MAX_LIVES
	_update_lives_labels()
	game_over = false
	ui_locked = false
	start_round()
	_update_turn_label()
	_update_controls()

# ===== Dealer actions =====
# 1 aksi dealer: hit TERBUKA sekali atau stand, lalu selesai (dipakai setelah player HIT)
func dealer_take_one_action() -> void:
	if dealer_stood:
		return
	await get_tree().create_timer(0.6).timeout  # delay kecil (opsional)
	var d_vis := calculate_points(dealer_cards)
	if dealer_should_hit(d_vis):
		# dealer hit TERBUKA (pakai force untuk pastikan terbuka)
		_deal_to_with_anim("Joker", false, true)
		update_score_labels()
		
		#AUTOBUST
		d_vis = points_visible(dealer_cards)
		if d_vis > 21:
			dealer_stood = true                # dealer bust → stand & kalah
	else:
		dealer_stood = true
	_swap_turn()
	_update_turn_label()
	_update_controls()

# Dealer lanjut sampai stand (dipakai setelah player STAND)
func dealer_take_until_stand() -> void:
	if dealer_stood:
		return
	while not dealer_stood:
		await get_tree().create_timer(0.6).timeout  # delay antar aksi
		var d_vis := calculate_points(dealer_cards)
		if dealer_should_hit(d_vis):
			_deal_to_with_anim("Joker", false, true)  # selalu TERBUKA
			update_score_labels()
			
			d_vis = points_visible(dealer_cards)
			if d_vis > 21:
				dealer_stood = true
		else:
			dealer_stood = true
		_update_turn_label()
		_update_controls()

# ===== Buttons =====
func _on_restart_pressed() -> void:
	reset_round()

# Player HIT: kartu TERBUKA, lalu dealer 1 aksi
func _on_hit_button_pressed() -> void:
	if current_turn != "player" or player_stood:
		return
	# Player HIT TERBUKA (pakai force biar pasti terbuka)
	_deal_to_with_anim("player", false, true)
	update_score_labels()
	
	var p_vis := points_visible(player_cards)
	if p_vis > 21:
		player_stood = true
		dealer_stood = true          # dealer menang otomatis; tak perlu aksi lagi
		reveal_all_if_both_stand()   # ini akan evaluate & game over
		return
		
	# Pindah ke dealer 1 aksi
	_swap_turn()
	ui_locked = true
	_update_turn_label()
	_update_controls()
	
	await dealer_take_one_action()

	# Setelah dealer aksi, jika dealer belum stand -> balik ke player
	if not dealer_stood:
		current_turn = "player"
	ui_locked = false
	_update_turn_label()
	_update_controls()
	update_score_labels()
	reveal_all_if_both_stand()

# Player STAND: dealer bebas jalan sampai stand

func _on_stand_button_pressed() -> void:
	if current_turn != "player" or player_stood:
		return
	player_stood = true

	_swap_turn()
	ui_locked = true
	_update_turn_label()
	_update_controls()
	update_score_labels()

	await dealer_take_until_stand()

	ui_locked = false
	_update_turn_label()
	_update_controls()
	update_score_labels()

	reveal_all_if_both_stand()

func buff_or_debuff():
	if winner == "Joker":
		emit_signal("game_finished", "lose")
		print("kontol")
		await get_tree().create_timer(3).timeout
		anim.play("fade_in")
		await get_tree().create_timer(1).timeout
		get_tree().change_scene_to_file("res://scene/main menu.tscn")
	if winner == "Player":
		emit_signal("game_finished", "win")
		print("yessir")
		await get_tree().create_timer(3).timeout
		anim.play("fade_in")
		await get_tree().create_timer(1).timeout
		get_tree().change_scene_to_file("res://scene/buff_select.tscn")



func _on_finish_button_pressed() -> void:
	if winner == "Joker":
		emit_signal("game_finished", "lose")
		print("kontol")
	if winner == "Player":
		emit_signal("game_finished", "win")
		print("yessir")
	anim.play("fade_in")
	await get_tree().create_timer(1).timeout
	get_tree().change_scene_to_file("res://scene/main menu.tscn")

func _pick(arr: Array) -> String:
	if arr.is_empty():
		return ""
	return arr[randi() % arr.size()]

func _show_react(text: String, hold_time: float) -> void:
	if dealer_react_label == null:
		return

	# Matikan tween sebelumnya kalau masih jalan
	if _react_tween and _react_tween.is_running():
		_react_tween.kill()

	dealer_react_label.text = text
	dealer_react_label.modulate.a = 0.0
	dealer_react_label.visible = true

	# Fade-in
	_react_tween = get_tree().create_tween()
	_react_tween.tween_property(dealer_react_label, "modulate:a", 1.0, REACT_FADE_TIME)
	await _react_tween.finished

	# Tahan
	await get_tree().create_timer(hold_time).timeout

	# Fade-out
	_react_tween = get_tree().create_tween()
	_react_tween.tween_property(dealer_react_label, "modulate:a", 0.0, REACT_FADE_TIME)
	await _react_tween.finished

	dealer_react_label.visible = false
	
func _react_mock() -> void:
	await _show_react(_pick(TAUNT_WHEN_WIN), REACT_SHOW_TIME_WIN)

func _react_angry() -> void:
	await _show_react(_pick(ANGRY_WHEN_LOSE), REACT_SHOW_TIME_LOSE)

func _react_neutral() -> void:
	await _show_react(_pick(NEUTRAL_WHEN_DRAW), REACT_SHOW_TIME_DRAW)
