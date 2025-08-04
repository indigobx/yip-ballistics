extends StaticBody3D

@export var medium: Physics.Medium
@export var size: Vector3
@export var thickness: float = 0.4

func _ready() -> void:
  $CollisionShape3D.shape.size = size
