#!/bin/sh
# Usage: tools/shot.sh <scenario> <out.png>   (renders with a real GPU window)
cd "$(dirname "$0")/.." && "E:/Godot/godot_mono/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe" --path . --resolution 720x1280 res://tools/shot.tscn -- scenario="$1" out="$2" 2>&1 | grep -vE "^$|Godot Engine|OpenGL API|^\s*$"
