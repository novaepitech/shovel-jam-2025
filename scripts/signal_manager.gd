# res://scripts/SignalManager.gd
# This script does not need to inherit from Node.
# It's just a container for our global signals.
extends Node

# We declare the signal. It can carry a value (the new speed).
signal speed_change_requested(new_speed: float)
