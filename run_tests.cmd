@echo off
setlocal

set GODOT_EXE=E:\Godot\godot_mono\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe
rem %~dp0 ends in a trailing backslash, which escapes the closing quote below
rem ("...\") and swallows the rest of the command line. Strip it with %~dp0:~0,-1.
set PROJECT_DIR=%~dp0
set PROJECT_DIR=%PROJECT_DIR:~0,-1%

"%GODOT_EXE%" --headless --path "%PROJECT_DIR%" -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit

exit /b %ERRORLEVEL%
