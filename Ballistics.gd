extends Node3D
class_name AdvancedBallistics

# Константы
const MIN_VELOCITY := 0.01  # Минимальная значимая скорость [м/с]
const G7_DRAG_BASE := 0.471  # Базовый коэффициент сопротивления модели G7
const STABILITY_THRESHOLD := 1.5  # Порог устойчивости снаряда
const LIFT_COEFFICIENT := 0.0045  # Коэффициент подъемной силы 0.0025
const GYROSCOPIC_PRECESSION_FACTOR := 0.00025  # Фактор гироскопической прецессии 0.0001
const SPIN_DECAY_AIR := 0.998  # Коэффициент затухания вращения в воздухе
const SPIN_DECAY_WATER := 0.8  # Коэффициент затухания вращения в воде
const BULLET_TUMBLE_THRESHOLD := 1.0  # Порог начала кувыркания

#=== Основной метод обновления ===#
func update_projectile(proj: Dictionary, delta: float) -> Dictionary:
  var new_proj = proj.duplicate(true)
  var medium = GameState.env_conditions["medium"]
  var medium_props = Physics.get_medium_properties(medium)
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
    "mach_number": 0.0,  # Будет рассчитано,
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
  
  var v = proj["velocity"].length()
  var twist_rate = proj["weapon"].twist_rate * 0.001
  var d = proj["caliber"] * 0.001
  
  var sg = (30.0 * proj["mass"] * v) / \
           (pow(d, 3) * proj["length_diameter_ratio"] * pow(twist_rate, 2))
  
  proj["stability_factor"] = clamp(sg / STABILITY_THRESHOLD, 0.0, 1.0)
  
  if proj["stability_factor"] < BULLET_TUMBLE_THRESHOLD:
    proj["tumble_time"] += delta * (1.0 - proj["stability_factor"])

#=== Физика для разных сред ===#
func _update_gas_dynamics(proj: Dictionary, medium_props: Dictionary, delta: float) -> void:
  var debug_vel = {}
  """Полная аэродинамика в газовых средах"""
  debug_vel["0_initial"] = proj.velocity
  _apply_aerodynamic_drag(proj, medium_props, delta)
  debug_vel["1_aero_drag"] = proj.velocity
  _apply_gravity(proj, delta)
  debug_vel["2_gravity"] = proj.velocity
  _apply_lift_force(proj, medium_props, delta)
  debug_vel["3_lift"] = proj.velocity
  _apply_angular_drag(proj, medium_props, delta)
  debug_vel["4_ang_drag"] = proj.velocity
  
  if proj["ammo"].stab_type == AmmoData.StabilizationType.SPIN:
    _apply_gyroscopic_precession(proj, delta)
    debug_vel["5_gyro"] = proj.velocity
    _apply_magnus_effect(proj, medium_props, delta)
    debug_vel["6_magnus"] = proj.velocity
    _apply_derivation(proj, delta)
  
  _apply_wind(proj, delta)
  debug_vel["7_wind"] = proj.velocity
  _apply_turbulence(proj, medium_props, delta)
  debug_vel["8_turb"] = proj.velocity
  print("%s flight time %s" % [proj["flight_time"], debug_vel])

func _update_hydrodynamics(proj: Dictionary, medium_props: Dictionary, delta: float) -> void:
  """Гидродинамика в жидких средах"""
  # Усиленное демпфирование вращения в жидкостях
  proj["spin_decay_rate"] = SPIN_DECAY_WATER
  
  # Применение гидродинамических сил
  _apply_hydrodynamic_drag(proj, medium_props, delta)
  _apply_gravity(proj, delta)
  _apply_buoyancy(proj, medium_props, delta)
  _apply_angular_drag(proj, medium_props, delta, 10.0)  # Сильное демпфирование вращения
  _apply_derivation(proj, delta)
  
  # Эффект кавитации - временное снижение сопротивления
  if proj["flight_time"] < 0.05:  # Первые 50 мс - кавитационный режим
    proj["velocity"] *= 0.98  # Слабое замедление
  else:
    # После кавитации - полное сопротивление
    pass

