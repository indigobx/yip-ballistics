extends Node

var max_ricochets: int = 3
var max_fragmentations: int = 1
var max_penetrations: int = 3
var total_impacts_limit: int = 5
var projectile_max_distance: float = 50.0
var projectile_max_substeps: int = 200
const max_recoil_offset = Vector3(0.15, 0.25, 0.1)  # X,Y,Z
const max_recoil_rotation = Vector2(0.5, 0.3)       # X (наклон), Y (поворот)

const projectile_ttl = 2.0
