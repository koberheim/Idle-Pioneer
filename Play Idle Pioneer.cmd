@echo off
rem Plays Idle Pioneer straight from this folder (no editor).
rem Edit GODOT below if Godot is installed somewhere else.
set "GODOT=E:\Godot\godot_mono\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"
if not exist "%GODOT%" (
  echo Godot not found at %GODOT%
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0."