#=== Реализация физических эффектов ===#
func _apply_aerodynamic_drag(proj: Dictionary, medium_props: Dictionary, delta: float) -> void:
  var density = medium_props["base_density"]  # 1.225 кг/м³
  var speed = proj["velocity"].length()
  if speed < MIN_VELOCITY: return
  
  # Все величины в СИ:
  var cd = _calculate_dynamic_drag_coef(proj)  # 0.28-0.45
  var area = proj["effective_cross_section"]  # 2.55e-5 м²
  var mass_kg = proj["mass"] * 0.001  # 0.0041 кг
  
  # Формула сопротивления (F = 0.5 * ρ * v² * Cd * A)
  var drag_force = 0.5 * density * speed * speed * cd * area
  
  # Ускорение (a = F/m)
  var acceleration = drag_force / mass_kg
  
  # Изменение скорости (Δv = a * Δt)
  var delta_v = acceleration * delta
  
  # Ограничение максимального замедления (не более 10% за кадр)
  #delta_v = min(delta_v, speed * 0.2)
  
  # Применяем замедление
  proj["velocity"] -= delta_v * proj["velocity"].normalized()
  
  # Отладочный вывод
  print("Drag force: %.2f N, Accel: %.2f m/s², Delta v: %.2f m/s" % [
    drag_force, acceleration, delta_v
  ])

func _calculate_dynamic_drag_coef(proj: Dictionary) -> float:
  var mach = proj["mach_number"]
  if mach > 1.0:
    return proj["drag_coef"] * 2.1  # Сильное сопротивление на сверхзвуке
  elif mach > 0.9:
    return proj["drag_coef"] * 1.85  # Переходный режим
  elif mach > 0.8:
    return proj["drag_coef"] * 1.33  # Дозвуковой
  return proj["drag_coef"]

func _calculate_effective_cross_section(proj: Dictionary) -> float:
  var base_area = PI * pow(proj["caliber"] * 0.0005, 2)
  var forward = Basis(proj["rotation"]).z.normalized()
  var velocity_dir = proj["velocity"].normalized()
  
  # Угол атаки (0° - идеальное движение)
  var angle_of_attack = forward.angle_to(velocity_dir)
  # Коррекция для кувыркающихся пуль
  if proj["stability_factor"] < BULLET_TUMBLE_THRESHOLD:
    return base_area * 1.5  # Максимальное сечение
  
  return base_area * (1.0 + 0.2 * sin(angle_of_attack))

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
  var torque = lift_dir.cross(forward) * (lift_force * 0.01)  # new
  proj["angular_velocity"] += torque * delta  # new
  proj["velocity"] += lift_force * delta / (proj["mass"] * 0.001) * lift_dir

func _apply_gyroscopic_precession(proj: Dictionary, delta: float) -> void:
  if proj["angular_velocity"].length_squared() < 1.0: return
  
  var forward = Basis(proj["rotation"]).z.normalized()
  var velocity_dir = proj["velocity"].normalized() if proj["velocity"].length_squared() > 0 else forward
  
  #var torque = forward.cross(velocity_dir) * GYROSCOPIC_PRECESSION_FACTOR * \
    #(1.0 - proj["stability_factor"])  # Усиление при потере стабильности
  var torque = forward.cross(velocity_dir) * GYROSCOPIC_PRECESSION_FACTOR * \
    (1.0 - proj["stability_factor"]) * proj["angular_velocity"].length()  # v2  
  proj["angular_velocity"] += torque * delta

func _apply_magnus_effect(proj: Dictionary, medium_props: Dictionary, delta: float) -> void:
  if proj["state"] != "normal" or proj["angular_velocity"].length() < 10.0: return
  
  var magnus_dir = proj["angular_velocity"].cross(proj["velocity"].normalized())
  if magnus_dir.length_squared() > 0:
    var magnus_force = magnus_dir * proj["magnus_effect_factor"] * \
              proj["stability_factor"]  # Ослабление при кувыркании
    var density = Physics.get_density(
      GameState.env_conditions["medium"],
      GameState.env_conditions["temperature"],
      GameState.env_conditions.get("pressure", 101325.0)
    )
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
  #var drag_torque = 0.1 * density * viscosity * factor * delta
  var drag_torque = density * viscosity * factor * delta
  proj["angular_velocity"] *= 1.0 - drag_torque

