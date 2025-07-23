extends Node

enum Medium {
  AIR_CLEAN,
  AIR_URBAN,
  AIR_HUMID,
  AIR_HOT,  # Около пламени/плазмы
  WATER_FRESH,
  WATER_DIRTY,  # Грязь/ил
  WATER_SALT,
  OIL_MACHINE,  # SAE 30
  STEEL_STRUCTURAL,  # AISI 1020
  STEEL_ARMOR,  # RHA (Rolled Homogeneous Armor)
  ALUMINUM_7000,  # Алюминий 7075-T6
  CAST_IRON,
  CONCRETE,  # M300
  ASPHALT,
  BRICK,
  BONE,  # Кортикальная кость
  WOOD,  # Дуб вдоль волокон
  PLASTIC_SOFT,  # Полиэтилен
  PLASTIC_HARD,  # Поликарбонат
  VACUUM,
  FLESH_MUSCLE,
  FLESH_ORGANS,  # Среднее по легким/печени
}

# Базовые физические константы
const GAS_CONSTANT = 8.314  # Универсальная газовая постоянная [Дж/(моль·K)]
#const PI = 3.14159265358979

var _medium_profiles = {}  # Заполняется в _ready()

func _ready():
  _initialize_medium_profiles()

func _initialize_medium_profiles():
  """Инициализация физических параметров сред"""
  _medium_profiles = {
      #------------------------------
      # Газы
      #------------------------------
      Medium.AIR_CLEAN: {
          "type": "gas",
          "base_density": 1.225,
          "molar_mass": 0.029,
          "drag_model": "quadratic",
          "drag_coef": 0.47,
          "viscosity": 1.81e-5,
          "speed_of_sound": 343.0,
          "rha_coef": 0.00001  # Практически не защищает
      },
      
      Medium.AIR_URBAN: {
          "type": "gas",
          "base_density": 1.290,  # Загрязнения + пыль
          "molar_mass": 0.030,
          "drag_model": "quadratic",
          "drag_coef": 0.52,
          "viscosity": 1.85e-5,
          "rha_coef": 0.00002
      },
      
      Medium.AIR_HUMID: {
          "type": "gas",
          "base_density": 1.194,  # 90% влажности
          "molar_mass": 0.028,
          "drag_model": "quadratic",
          "drag_coef": 0.55,  # Капли воды увеличивают сопротивление
          "viscosity": 1.88e-5,
          "rha_coef": 0.00003
      },
      
      Medium.AIR_HOT: {  # Около пламени/плазмы
          "type": "gas",
          "base_density": 0.5,   # При ~500°C
          "molar_mass": 0.029,
          "drag_model": "quadratic",
          "drag_coef": 0.45,
          "viscosity": 3.5e-5,
          "rha_coef": 0.00001
      },
      
      #------------------------------
      # Жидкости
      #------------------------------
      Medium.WATER_FRESH: {
          "type": "liquid",
          "base_density": 998.0,
          "drag_model": "stokes",
          "drag_coef": 0.47,
          "viscosity": 1.002e-3,
          "bulk_modulus": 2.2e9,
          "speed_of_sound": 1482,
          "rha_coef": 0.05  # 1 м воды ~ 50 мм RHA против кинетики
      },
      
      Medium.WATER_DIRTY: {  # Грязь/ил
          "type": "liquid",
          "base_density": 1100.0,
          "drag_model": "viscous",
          "viscosity": 5.0e-3,
          "rha_coef": 0.07
      },
      
      Medium.WATER_SALT: {
          "type": "liquid",
          "base_density": 1025.0,
          "drag_model": "stokes",
          "drag_coef": 0.5,
          "viscosity": 1.07e-3,
          "rha_coef": 0.055
      },
      
      Medium.OIL_MACHINE: {  # SAE 30
          "type": "liquid",
          "base_density": 900.0,
          "drag_model": "viscous",
          "viscosity": 0.1,
          "rha_coef": 0.08  # Вязкость даёт доп. сопротивление
      },
      
      #------------------------------
      # Металлы
      #------------------------------
      Medium.STEEL_STRUCTURAL: {  # AISI 1020
          "type": "solid",
          "base_density": 7850.0,
          "young_modulus": 2.0e11,
          "poisson_ratio": 0.29,
          "hardness": 120,  # HB
          "speed_of_sound": 5000,
          "rha_coef": 0.7  # Относительно RHA
      },
      
      Medium.STEEL_ARMOR: {  # RHA (Rolled Homogeneous Armor)
          "type": "solid",
          "base_density": 7850.0,
          "young_modulus": 2.1e11,
          "hardness": 250,  # HB
          "rha_coef": 1.0  # Эталон
      },
      
      Medium.ALUMINUM_7000: {  # Алюминий 7075-T6
          "type": "solid",
          "base_density": 2810.0,
          "young_modulus": 7.2e10,
          "hardness": 150,
          "rha_coef": 0.3
      },
      
      Medium.CAST_IRON: {
          "type": "solid",
          "base_density": 7300.0,
          "young_modulus": 1.2e11,
          "hardness": 200,
          "brittleness": 0.8,
          "rha_coef": 0.6
      },
      
      #------------------------------
      # Строительные материалы
      #------------------------------
      Medium.CONCRETE: {  # M300
          "type": "solid",
          "base_density": 2400.0,
          "young_modulus": 3.0e10,
          "compressive_strength": 30e6,
          "rha_coef": 0.2
      },
      
      Medium.ASPHALT: {
          "type": "solid",
          "base_density": 2300.0,
          "young_modulus": 2.0e9,
          "rha_coef": 0.15
      },
      
      Medium.BRICK: {
          "type": "solid",
          "base_density": 1800.0,
          "young_modulus": 2.4e10,
          "rha_coef": 0.18
      },
      
      #------------------------------
      # Органика/полимеры
      #------------------------------
      Medium.BONE: {  # Кортикальная кость
          "type": "solid",
          "base_density": 1850.0,
          "young_modulus": 1.5e10,
          "rha_coef": 0.25
      },
      
      Medium.WOOD: {  # Дуб вдоль волокон
          "type": "solid",
          "base_density": 700.0,
          "young_modulus": 1.2e10,
          "rha_coef": 0.1
      },
      
      Medium.PLASTIC_SOFT: {  # Полиэтилен
          "type": "solid",
          "base_density": 950.0,
          "young_modulus": 0.8e9,
          "rha_coef": 0.03
      },
      
      Medium.PLASTIC_HARD: {  # Поликарбонат
          "type": "solid",
          "base_density": 1200.0,
          "young_modulus": 2.3e9,
          "rha_coef": 0.07
      },
      
      #------------------------------
      # Специальные среды
      #------------------------------
      Medium.VACUUM: {
          "type": "vacuum",
          "base_density": 1e-12,
          "drag_model": "none",
          "rha_coef": 0.0
      },
      
      Medium.FLESH_MUSCLE: {
          "type": "solid",
          "base_density": 1050.0,
          "young_modulus": 1e5,
          "poisson_ratio": 0.49,
          "damping": 0.5,
          "rha_coef": 0.04
      },
      
      Medium.FLESH_ORGANS: {  # Среднее по легким/печени
          "type": "solid",
          "base_density": 950.0,
          "young_modulus": 5e4,
          "rha_coef": 0.02
      }
  }

