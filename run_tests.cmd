@echo off
setlocal

set GODOT_EXE=D:\Godot_v4.6.2-stable_win64.exe
rem %~dp0 ends in a trailing backslash, which escapes the closing quote below
rem ("...\") and swallows the rest of the command line. Strip it with %~dp0:~0,-1.
set PROJECT_DIR=%~dp0
set PROJECT_DIR=%PROJECT_DIR:~0,-1%

"%GODOT_EXE%" --headless --path "%PROJECT_DIR%" -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit

exit /b %ERRORLEVEL%