func _apply_wind(proj: Dictionary, delta: float) -> void:
  var wind_strength = GameState.env_conditions.get("wind_strength", 0.0)
  if wind_strength <= 0.0:
    return  # Нулевой ветер - сразу выходим
  
  var wind_dir = GameState.env_conditions["wind_direction"].normalized()
  var wind_vec = wind_dir * wind_strength
  
  # Правильная относительная скорость (только проекция ветра)
  var relative_wind = wind_vec - wind_dir.dot(proj["velocity"]) * wind_dir
  
  # Реалистичное влияние (0.002 - коэффициент влияния ветра)
  var wind_force = relative_wind * 0.002 * delta / (proj["mass"] * 0.001)
  
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
  var density = medium_props["base_density"]  # Плотность воды 998 кг/м³
  var viscosity = medium_props["viscosity"]   # Вязкость воды 0.001002 Па·с
  var speed = proj["velocity"].length()
  
  if speed < MIN_VELOCITY:
    return
  
  # Все величины в СИ:
  var cd = _calculate_underwater_drag_coef(proj)  # 0.3-0.5 для подводных снарядов
  var area = proj["effective_cross_section"]      # ~6.4e-5 м² для 9мм
  var mass_kg = proj["mass"] * 0.001              # 0.0075 кг
  
  # 1. Квадратичное сопротивление (преобладает на высоких скоростях)
  var quadratic_drag = 0.5 * density * speed * speed * cd * area
  
  # 2. Вязкое сопротивление (преобладает на низких скоростях)
  var radius = proj["caliber"] * 0.0005           # Радиус в метрах
  var stokes_drag = 6 * PI * viscosity * radius * speed
  
  # Комбинированная модель сопротивления с плавным переходом
  var reynolds = (2 * radius * speed * density) / viscosity
  var transition = clamp(reynolds / 1000.0, 0.0, 1.0)  # Переход между режимами
  var total_drag = lerp(stokes_drag, quadratic_drag, transition)
  
  # Ограничение максимального замедления (не более 30% скорости за кадр)
  var max_delta_v = speed * 0.3
  var delta_v = min(total_drag * delta / mass_kg, max_delta_v)
  
  # Применение замедления
  proj["velocity"] -= delta_v * proj["velocity"].normalized()
  
  var speed_effect = smoothstep(100.0, 300.0, speed)  # Плавный переход 100-300 м/с
  var water_hammer = 1.0 - speed_effect * 0.4  # Доп. потери до 40%
  
  # Итоговое применение
  proj["velocity"] -= delta_v * water_hammer * proj["velocity"].normalized()

func _calculate_underwater_drag_coef(proj: Dictionary) -> float:
  # Базовый коэффициент для подводных снарядов
  var base_cd = 0.4
  
  # Увеличение сопротивления при кувыркании
  if proj["stability_factor"] < BULLET_TUMBLE_THRESHOLD:
    return base_cd * 1.5
  
  return base_cd


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

func _apply_derivation(proj: Dictionary, delta: float) -> void:
  #return
  if proj["ammo"].stab_type != AmmoData.StabilizationType.SPIN:
    return
  
  var spin_axis = proj["angular_velocity"].normalized()
  var vel_dir = proj["velocity"].normalized()
  var speed = proj["velocity"].length()
  
  # 1. Рассчитываем угловую скорость деривации (рад/с)
  var spin_rate = proj["angular_velocity"].length()
  var derivation_rate = spin_rate * (1.0 - abs(spin_axis.dot(vel_dir))) * 0.0005
  
  # 2. Создаем вектор отклонения (перпендикулярно скорости и оси вращения)
  var derivation_dir = vel_dir.cross(spin_axis).normalized()
  
  # 3. Рассчитываем мгновенное отклонение (м/с²)
  var derivation_accel = derivation_dir * derivation_rate * speed * 0.1
  
  # 4. Применяем к скорости и угловой скорости:
  proj["velocity"] += derivation_accel * delta
  
  # 5. Гироскопический эффект - корректируем вращение
  var correction_torque = vel_dir.cross(derivation_dir) * spin_rate * 0.01
  proj["angular_velocity"] += correction_torque * delta
  
  # 6. Визуальный эффект - небольшой доворот пули
  if derivation_dir.length_squared() > 0.1:
    var visual_rotation = Basis(derivation_dir, derivation_rate * delta * 0.1)
    proj["rotation"] = visual_rotation * proj["rotation"]

#=== Обновление положения и состояния ===#
func _update_position_orientation(proj: Dictionary, delta: float) -> void:
  # Обновление позиции с проверкой на валидность скорости
  if proj["velocity"].is_finite():
    proj["position"] += proj["velocity"] * delta
  else:
    proj["velocity"] = Vector3.ZERO
  
  # Обновление вращения с защитой от NaN и проверкой длины
  if proj["angular_velocity"].length_squared() > 0.01:
    # Защита от NaN в угловой скорости
    if not proj["angular_velocity"].is_finite():
      proj["angular_velocity"] = Vector3.ZERO
      return
      
    var axis = proj["angular_velocity"].normalized()
    
    # Дополнительная проверка нормализации (на случай численных ошибок)
    if not axis.is_normalized():
      axis = axis.normalized()
      # Если все равно не нормализуется - сбрасываем вращение
      if not axis.is_normalized():
        proj["angular_velocity"] = Vector3.ZERO
        return
    
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

func smoothstep(edge0: float, edge1: float, x: float) -> float:
  var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
  return t * t * (3.0 - 2.0 * t)
