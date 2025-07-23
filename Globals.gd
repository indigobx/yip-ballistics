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
