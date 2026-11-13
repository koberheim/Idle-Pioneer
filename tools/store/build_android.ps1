<#
Builds build\android\IdlePioneer.aab, the signed release bundle that is
uploaded to Google Play, then checks it (tools\store\check_aab.py).

  tools\store\build_android.cmd            build with the current version code
  tools\store\build_android.cmd -Bump      raise the version code by one first
  tools\store\build_android.cmd -Trial     a practice run signed with Godot's debug
                                           key -> IdlePioneer-trial.aab (NOT for upload)

The upload key comes from tools\store\make_keystore.cmd. Its password is asked
for here on every build and is never written to disk. If you saved the key in
the Godot editor instead (Project > Export > Android > Keystore), that is used
and nothing is asked.
#>
param([switch]$Bump, [switch]$Trial)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$godot = if ($env:GODOT) { $env:GODOT } else { 'E:\Godot\Godot_v4.7.2-stable_win64.exe' }
if (-not $env:JAVA_HOME) { $env:JAVA_HOME = 'E:\Android\jdk-17' }
# Gradle's cache is several GB; keep it next to the SDK.
if (-not $env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME = 'E:\Android\gradle' }
# Without this Gradle leaves a background process running for hours, and the
# export below would sit waiting for it after the bundle is already written.
$env:GRADLE_OPTS = '-Dorg.gradle.daemon=false'
$keystore = if ($env:IDLE_PIONEER_KEYSTORE) { $env:IDLE_PIONEER_KEYSTORE } else { 'E:\Android\keys\idlepioneer-upload.jks' }
$presets = Join-Path $root 'export_presets.cfg'
$out = Join-Path $root $(if ($Trial) { 'build\android\IdlePioneer-trial.aab' } else { 'build\android\IdlePioneer.aab' })
$log = Join-Path $root 'build\android\export.log'

if (-not (Test-Path $godot)) { throw "Godot not found at $godot (set the GODOT environment variable)." }

# --- version code -------------------------------------------------------------
$text = [IO.File]::ReadAllText($presets)
$m = [regex]::Match($text, '(?m)^version/code=(\d+)')
if (-not $m.Success) { throw 'version/code not found in export_presets.cfg' }
$code = [int]$m.Groups[1].Value
if ($Bump) {
	$code += 1
	$text = $text.Substring(0, $m.Index) + "version/code=$code" + $text.Substring($m.Index + $m.Length)
	[IO.File]::WriteAllText($presets, $text, (New-Object Text.UTF8Encoding $false))
}
$name = [regex]::Match($text, '(?m)^version/name="([^"]*)"').Groups[1].Value
Write-Host "Idle Pioneer $name (version code $code)"
Write-Host 'Google Play refuses a version code it has already seen: use -Bump for every new upload.'

# --- signing ------------------------------------------------------------------
$saved = Join-Path $root '.godot\export_credentials.cfg'
$editorHasKey = (Test-Path $saved) -and ((Get-Content $saved -Raw) -match '(?m)^keystore/release="[^"]+"')
if ($Trial) {
	# Godot's own debug key (its password is the public Android default).
	$settings = Get-ChildItem (Join-Path $env:APPDATA 'Godot\editor_settings-4*.tres') | Sort-Object Name | Select-Object -Last 1
	$dk = [regex]::Match((Get-Content $settings.FullName -Raw), '(?m)^export/android/debug_keystore = "([^"]+)"').Groups[1].Value
	if (-not $dk -or -not (Test-Path $dk)) { throw 'Godot debug keystore not found (Editor Settings > Export > Android).' }
	$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $dk
	$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = 'androiddebugkey'
	$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = 'android'
	Write-Host 'TRIAL build: signed with the debug key. Do not upload it.'
} elseif (-not $editorHasKey) {
	if (-not (Test-Path $keystore)) {
		throw "No upload key at $keystore. Run tools\store\make_keystore.cmd first."
	}
	$secure = Read-Host 'Upload key password' -AsSecureString
	$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
	try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
	finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
	if (-not $plain) { throw 'No password entered.' }
	$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keystore
	$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = 'upload'
	$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $plain
}

# --- export -------------------------------------------------------------------
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
if (Test-Path $out) { Remove-Item $out }
Write-Host 'Exporting (a few minutes; the first build downloads Google''s libraries)...'
$exportArgs = @('--headless', '--path', "`"$root`"", '--install-android-build-template', '--export-release', 'Android', "`"$out`"")
$p = Start-Process -FilePath $godot -ArgumentList $exportArgs -NoNewWindow -Wait -PassThru `
	-RedirectStandardOutput $log -RedirectStandardError "$log.err"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $null
if (-not (Test-Path $out)) {
	Write-Host "Export failed (exit code $($p.ExitCode)). Last lines of ${log}:"
	Get-Content $log, "$log.err" -ErrorAction SilentlyContinue | Select-Object -Last 30
	exit 1
}

# --- check --------------------------------------------------------------------
$checkArgs = @((Join-Path $PSScriptRoot 'check_aab.py'), $out)
if ($Trial) { $checkArgs += '--allow-test' }
& python @checkArgs
exit $LASTEXITCODE
