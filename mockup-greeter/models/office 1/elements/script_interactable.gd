extends StaticBody3D

@export var interactable_name := "white board"
@export var description := "A writable panel used for quick notes, drawings, and visual ideas."

func is_interactable():
	return true
