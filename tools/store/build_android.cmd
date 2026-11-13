@echo off
rem Builds the signed release bundle for Google Play. See build_android.ps1.
rem   tools\store\build_android.cmd            build with the current version code
rem   tools\store\build_android.cmd -Bump      raise the version code by one first
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_android.ps1" %*
exit /b %ERRORLEVEL%
