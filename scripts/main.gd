# Root scene — registers the holder and kicks off the title scene.
extends Node2D

var holder: Node2D = null

func _ready() -> void:
	holder = Node2D.new()
	holder.name = "Holder"
	add_child(holder)
	Game.register_holder(holder)
	Game.scene_change_to("title")
