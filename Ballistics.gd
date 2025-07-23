extends Node3D
class_name AdvancedBallistics

# Константы
const MIN_VELOCITY := 0.01  # Минимальная значимая скорость [м/с]
const G7_DRAG_BASE := 0.371  # Базовый коэффициент сопротивления модели G7
const STABILITY_THRESHOLD := 1.5  # Порог устойчивости снаряда
const LIFT_COEFFICIENT := 0.0025  # Коэффициент подъемной силы
const GYROSCOPIC_PRECESSION_FACTOR := 0.0001  # Фактор гироскопической прецессии
const SPIN_DECAY_AIR := 0.998  # Коэффициент затухания вращения в воздухе
const SPIN_DECAY_WATER := 0.8  # Коэффициент затухания вращения в воде
const BULLET_TUMBLE_THRESHOLD := 0.5  # Порог начала кувыркания

#=== Основной метод обновления ===#
func update_projectile(proj: Dictionary, delta: float) -> Dictionary:
  var new_proj = proj.duplicate(true)
  var medium = GameState.env_conditions["medium"]
  var medium_props = Physics.get_medium_properties(medium)
  print(medium_props)
  if medium_props.is_empty():
    push_warning("Unknown medium type")
    return new_proj
  
  # 1. Предварительные расчеты
  _update_pre_physics(new_proj, delta)
  
  # 2. Физика в зависимости от типа среды
  match medium_props["type"]:
    "gas":
      _update_gas_dynamics(new_proj, medium_props, delta)
    "liquid":
      _update_hydrodynamics(new_proj, medium_props, delta)
    "vacuum":
      _update_vacuum_dynamics(new_proj, delta)
    "solid":
      _update_solid_interaction(new_proj, delta)
  
  # 3. Обновление положения и ориентации
  _update_position_orientation(new_proj, delta)
  
  # 4. Проверка состояния после физики
  _update_post_physics(new_proj, delta)
  
  return new_proj

#=== Создание снаряда с улучшенными параметрами ===#
func create_projectile(weapon: WeaponData, ammo: AmmoData, muzzle_pos: Vector3, muzzle_rot: Basis) -> Dictionary:
  var direction = -muzzle_rot.z.normalized()
  var length_diameter_ratio = ammo.get_property("length_diameter_ratio", ammo.length / ammo.caliber if ammo.caliber > 0 else 3.0)
  
  # Расчет начального вращения в зависимости от типа стабилизации
  var angular_velocity = Vector3.ZERO
  if ammo.stab_type == AmmoData.StabilizationType.SPIN:
    var twist_rate_m = weapon.twist_rate * 0.001  # Переводим мм/оборот в м/оборот
    var spin_magnitude = (2.0 * PI * ammo.speed) / twist_rate_m
    angular_velocity = (muzzle_rot * Vector3.FORWARD) * spin_magnitude * (-1.0 if weapon.rifling_clockwise else 1.0)
  
  # Расчет коэффициента эффекта Магнуса с учетом глубины нарезов
  var magnus_factor = 0.00025 * weapon.rifling_depth_mm * length_diameter_ratio
  
  # Формирование снаряда
  return {
    "weapon": weapon,
    "ammo": ammo,
    "uid": Globals.gen_uid(8, "proj_"),
    "position": muzzle_pos,
    "velocity": direction * ammo.speed,
    "rotation": muzzle_rot,
    "flight_time": 0.0,
    "mass": ammo.mass,
    "caliber": ammo.caliber,
    "length": ammo.length,
    "length_diameter_ratio": length_diameter_ratio,
    "drag_coef": ammo.drag_coef,
    "cross_section": PI * pow(ammo.caliber * 0.0005, 2),
    "core_mass": ammo.core_mass,
    "core_hardness": ammo.core_hardness,
    "core_caliber": ammo.core_caliber,
    "kind": "normal",
    "state": "normal",
    "ricochet_min_angle": ammo.ricochet_min_angle,
    "ricochet_max_angle": ammo.ricochet_max_angle,
    "fragmentation_chance": ammo.fragmentation_chance,
    "fragments_min": ammo.fragments_min,
    "fragments_max": ammo.fragments_max,
    "impact_count": 0,
    "ricochet_count": 0,
    "penetration_count": 0,
    "fragmentation_count": 0,
    "ttl": Time.get_ticks_msec() / 1000.0 + Config.projectile_ttl,
    "spin_decay_rate": SPIN_DECAY_AIR,
    "angular_velocity": angular_velocity,
    "magnus_effect_factor": magnus_factor,
    "stability_factor": 1.0,  # 1.0 = полностью стабилен
    "tumble_time": 0.0,  # Время кувыркания
    "effective_cross_section": 0.0,  # Будет рассчитано
    "current_drag_coef": 0.0,  # Будет рассчитано
    "mach_number": 0.0  # Будет рассчитано
  }

