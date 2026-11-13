@echo off
rem Publishes docs\site (privacy policy, support page, app-ads.txt) to the
rem public GitHub Pages site https://koberheim.github.io
rem
rem First create an empty PUBLIC repository named koberheim.github.io on
rem github.com. Then run this from anywhere; run it again after any change
rem to the pages. Git may ask you to sign in to GitHub the first time.
setlocal
set ROOT=%~dp0..\..
set SITE_REPO=https://github.com/koberheim/koberheim.github.io.git
for %%I in ("%ROOT%\..\koberheim.github.io") do set DEST=%%~fI

python "%~dp0fill_site.py"
if errorlevel 1 (
	echo.
	echo Not published: fill the placeholders above first ^(tools\store\fill_site.py^).
	exit /b 1
)

if not exist "%DEST%\.git" (
	git clone "%SITE_REPO%" "%DEST%"
	if errorlevel 1 (
		echo Could not clone %SITE_REPO%. Create that repository on github.com first.
		exit /b 1
	)
) else (
	git -C "%DEST%" pull --ff-only
)

copy /y "%ROOT%\docs\site\*.html" "%DEST%\" >nul
copy /y "%ROOT%\docs\site\app-ads.txt" "%DEST%\" >nul
rem Tell GitHub to serve the files as they are.
type nul > "%DEST%\.nojekyll"

git -C "%DEST%" add -A
git -C "%DEST%" diff --cached --quiet
if not errorlevel 1 (
	echo Nothing changed since the last publish.
	exit /b 0
)
git -C "%DEST%" commit -m "Idle Pioneer site"
git -C "%DEST%" push -u origin HEAD
if errorlevel 1 exit /b 1
echo.
echo Published. In a minute or two: https://koberheim.github.io/privacy.html
exit /b 0
