extends Control
@onready var button_click: AudioStreamPlayer = $ButtonClick
@onready var tutorial_overlay: ColorRect = $TutorialOverlay
@onready var screenshot_display: TextureRect = $TutorialOverlay/ScreenshotDisplay
@onready var description_label: Label = $TutorialOverlay/DescriptionLabel
var current_page = 0
var tutorial_pages = [
	{
		"image": preload("res://assets/Tutorial/Screenshot 2026-03-13 230731.png"), 
		"text": "1. Make Trenches Using Left Click."
	},
	{
		"image": preload("res://assets/Tutorial/Screenshot 2026-03-13 230747.png"), 
		"text": "2. Connect Them To the Water Source To Access Water"
	},
	{
		"image": preload("res://assets/Tutorial/Screenshot 2026-03-13 230757.png"), 
		"text": "3. Disconnect Using Right Click ."
	},
	{
		"image": preload("res://assets/Tutorial/Screenshot 2026-03-13 230818.png"), 
		"text": "4. Connect Them To the ScareCrows to power them and reflect light"
	},
	{
		"image": preload("res://assets/Tutorial/Screenshot 2026-03-13 230832.png"), 
		"text": "5. Click On the scarecrows to rotate them and kill pests using sunlight"
	},
	{
		"image": preload("res://assets/Tutorial/Screenshot 2026-03-13 230847.png"), 
		"text": "6. Give Water and sunlight access to the crop to grow it"
	},
	{
		"image": preload("res://assets/Tutorial/Screenshot 2026-03-13 230901.png"), 
		"text": "End Turns using spacebar or end turn button to grow crop"
	}
]
func _ready():
	# Make sure the overlay is hidden when the game starts
	tutorial_overlay.visible = false
	update_tutorial_display()


func update_tutorial_display():
	# Update the image and text based on the current page
	var page_data = tutorial_pages[current_page]
	screenshot_display.texture = page_data["image"]
	description_label.text = page_data["text"]

func _on_play_pressed() -> void:
	button_click.play()
	await get_tree().create_timer(1).timeout
	get_tree().change_scene_to_file("res://scenes/level_01.tscn")


func _on_quit_pressed() -> void:
	button_click.play()
	await get_tree().create_timer(1).timeout
	get_tree().quit()


func _on_tutorial_button_pressed() -> void:
	current_page = 0 # Always start at page 1
	update_tutorial_display()
	tutorial_overlay.visible = true


func _on_next_pressed() -> void:
	if current_page < tutorial_pages.size() - 1:
		current_page += 1
		update_tutorial_display()


func _on_previous_pressed() -> void:
	if current_page > 0:
		current_page -= 1
		update_tutorial_display()


func _on_close_pressed() -> void:
	tutorial_overlay.visible = false