#=== Детализированные физические модели ===#
func _update_pre_physics(proj: Dictionary, delta: float) -> void:
  """Расчет динамических параметров перед физикой"""
  # Обновление динамического сечения (G7 модель)
  proj["effective_cross_section"] = _calculate_effective_cross_section(proj)
  
  # Расчет текущего коэффициента сопротивления
  proj["current_drag_coef"] = _calculate_dynamic_drag_coef(proj)
  
  # Расчет числа Маха
  var speed_of_sound = Physics.get_speed_of_sound(GameState.env_conditions["medium"])
  proj["mach_number"] = proj["velocity"].length() / speed_of_sound if speed_of_sound > 0 else 0
  
  # Обновление фактора стабильности
  _update_stability_factor(proj, delta)

func _update_stability_factor(proj: Dictionary, delta: float) -> void:
  """Расчет фактора стабильности снаряда"""
  if proj["ammo"].stab_type != AmmoData.StabilizationType.SPIN:
    proj["stability_factor"] = 0.0
    return
  
  # Расчет гироскопической стабильности (Sg)
  var twist_rate = proj["weapon"].twist_rate * 0.001
  var sg = (30.0 * proj["mass"] * pow(proj["ammo"].speed, 2)) / \
       (PI * pow(twist_rate, 2) * pow(proj["caliber"] * 0.001, 3) * proj["length_diameter_ratio"])
  
  # Расчет аэродинамической стабильности
  var stability = sg / (1.0 + 0.5 * (1.0 - proj["stability_factor"]))
  proj["stability_factor"] = clamp(stability / STABILITY_THRESHOLD, 0.0, 1.0)
  
  # Обновление времени кувыркания для нестабильных снарядов
  if proj["stability_factor"] < BULLET_TUMBLE_THRESHOLD:
    proj["tumble_time"] += delta * (1.0 - proj["stability_factor"])

#=== Физика для разных сред ===#
func _update_gas_dynamics(proj: Dictionary, medium_props: Dictionary, delta: float) -> void:
  """Полная аэродинамика в газовых средах"""
  _apply_aerodynamic_drag(proj, medium_props, delta)
  _apply_gravity(proj, delta)
  _apply_lift_force(proj, medium_props, delta)
  _apply_angular_drag(proj, medium_props, delta)
  
  if proj["ammo"].stab_type == AmmoData.StabilizationType.SPIN:
    _apply_gyroscopic_precession(proj, delta)
    _apply_magnus_effect(proj, medium_props, delta)
  
  _apply_wind(proj, delta)
  _apply_turbulence(proj, medium_props, delta)

func _update_hydrodynamics(proj: Dictionary, medium_props: Dictionary, delta: float) -> void:
  """Гидродинамика в жидких средах"""
  _apply_hydrodynamic_drag(proj, medium_props, delta)
  _apply_gravity(proj, delta)
  _apply_buoyancy(proj, medium_props, delta)
  _apply_angular_drag(proj, medium_props, delta, 5.0)  # Усиленное демпфирование
  
  if proj["flight_time"] < 0.1:  # Эффект кавитации
    proj["velocity"] *= 0.95

#=== Реализация физических эффектов ===#
func _apply_aerodynamic_drag(proj: Dictionary, medium_props: Dictionary, delta: float) -> void:
  var density = medium_props["base_density"]  # кг/м³
  var speed = proj["velocity"].length()
  if speed < MIN_VELOCITY: return
  
  # Получаем баллистический коэффициент из данных пули (по умолчанию 0.15 для G7)
  var ballistic_coef = proj["ammo"].get("ballistic_coefficient_g7")
  
  # Динамический коэффициент сопротивления с учётом числа Маха
  var drag_coef = _calculate_dynamic_drag_coef(proj)
  
  # Формула сопротивления с разделением BC и Cᴅ
  var drag_force = (0.5 * density * speed * speed * drag_coef * proj["effective_cross_section"]) / ballistic_coef
  
  # Применяем силу (массу переводим граммы → кг)
  var mass_kg = proj["mass"] * 0.001
  proj["velocity"] -= drag_force * delta / mass_kg * proj["velocity"].normalized()

