#!/bin/bash

W=32
draw_cmd=""

# Первый пиксель — красный
draw_cmd+='-fill red -draw "point 0,0" '

# Промежуточные серые
for ((i=1; i<W-1; i++)); do
  draw_cmd+=" -fill gray70 -draw \"point $i,0\""
done

# Последний пиксель — gray90
draw_cmd+=" -fill gray90 -draw \"point $((W-1)),0\""

# Выполнить команду
eval magick -size ${W}x1 xc:none $draw_cmd bullet_3d.png
