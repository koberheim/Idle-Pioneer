@echo off
rem Creates the Google Play upload key for Idle Pioneer. Run it once.
rem
rem It asks you to choose a password, then for your name and country. The key
rem is written OUTSIDE the project so it can never be committed by accident.
rem Back up the .jks file and its password somewhere safe (a password manager
rem plus a USB stick): every future update must be signed with it.
setlocal
if not defined JAVA_HOME set JAVA_HOME=E:\Android\jdk-17
if not defined IDLE_PIONEER_KEYSTORE set IDLE_PIONEER_KEYSTORE=E:\Android\keys\idlepioneer-upload.jks

if exist "%IDLE_PIONEER_KEYSTORE%" (
	echo A key already exists at %IDLE_PIONEER_KEYSTORE%
	echo Nothing was changed. Delete it yourself first if you really want a new one.
	exit /b 1
)
for %%I in ("%IDLE_PIONEER_KEYSTORE%") do if not exist "%%~dpI" mkdir "%%~dpI"

echo Creating %IDLE_PIONEER_KEYSTORE%
echo Choose a password you will not lose. Nothing shows while you type it.
echo.
"%JAVA_HOME%\bin\keytool" -genkeypair -v -keystore "%IDLE_PIONEER_KEYSTORE%" -alias upload -keyalg RSA -keysize 4096 -validity 10000
if errorlevel 1 exit /b 1
echo.
echo Done. Now back up this file and its password:
echo   %IDLE_PIONEER_KEYSTORE%
exit /b 0
