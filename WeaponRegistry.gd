extends Node

const JSON_PATH := "res://weapon_data.json"
var weapon_dict: Dictionary = {}
var weapon_list: Array[WeaponData] = []

func _ready():
  load_weapon_from_json()

func load_weapon_from_json():
  var file = FileAccess.open(JSON_PATH, FileAccess.READ)
  if file == null:
    push_error("Failed to open weapon JSON file: %s" % FileAccess.get_open_error())
    return
  
  var json = JSON.new()
  var parse_result = json.parse(file.get_as_text())
  if parse_result != OK:
    push_error("JSON parse error: %s" % json.get_error_message())
    return
  
  var data = json.get_data()
  var entries: Array = data.get("weapons", [])
  
  weapon_dict.clear()
  weapon_list.clear()
  
  for entry in entries:
    var weapon = _safe_parse_weapon(entry)
    if weapon:
      weapon_dict[weapon.name] = weapon
      weapon_list.append(weapon)
  
  print_loaded_weapons()


func _safe_parse_weapon(dict: Dictionary) -> WeaponData:
  var weapon = WeaponData.new()
  
  # Основные параметры
  weapon.name = dict.get("name", "")
  weapon.mass = dict.get("mass", 0.0)
  weapon.barrel_length = dict.get("barrel_length", 0.0)
  weapon.spread_moa = dict.get("spread_moa", 4.0)
  weapon.ammo_type = dict.get("ammo_type", "")
  weapon.burst_rounds = dict.get("burst", 0)
  weapon.has_safety = dict.get("has_safety", true)
  
  weapon.twist_rate = dict.get("twist_rate", 254.0)  # Стандарт 1:10"
  weapon.rifling_depth_mm = dict.get("rifling_depth_mm", 0.15)
  weapon.rifling_clockwise = dict.get("rifling_clockwise", true)
  weapon.progressive_rifling = dict.get("progressive_rifling", false)
  weapon.rifling_shape = dict.get("rifling_shape", Globals.Rifling.TRAPEZOID)
  
  # Параметры fire_rate с защитой
  var fire_rate = dict.get("fire_rate", {})
  if fire_rate is Dictionary:
    weapon.fire_rate_single = fire_rate.get("single", 0.0)
    weapon.fire_rate_auto = fire_rate.get("auto", 0.0)
    weapon.fire_rate_burst = fire_rate.get("burst", 0.0)
  
  return weapon

func print_loaded_weapons():
  var names = weapon_list.map(func(w): return w.name)
  print("Loaded weapons: ", ", ".join(names))

func get_weapon_by_name(wname: String) -> WeaponData:
  return weapon_dict.get(wname) as WeaponData