func get_rha(medium: Medium, thickness: float) -> float:
    """
    Конвертирует толщину материала в эквивалент броневой стали (RHA)
    thickness - толщина в метрах
    Возвращает эквивалент в метрах RHA
    """
    var props = get_medium_properties(medium)
    if props.is_empty(): return 0.0
    return thickness * props.get("rha_coef", 0.0)

#==== Основные публичные методы ====#
func get_medium_properties(medium: Medium) -> Dictionary:
  """Получить все свойства среды"""
  return _medium_profiles.get(medium, {})

func get_density(medium: Medium, temp: float = 293.0, pressure: float = 101325.0) -> float:
  """
  Рассчитать плотность среды с учётом температуры и давления
  temp в Кельвинах, pressure в Паскалях
  """
  var props = get_medium_properties(medium)
  if props.is_empty(): return 0.0
  
  match props.type:
    "gas":
      return _calculate_gas_density(props, temp, pressure)
    "liquid":
      return _calculate_liquid_density(props, temp)
    "plasma":
      return _calculate_plasma_density(props, temp)
    _:
      return props.get("base_density", 0.0)

func get_drag_force(medium: Medium, velocity: Vector3, area: float, shape: String = "sphere") -> Vector3:
  """
  Рассчитать силу сопротивления среды
  velocity - вектор скорости объекта [м/с]
  area - характерная площадь [м²]
  shape - форма объекта ("sphere", "cube", "cylinder", "plate")
  """
  var props = get_medium_properties(medium)
  if props.is_empty(): return Vector3.ZERO
  
  var v = velocity.length()
  if v <= 0.01: return Vector3.ZERO
  var dir = -velocity.normalized()
  
  match props.drag_model:
    "quadratic":
      return _quadratic_drag(props, v, area, shape) * dir
    "stokes":
      return _stokes_drag(props, v, area) * dir
    "viscous":
      return _viscous_drag(props, v, area) * dir
    "plasma":
      return _plasma_drag(props, v, area) * dir
    _:
      return Vector3.ZERO

