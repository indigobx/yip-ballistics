extends Control

enum Hatch {
  NONE,
  DOTS,
  D_DOTS,
  HORIZONTAL,
  VERTICAL,
  DIAGONAL_LEFT,
  DIAGONAL_RIGHT,
  X_CROSS,
  PLUS_CROSS,
  WAVE,
  X,
  PLUS
}

@export var medium: Physics.Medium:
  get:
    return _medium
  set(value):
    _medium = value
    queue_redraw()

var _medium: Physics.Medium = Physics.Medium.AIR_CLEAN

var pattern: Hatch
var hatch_density: float = 8.0
var hatch_thickness: float = 1.0
var color: Color = Color(0.5, 1.0, 0.7, 0.25)
@onready var rect: Vector2 = $TextureRect.get_rect().size

func _ready() -> void:
  queue_redraw()

func _draw() -> void:
  _set_pattern()
  _draw_hatching()

func _set_pattern() -> void:
  match medium:
    Physics.Medium.AIR_CLEAN, Physics.Medium.AIR_URBAN:
      pattern = Hatch.D_DOTS
      hatch_density = 24.0
      hatch_thickness = 1.0
      
    Physics.Medium.AIR_HOT:
      pattern = Hatch.DOTS
      hatch_density = 20.0
      hatch_thickness = 1.0

    Physics.Medium.AIR_HUMID:
      pattern = Hatch.DOTS
      hatch_density = 18.0
      hatch_thickness = 1.5

    Physics.Medium.WATER_FRESH, Physics.Medium.WATER_SALT:
      pattern = Hatch.HORIZONTAL
      hatch_density = 12.0
      hatch_thickness = 1.2

    Physics.Medium.WATER_DIRTY:
      pattern = Hatch.HORIZONTAL
      hatch_density = 8.0
      hatch_thickness = 1.5

    Physics.Medium.OIL_MACHINE:
      pattern = Hatch.WAVE
      hatch_density = 10.0
      hatch_thickness = 1.4

    Physics.Medium.STEEL_STRUCTURAL, Physics.Medium.STEEL_ARMOR, Physics.Medium.CAST_IRON:
      pattern = Hatch.DIAGONAL_LEFT
      hatch_density = 14.0
      hatch_thickness = 1.8

    Physics.Medium.ALUMINUM_7000:
      pattern = Hatch.DIAGONAL_RIGHT
      hatch_density = 14.0
      hatch_thickness = 1.6

    Physics.Medium.CONCRETE, Physics.Medium.ASPHALT, Physics.Medium.BRICK:
      pattern = Hatch.PLUS
      hatch_density = 8.0
      hatch_thickness = 2.0

    Physics.Medium.WOOD:
      pattern = Hatch.X
      hatch_density = 10.0
      hatch_thickness = 1.5

    Physics.Medium.PLASTIC_SOFT:
      pattern = Hatch.WAVE
      hatch_density = 16.0
      hatch_thickness = 1.2

    Physics.Medium.PLASTIC_HARD:
      pattern = Hatch.PLUS_CROSS
      hatch_density = 14.0
      hatch_thickness = 1.6

    Physics.Medium.POLYSTYRENE:
      pattern = Hatch.DOTS
      hatch_density = 12.0
      hatch_thickness = 3.0

    Physics.Medium.VACUUM:
      pattern = Hatch.NONE
      hatch_density = 0.0
      hatch_thickness = 0.0

    Physics.Medium.FLESH_MUSCLE, Physics.Medium.FLESH_SKIN, Physics.Medium.FLESH_GENERIC:
      pattern = Hatch.X_CROSS
      hatch_density = 12.0
      hatch_thickness = 1.3

    Physics.Medium.FLESH_ORGAN_DENSE, Physics.Medium.FLESH_ORGAN_HOLLOW:
      pattern = Hatch.PLUS_CROSS
      hatch_density = 10.0
      hatch_thickness = 1.5

    Physics.Medium.BONE:
      pattern = Hatch.DIAGONAL_LEFT
      hatch_density = 16.0
      hatch_thickness = 2.0

    Physics.Medium.BALLISTIC_GEL:
      pattern = Hatch.DOTS
      hatch_density = 14.0
      hatch_thickness = 2.2

    _:
      pattern = Hatch.NONE

func _draw_hatching() -> void:
  match pattern:
    Hatch.DOTS:
      _draw_dots()
    Hatch.D_DOTS:
      _draw_d_dots()
    Hatch.HORIZONTAL:
      _draw_horizontal()
    Hatch.VERTICAL:
      _draw_vertical()
    Hatch.DIAGONAL_LEFT:
      _draw_diagonal_left()
    Hatch.DIAGONAL_RIGHT:
      _draw_diagonal_right()
    Hatch.X_CROSS:
      _draw_diagonal_left()
      _draw_diagonal_right()
    Hatch.PLUS_CROSS:
      _draw_horizontal()
      _draw_vertical()
    Hatch.WAVE:
      _draw_wave()
    Hatch.X:
      _draw_diagonal_cross()
    Hatch.PLUS:
      _draw_plus_cross()
    Hatch.NONE:
      pass
    _:
      push_warning("Unknown hatch pattern: %s" % str(pattern))

func _draw_dots() -> void:
  for y in range(0, rect.y, hatch_density):
    for x in range(0, rect.x, hatch_density):
      var xy = Vector2(x, y)
      draw_circle(xy, hatch_thickness, color)

func _draw_d_dots() -> void:
  var i = 0
  for y in range(0, rect.y, hatch_density):
    for x in range(0, rect.x, hatch_density):
      if i%2 == 0:
        x += int(hatch_density/2)
      var xy = Vector2(x, y)
      draw_circle(xy, hatch_thickness, color)
    i += 1

func _draw_horizontal() -> void:
  for y in range(0, rect.y, hatch_density):
    var from = Vector2(0.0, y)
    var to = Vector2(rect.x, y)
    draw_line(from, to, color, hatch_thickness)

func _draw_vertical() -> void:
  for x in range(0, rect.x, hatch_density):
    var from = Vector2(x, 0.0)
    var to = Vector2(x, rect.y)
    draw_line(from, to, color, hatch_thickness)

func _draw_diagonal_left() -> void:
  var total = int((rect.x + rect.y) / hatch_density)

  for i in range(total + 1):
    var from = Vector2(0, i * hatch_density)
    var to = Vector2(i * hatch_density, 0)

    if from.y > rect.y:
      from.x += from.y - rect.y
      from.y = rect.y
    if to.x > rect.x:
      to.y += to.x - rect.x
      to.x = rect.x

    draw_line(from, to, color, hatch_thickness)

func _draw_diagonal_right() -> void:
  var total = int((rect.x + rect.y) / hatch_density)

  for i in range(total + 1):
    var from = Vector2(rect.x, i * hatch_density)
    var to = Vector2(rect.x - i * hatch_density, 0)

    if from.y > rect.y:
      from.x -= from.y - rect.y
      from.y = rect.y
    if to.x < 0:
      to.y += -to.x
      to.x = 0

    draw_line(from, to, color, hatch_thickness)

func _draw_diagonal_cross() -> void:
  pass

func _draw_plus_cross() -> void:
  pass

func _draw_wave() -> void:
  pass
