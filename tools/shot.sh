#!/bin/sh
# Usage: tools/shot.sh <scenario> <out.png>   (renders with a real GPU window)
cd "$(dirname "$0")/.." && "D:/Godot_v4.6.2-stable_win64.exe" --path . --resolution 720x1280 res://tools/shot.tscn -- scenario="$1" out="$2" 2>&1 | grep -vE "^$|Godot Engine|OpenGL API|^\s*$"