#==== Модели плотности ====#
func _calculate_gas_density(props: Dictionary, temp: float, pressure: float) -> float:
  """Уравнение состояния идеального газа: ρ = P*M/(R*T)"""
  return (pressure * props.get("molar_mass", 0.029)) / (GAS_CONSTANT * temp)

func _calculate_liquid_density(props: Dictionary, temp: float) -> float:
  """Плотность жидкости с температурной поправкой: ρ = ρ₀(1 - βΔT)"""
  var beta = props.get("thermal_expansion", 0.0)
  return props.base_density * (1.0 - beta * (temp - 293.0))

func _calculate_plasma_density(props: Dictionary, temp: float) -> float:
  """Плотность плазмы с учётом температуры: ρ ~ 1/√T"""
  return props.base_density * sqrt(10000.0 / max(temp, 1000.0))

#==== Модели сопротивления ====#
func _quadratic_drag(props: Dictionary, speed: float, area: float, shape: String) -> float:
  """Квадратичное сопротивление: F = 0.5*ρ*v²*C_d*A"""
  var C_d = props.drag_coef * _get_shape_coefficient(shape)
  return 0.5 * get_density(props.medium) * speed * speed * C_d * area

func _stokes_drag(props: Dictionary, speed: float, area: float) -> float:
  """Стоксово сопротивление (малые числа Рейнольдса): F = 6πηrv"""
  var r = sqrt(area / PI)
  return 6.0 * PI * props.viscosity * r * speed

func _viscous_drag(props: Dictionary, speed: float, area: float) -> float:
  """Вязкое сопротивление: F = η*v*A"""
  return props.viscosity * speed * area

func _plasma_drag(props: Dictionary, speed: float, area: float) -> float:
  """Кастомная модель для плазмы: F ~ ρ*v³*A"""
  return 0.1 * get_density(props.medium) * speed * speed * speed * area

#==== Вспомогательные методы ====#
func _get_shape_coefficient(shape: String) -> float:
  """Коэффициент формы объекта"""
  match shape:
    "sphere": return 0.47
    "cube": return 1.05
    "cylinder": return 0.82
    "plate": return 1.17
    _: return 1.0

func get_speed_of_sound(medium: Medium) -> float:
  """Скорость звука в среде [м/с]"""
  var props = get_medium_properties(medium)
  return props.get("speed_of_sound", 343.0)

func get_viscosity(medium: Medium) -> float:
  """Динамическая вязкость [Па·с]"""
  var props = get_medium_properties(medium)
  return props.get("viscosity", 0.0)
