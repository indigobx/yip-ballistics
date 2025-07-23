extends Control

@export var from := Vector2.ZERO
@export var to := Vector2.ZERO
@export var color := Color.RED
@export var clamp_length := Vector2.ZERO
@export var has_arrow: bool = true
@export var has_label: bool = true
@export var show_value: bool = false
@export var label_text: String = "ABXY"
@export var label_size: int = 14
@export var label_offset := Vector2(0, -10)
@export var width: float = 1.0
@export var arrow_size: float = 4.0
@onready var line := $Line
@onready var arrow := $Arrow
@onready var label := $Label
@onready var v_label := $Value
var length: float = 0.0
var value

func _ready() -> void:
  update()

func update() -> void:
  length = abs(from.length() - to.length())
  if clamp_length != Vector2.ZERO and not is_zero_approx(length):
    _clamp_length()
  if not is_zero_approx(length):
    _draw_line()
    if has_arrow:
      _draw_arrow()
    else:
      _hide_arrow()
    if has_label and label:
      _draw_label()
    else:
      _hide_label()
    if show_value and value:
      _draw_value()
    else:
      _hide_value()
  else:
    _hide_line()
    _hide_arrow()
    _hide_value()
    _hide_label()

func _clamp_length() -> void:
  var dir = (to - from).normalized()
  if length < clamp_length.x:
    to = dir * clamp_length.x
  if length > clamp_length.y:
    to = dir * clamp_length.y

func _draw_line() -> void:
  line.visible = true
  line.clear_points()
  line.add_point(from)
  line.add_point(to)
  line.default_color = color
  line.width = width
  line.closed = false

func _hide_line() -> void:
  line.visible = false

func _draw_label() -> void:
  label.visible = true
  var label_dim = label.size
  label.text = label_text
  label.label_settings.font_size = label_size
  label.modulate = color
  label.position = from + label_offset
  label.position.x -= label_dim.x/2

func _hide_label() -> void:
  label.visible = false

func _draw_arrow() -> void:
  arrow.visible = true
  var rot = (to-from).angle()
  arrow.clear_points()
  arrow.add_point(Vector2(-arrow_size, -arrow_size))
  arrow.add_point(Vector2.ZERO)
  arrow.add_point(Vector2(-arrow_size, arrow_size))
  arrow.position = to
  arrow.rotation = rot
  arrow.default_color = color
  arrow.width = width
  arrow.closed = false

func _hide_arrow() -> void:
  arrow.visible = false

func _draw_value() -> void:
  v_label.visible = true
  v_label.modulate = color
  v_label.text = "%s" % value
  v_label.position = to + label_offset

func _hide_value() -> void:
  v_label.visible = false