func _calculate_dynamic_drag_coef(proj: Dictionary) -> float:
  # Базовый коэффициент из данных пули (для 5.56x45 M855 = 0.28)
  var base_coef = proj["drag_coef"]
  
  # Коррекция для сверхзвукового режима (M855)
  if proj["mach_number"] > 1.0:
    return base_coef * (1.0 + 0.2 * (proj["mach_number"] - 1.0))
  
  # Коррекция для дозвукового режима
  elif proj["mach_number"] < 0.9:
    return base_coef * 0.9
  
  return base_coef

func _calculate_effective_cross_section(proj: Dictionary) -> float:
  var base_area = PI * pow(proj["caliber"] * 0.0005, 2)  # мм → м
  var forward = Basis(proj["rotation"]).z.normalized()
  var velocity_dir = proj["velocity"].normalized() if proj["velocity"].length_squared() > MIN_VELOCITY else forward
  
  # Угол атаки и коррекция площади
  var angle_of_attack = forward.angle_to(velocity_dir)
  return base_area * (1.0 + 0.3 * abs(sin(angle_of_attack)))

func _apply_lift_force(proj: Dictionary, medium_props: Dictionary, delta: float) -> void:
  var density = Physics.get_density(
    GameState.env_conditions["medium"],
    GameState.env_conditions["temperature"],
    GameState.env_conditions.get("pressure", 101325.0)
  )
  
  var velocity = proj["velocity"]
  var speed = velocity.length()
  if speed < MIN_VELOCITY: return
  
  var velocity_dir = velocity.normalized()
  var forward = Basis(proj["rotation"]).z.normalized()
  var right = Basis(proj["rotation"]).x.normalized()
  var angle_of_attack = forward.angle_to(velocity_dir)
  
  var lift_dir = velocity_dir.cross(right).normalized()
  var lift_coef = LIFT_COEFFICIENT * angle_of_attack * proj["length_diameter_ratio"]
  var lift_force = 0.5 * density * speed * speed * lift_coef * proj["effective_cross_section"]
  
  proj["velocity"] += lift_force * delta / (proj["mass"] * 0.001) * lift_dir

func _apply_gyroscopic_precession(proj: Dictionary, delta: float) -> void:
  if proj["angular_velocity"].length_squared() < 1.0: return
  
  var forward = Basis(proj["rotation"]).z.normalized()
  var velocity_dir = proj["velocity"].normalized() if proj["velocity"].length_squared() > 0 else forward
  
  var torque = forward.cross(velocity_dir) * GYROSCOPIC_PRECESSION_FACTOR * \
        (1.0 - proj["stability_factor"])  # Усиление при потере стабильности
  proj["angular_velocity"] += torque * delta

func _apply_magnus_effect(proj: Dictionary, medium_props: Dictionary, delta: float) -> void:
  if proj["state"] != "normal" or proj["angular_velocity"].length() < 10.0: return
  
  var magnus_dir = proj["angular_velocity"].cross(proj["velocity"].normalized())
  if magnus_dir.length_squared() > 0:
    var magnus_force = magnus_dir * proj["magnus_effect_factor"] * \
              proj["stability_factor"]  # Ослабление при кувыркании
    proj["velocity"] += magnus_force * delta

#=== Физика в вакууме ===#
func _update_vacuum_dynamics(proj: Dictionary, delta: float) -> void:
  """Физика снаряда в вакууме - только гравитация"""
  _apply_gravity(proj, delta)
  # В вакууме нет сопротивления, только гравитация
  proj["spin_decay_rate"] = 0.999  # Очень медленное затухание вращения

#=== Взаимодействие с твердыми средами ===#
func _update_solid_interaction(proj: Dictionary, delta: float) -> void:
  """Обработка снаряда, застрявшего в твердой среде"""
  # Сильное замедление
  proj["velocity"] *= pow(0.1, delta)
  # Быстрая потеря вращения
  proj["angular_velocity"] *= pow(0.5, delta)
  # Увеличение времени жизни перед удалением
  proj["ttl"] = Time.get_ticks_msec() / 1000.0 + 1.0

#=== Базовые физические силы ===#
func _apply_gravity(proj: Dictionary, delta: float) -> void:
  """Применение гравитации к снаряду"""
  proj["velocity"].y -= GameState.env_conditions["gravity"] * delta

