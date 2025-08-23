extends Sprite2D

# Set these to match your spritesheet
const CARD_WIDTH = 48
const CARD_HEIGHT = 64
const COLUMNS = 15
const SUITS = ["H", "D", "S", "C"]  # Top to bottom (rows)
const RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]  # Left to right (columns)\

@onready var card_spritesheet: Sprite2D = $CardSpritesheet

func show_card(card_name: String):
	var base_texture = preload("res://assets/card/1.2 Poker cards.png")
	var atlas_texture := AtlasTexture.new()
	
	card_name = card_name.strip_edges()
	
	if card_name == "close" :
		atlas_texture.atlas = base_texture
		atlas_texture.region = Rect2i(
		0 * CARD_WIDTH,
		4 * CARD_HEIGHT,
		CARD_WIDTH,
		CARD_HEIGHT
		)  
		$CardSpritesheet.texture = atlas_texture  
		return
		
	if card_name.length() < 2:
		push_error("Card name too short: " + card_name)
		return

	var rank = card_name.substr(0, card_name.length() - 1)  
	var suit = card_name.substr(card_name.length() - 1, 1)  


	var col = RANKS.find(rank)
	var row = SUITS.find(suit)
	if col == -1 or row == -1:
		push_error("Invalid card name: " + card_name)
		return
	
	atlas_texture.atlas = base_texture
	atlas_texture.region = Rect2i(
	col * CARD_WIDTH,
	row * CARD_HEIGHT,
	CARD_WIDTH,
	CARD_HEIGHT
	)  

	$CardSpritesheet.texture = atlas_texture  
