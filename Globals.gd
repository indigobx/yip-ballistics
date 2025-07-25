extends Node

enum Rifling { NONE, POLYGONAL, TRAPEZOID, RATCHET }


var _safe_chars = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
var _safe_chars_len = _safe_chars.length()

func gen_uid(length: int = 8, prefix: String = "", suffix: String = "") -> String:
  var result = PackedByteArray()
  result.resize(length)
  for i in range(length):
    result[i] = _safe_chars.unicode_at(randi() % _safe_chars_len)
  return prefix + result.get_string_from_ascii() + suffix

func save_json(data, path: String) -> bool:
  var file = FileAccess.open(path, FileAccess.WRITE)
  if file == null:
    push_error("Failed to save JSON: %s" % FileAccess.get_open_error())
    return false
  
  file.store_string(JSON.stringify(data, "  "))  # "\t" для красивого форматирования
  file.close()
  return true

func prettify_dict(original: Dictionary) -> Dictionary:
  var result := {}
  for key in original:
    result[key] = _convert_value(original[key])
  return result

func _convert_value(value) -> Variant:
  match typeof(value):
    TYPE_DICTIONARY:
      return prettify_dict(value)
      
    TYPE_ARRAY:
      return value.map(_convert_value)
      
    TYPE_VECTOR2, TYPE_VECTOR2I:
      return {"x": value.x, "y": value.y}
      
    TYPE_VECTOR3, TYPE_VECTOR3I:
      return {"x": value.x, "y": value.y, "z": value.z}
      
    TYPE_VECTOR4, TYPE_VECTOR4I:
      return {"x": value.x, "y": value.y, "z": value.z, "w": value.w}
      
    TYPE_QUATERNION:
      return {"x": value.x, "y": value.y, "z": value.z, "w": value.w}
      
    TYPE_BASIS:
      return {
        "x": {"x": value.x.x, "y": value.x.y, "z": value.x.z},
        "y": {"x": value.y.x, "y": value.y.y, "z": value.y.z},
        "z": {"x": value.z.x, "y": value.z.y, "z": value.z.z}
      }
      
    TYPE_TRANSFORM2D:
      return {
        "x": {"x": value.x.x, "y": value.x.y},
        "y": {"x": value.y.x, "y": value.y.y},
        "origin": {"x": value.origin.x, "y": value.origin.y}
      }
      
    TYPE_TRANSFORM3D:
      return {
        "basis": _convert_value(value.basis),
        "origin": _convert_value(value.origin)
      }
      
    _:
      return value
