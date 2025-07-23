class_name AmmoData
extends Resource

enum StabilizationType { NONE, SPIN, FIN, THRUST }
enum FuseRule { NONE, HIT, SPEED, ACCEL, TIME, DIST }

@export var name: String
@export var speed: float
@export var mass: float
@export var caliber: float
@export var length: float
@export var length_diameter_ratio: float
@export var spread_moa: float
@export var drag_coef: float
@export var ballistic_coefficient_g7: float
@export var stab_type: StabilizationType = StabilizationType.NONE
@export var has_thruster: bool = false
@export var thrust_force: float = 0.0
@export var fuel_mass: float = 0.0
@export var burn_time: float = 0.0

# Дополнительно для пробиваемости:
@export var core_mass: float = 0.0
@export var core_hardness: float = 1.0
@export var core_caliber: float = 0.0

# Параметры рикошета (в градусах)
@export var can_ricochet: bool = true
@export var ricochet_min_angle: float = 20.0
@export var ricochet_max_angle: float = 75.0
@export var ricochet_chance: float = 0.5

# Фрагментация и подрыв
@export var explosive: bool = false
@export var explosive_mass: float = 0.0
@export var explosive_coef: float = 1.0
@export var fuse_delay_msec: float = 0.0
@export var fuse_delay_distance: float = 0.0
@export var fuse_arm_distance: float = 0.0
@export var fuse_init_rule: FuseRule = FuseRule.NONE
@export var fuse_init_angle: float = 45.0
@export var fuse_init_speed: float = 100.0
@export var fragments_min: int = 4
@export var fragments_max: int = 16
@export var fragmentation_chance: float = 0.5

var _dynamic_properties = {}

# Безопасный метод получения свойств (не переопределяет Object.get())
func get_property(property: StringName, default = null):
  # Проверка стандартных экспортированных свойств
  if property in self.get_property_list().map(func(p): return p.name):
    return self.get(property)
  
  # Проверка динамических свойств
  if _dynamic_properties.has(property):
    return _dynamic_properties[property]
  
  # Вычисляемые свойства
  match String(property):
    "length_diameter_ratio":
      return _calculate_length_diameter_ratio()
  
  return default

func _calculate_length_diameter_ratio() -> float:
  # Если есть кастомное значение - возвращаем его
  if _dynamic_properties.has("length_diameter_ratio"):
    return _dynamic_properties["length_diameter_ratio"]
  
  # Значение по умолчанию для типичных пуль
  return 3.0

func has_property(property: StringName) -> bool:
  var property_names = self.get_property_list().map(func(p): return p.name)
  return property in property_names or _dynamic_properties.has(property)
 
func set_custom_property(property: StringName, value) -> void:
  _dynamic_properties[property] = value

func get_property_alias(property: StringName) -> StringName:
  var aliases = {
    "ldr": "length_diameter_ratio",
    "frag_chance": "fragmentation_chance"
  }
  return aliases.get(property, property)