func _apply_angular_drag(proj: Dictionary, medium_props: Dictionary, delta: float, factor: float = 1.0) -> void:
  """Сопротивление вращению в среде"""
  if proj["angular_velocity"].length_squared() < 0.01:
    return
  
  var viscosity = medium_props.get("viscosity", 0.0)
  var density = Physics.get_density(
    GameState.env_conditions["medium"],
    GameState.env_conditions["temperature"],
    GameState.env_conditions.get("pressure", 101325.0)
  )
  
  # Момент сопротивления зависит от вязкости и плотности среды
  var drag_torque = 0.1 * density * viscosity * factor * delta
  proj["angular_velocity"] *= 1.0 - drag_torque

func _apply_wind(proj: Dictionary, delta: float) -> void:
  """Влияние ветра на снаряд"""
  var wind_vec = GameState.env_conditions["wind_direction"].normalized() * \
          GameState.env_conditions["wind_strength"]
  var relative_wind = wind_vec - proj["velocity"]
  var wind_force = relative_wind * 0.05 * delta / (proj["mass"] * 0.001)
  proj["velocity"] += wind_force

func _apply_turbulence(proj: Dictionary, medium_props: Dictionary, delta: float) -> void:
  """Турбулентные возмущения для атмосферы"""
  if medium_props["type"] != "gas" or proj["velocity"].length() < 50.0:
    return
  
  # Случайные колебания для имитации турбулентности
  var turbulence = Vector3(
    randf_range(-0.5, 0.5),
    randf_range(-0.2, 0.2),
    randf_range(-0.3, 0.3)
    )
  
  # Интенсивность зависит от скорости и стабильности
  var intensity = 0.01 * (1.0 - proj["stability_factor"]) * delta
  proj["velocity"] += turbulence * intensity

func _apply_hydrodynamic_drag(proj: Dictionary, medium_props: Dictionary, delta: float) -> void:
  """Гидродинамическое сопротивление в жидкостях"""
  var density = medium_props["base_density"]
  var viscosity = medium_props.get("viscosity", 0.001)
  var speed = proj["velocity"].length()
  
  if speed < MIN_VELOCITY:
    return
  
  # Квадратичное сопротивление
  var quadratic_drag = 0.5 * density * speed * speed * proj["current_drag_coef"] * proj["cross_section"]
  
  # Вязкое сопротивление (Стокс)
  var radius = proj["caliber"] * 0.0005
  var stokes_drag = 6 * PI * viscosity * radius * speed
  
  # Комбинированная модель
  var total_drag = quadratic_drag + stokes_drag
  proj["velocity"] -= total_drag * delta / (proj["mass"] * 0.001) * proj["velocity"].normalized()

func _apply_buoyancy(proj: Dictionary, medium_props: Dictionary, delta: float) -> void:
  """Плавучесть в жидких средах"""
  var medium_density = medium_props["base_density"]
  var bullet_volume = (proj["mass"] * 0.001) / medium_density  # Приблизительный объем
  
  # Сила плавучести (Архимедова сила)
  var buoyancy_force = medium_density * bullet_volume * GameState.env_conditions["gravity"]
  proj["velocity"].y += buoyancy_force * delta / (proj["mass"] * 0.001)
  
  # Демпфирование вертикальной скорости при всплытии/погружении
  if abs(proj["velocity"].y) > 2.0:
    proj["velocity"].y *= pow(0.9, delta)


#=== Обновление положения и состояния ===#
func _update_position_orientation(proj: Dictionary, delta: float) -> void:
  if proj["velocity"].is_finite():
    proj["position"] += proj["velocity"] * delta
  else:
    proj["velocity"] = Vector3.ZERO
  
  if proj["angular_velocity"].length_squared() > 0.01:
    var axis = proj["angular_velocity"].normalized()
    var angle = proj["angular_velocity"].length() * delta
    var rotation = Basis(proj["rotation"]).rotated(axis, angle)
    proj["rotation"] = rotation

func _update_post_physics(proj: Dictionary, delta: float) -> void:
  proj["flight_time"] += delta
  if Time.get_ticks_msec() / 1000.0 > proj["ttl"]:
    proj["state"] = "expired"
  
  # Проверка на NaN/Infinity
  if not proj["velocity"].is_finite():
    proj["velocity"] = Vector3.ZERO
  if not proj["position"].is_finite():
    proj["position"] = Vector3.ZERO
