extends StaticBody3D

@export var interactable_name := "lamp"
@export var description := "You can turn off and turn on this lamp with key [0]"

func is_interactable():
	return true
