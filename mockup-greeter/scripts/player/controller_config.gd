# res://scripts/config/controller_config.gd
## Controller Configuration - Centralized input and feature management
##
## Add or remove interactions here without modifying proto_controller.gd

class_name ControllerConfig

## Available interactions
enum Interactions {
	INTERACT = 0,
	INTERACT_GLOBAL = 1
}

## Interaction configuration
var interaction_config = {
	Interactions.INTERACT: {
		"enabled": true,
		"input": "interact",
		"distance": 5.0,
		"description": "Interact with objects"
	}
	,
	Interactions.INTERACT_GLOBAL: {
		"enabled": true,
		"input": "interact_global",
		"distance": 0.0,
		"description": "Global interaction with robot"
	}
}

## Check if interaction is enabled
func is_interaction_enabled(interaction: Interactions) -> bool:
	if interaction in interaction_config:
		return interaction_config[interaction].get("enabled", false)
	return false

## Get interaction configuration
func get_interaction_config(interaction: Interactions) -> Dictionary:
	if interaction in interaction_config:
		return interaction_config[interaction]
	return {}

## Get input action for interaction
func get_interaction_input(interaction: Interactions) -> String:
	var config = get_interaction_config(interaction)
	return config.get("input", "")

## Enable interaction
func enable_interaction(interaction: Interactions) -> void:
	if interaction in interaction_config:
		interaction_config[interaction]["enabled"] = true
		print("Interaction enabled: %s" % Interactions.keys()[interaction])

## Disable interaction
func disable_interaction(interaction: Interactions) -> void:
	if interaction in interaction_config:
		interaction_config[interaction]["enabled"] = false
		print("Interaction disabled: %s" % Interactions.keys()[interaction])

## Get all enabled interactions
func get_enabled_interactions() -> Array:
	var enabled = []
	for interaction in Interactions.values():
		if is_interaction_enabled(interaction):
			enabled.append(interaction)
			
	return enabled
