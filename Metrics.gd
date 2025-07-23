extends Node

# Настройки
var victoria_metrics_url = "http://192.168.1.3:28428/api/v1/import/prometheus"

func send_metrics(metrics: Dictionary):
  if not metrics.has("naming"):
    push_error("Missing 'naming' in metrics!")
    return
  
  # 1. Подготовка метрик
  var payload = ""
  var labels = {
    "projectile_uid": metrics.naming.get("projectile_uid", "unknown"),
    "weapon_name": metrics.naming.get("weapon_name", "unknown"), 
    "ammo_name": metrics.naming.get("ammo_name", "unknown")
  }
  
  # 2. Формируем payload
  for category in metrics:
    if category == "naming":
      continue
      
    for key in metrics[category]:
      var value = _convert_to_float(metrics[category][key])
      if value != null:
        var metric_name = "%s_%s" % [category, key]
        var label_str = ""
        for k in labels:
          label_str += '%s="%s",' % [k, labels[k]]
        label_str = label_str.trim_suffix(",")
        
        payload += "%s{%s} %f\n" % [metric_name, label_str, value]
  
  print("Debug payload:\n", payload)  # Для отладки
  
  # 3. Отправка HTTP-запроса
  var http = HTTPRequest.new()
  add_child(http)
  
  var error = http.request(victoria_metrics_url, [], HTTPClient.METHOD_POST, payload)
  if error != OK:
    push_error("HTTP request error: ", error)
    http.queue_free()
    return
  
  # Ожидаем завершения запроса (Godot 4)
  var result = await http.request_completed
  print("Response code: ", result)
  http.queue_free()

func _convert_to_float(value):
  if value is float or value is int:
    return float(value)
  elif value is String and value.is_valid_float():
    return value.to_float()
  return null
