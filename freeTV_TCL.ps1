$ErrorActionPreference = 'Stop'
$script:AppId = 'com.mihir.tvhome'
$script:HomeActivity = 'com.mihir.tvhome/.MainActivity'
$script:ScreenSaver = 'com.mihir.tvhome/.Salvapantallas'
$script:PackageList = @(
  'tv.anoki.acr.anokiacroptin', 'com.homwee.aipont', 'com.homwee.store',
  'com.homwee.help', 'com.google.android.feedback', 'com.google.android.play.games',
  'com.cltv.fast', 'com.google.android.katniss', 'com.google.android.tvrecommendations',
  'com.google.android.backdrop', 'com.google.android.videos', 'tv.accedo.mitele_xdk',
  'com.homwee.chtvmanager', 'com.homwee.chinstallapk',
  'com.google.android.leanbacklauncher.partnercustomizer', 'com.google.android.marvin.talkback',
  'com.google.android.tts', 'com.google.android.partnersetup', 'com.android.providers.calendar',
  'com.google.android.syncadapters.calendar', 'com.android.htmlviewer',
  'com.android.cameraextensions', 'com.android.wallpaperbackup', 'com.android.dynsystem',
  'com.homwee.upgrade', 'com.homwee.dmt.upgrade'
)
$script:PhotoList = @(
  'Lake Mystery, Canterbury, New Zealand 05.jpg', 'Moraine Lake 17092005.jpg',
  'Mount Hood reflected in Mirror Lake, Oregon.jpg', 'Crimea, Ai-Petri, low clouds.jpg',
  'Durmitor mountains, Montenegro.jpg', 'Mount Shasta, Lake Siskiyou, SW view.jpg',
  'Mountain view in Robson valley.jpg', 'Silver Lake Mammoth September 2016 001.jpg',
  'Water reflection of the mountains of Vang Vieng with crepuscular rays.jpg',
  'Sunlight and stormy sky over the mountains and paddy fields in Vang Vieng, Laos.jpg',
  'Blue Lake in Mount Cook National Park.jpg', 'Lake Tekapo 01.jpg',
  'Lake Willoughby October 2021 003.jpg', 'Mono Lake South Tufa August 2013 012.jpg',
  'Lake near Sunnig Grat summit.JPG', 'Sunrise at Maligne lake.jpg',
  'Lac de Montriond 07.jpg', 'Lake Shkopeti, Albania.jpg'
)
$script:DataDir = Join-Path $env:LOCALAPPDATA 'TVCasaJulia'
$script:Adb = Join-Path $script:DataDir 'platform-tools\adb.exe'
$script:Apk = Join-Path $PSScriptRoot 'inicio_estilo_apple.apk'
$script:StateFile = Join-Path $script:DataDir 'estado.json'
$script:LogFile = Join-Path $script:DataDir 'registro.txt'
$script:Ip = ''

New-Item -ItemType Directory -Force -Path $script:DataDir | Out-Null
try { Start-Transcript -Path $script:LogFile -Append | Out-Null } catch { }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Pause-Menu {
  [void](Read-Host 'Pulsa Enter para volver al menu')
}

function Get-Adb {
  if (Test-Path $script:Adb) { return }
  Write-Host 'Descargando Android Platform Tools oficiales de Google...'
  $zip = Join-Path $script:DataDir 'platform-tools.zip'
  Invoke-WebRequest 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath $script:DataDir -Force
  Remove-Item $zip -Force
  if (-not (Test-Path $script:Adb)) { throw 'No se pudo instalar ADB.' }
}

function Test-Device([string]$Address) {
  if (-not $Address) { return $false }
  & $script:Adb connect $Address 2>&1 | Out-Null
  Start-Sleep -Seconds 2
  return ((& $script:Adb -s $Address get-state 2>$null) -eq 'device')
}

function Connect-Device {
  Get-Adb
  $saved = Join-Path $script:DataDir 'direccion_tele.txt'
  if (Test-Path $saved) { $script:Ip = (Get-Content $saved -Raw).Trim() }
  if (Test-Device $script:Ip) {
    Write-Host "Conectado a la tele ($script:Ip)" -ForegroundColor Green
    return $true
  }
  Write-Host ''
  Write-Host 'Activa Depuracion inalambrica en la tele.'
  Write-Host 'Para vincular por primera vez, introduce los datos de la pantalla Vincular dispositivo.'
  $pairAddress = (Read-Host 'IP:PUERTO de vinculacion (Enter si ya esta vinculada)').Trim()
  if ($pairAddress) {
    $code = (Read-Host 'Codigo de vinculacion').Trim()
    & $script:Adb pair $pairAddress $code
  }
  $script:Ip = (Read-Host 'IP:PUERTO de Depuracion inalambrica').Trim()
  if (-not (Test-Device $script:Ip)) {
    Write-Host 'No se pudo conectar. Verifica la IP, la red y Depuracion inalambrica.' -ForegroundColor Red
    return $false
  }
  Set-Content -Path $saved -Value $script:Ip -Encoding ascii
  Write-Host "Conectado a la tele ($script:Ip)" -ForegroundColor Green
  return $true
}

function Device([string[]]$Arguments) {
  & $script:Adb -s $script:Ip @Arguments
}

function Get-RemotePackages([string]$Command) {
  $result = Device @('shell', $Command) 2>$null
  return @($result | ForEach-Object { ($_ -replace '^package:', '').Trim() } | Where-Object { $_ })
}

function Save-DeviceState {
  $allPackages = Get-RemotePackages 'pm list packages'
  $disabledPackages = Get-RemotePackages 'pm list packages -d'
  $state = [ordered]@{
    ip = $script:Ip
    windowAnimation = ((Device @('shell', 'settings get global window_animation_scale')) | Out-String).Trim()
    transitionAnimation = ((Device @('shell', 'settings get global transition_animation_scale')) | Out-String).Trim()
    animatorDuration = ((Device @('shell', 'settings get global animator_duration_scale')) | Out-String).Trim()
    installed = @($allPackages)
    disabled = @($disabledPackages)
  }
  $state | ConvertTo-Json -Depth 4 | Set-Content -Path $script:StateFile -Encoding utf8
  Write-Host "Copia del estado guardada en: $script:StateFile"
}

function Install-Launcher {
  if (-not (Test-Path $script:Apk)) { throw "Falta el APK junto al script: $script:Apk`nExtrae el ZIP completo antes de ejecutarlo." }
  $result = (Device @('install', '-r', $script:Apk) 2>&1 | Out-String)
  Write-Host $result
  if ($result -notmatch 'Success') { throw 'La instalacion del inicio fallo.' }
  Device @('shell', 'pm grant com.mihir.tvhome android.permission.READ_EXTERNAL_STORAGE') | Out-Null
  Device @('shell', 'pm grant com.mihir.tvhome android.permission.WRITE_SECURE_SETTINGS') | Out-Null
  Device @('shell', 'pm grant com.mihir.tvhome android.permission.ACCESS_FINE_LOCATION') | Out-Null
}

function Confirm-Launcher {
  Device @('shell', "am start -n $script:HomeActivity") | Out-Null
  Start-Sleep -Seconds 4
  $answer = (Read-Host 'Mira la tele. Ves el reloj, el fondo y las aplicaciones? (s/n)').Trim().ToLowerInvariant()
  if ($answer -ne 's') {
    Device @('uninstall', $script:AppId) | Out-Null
    Device @('shell', 'input keyevent KEYCODE_HOME') | Out-Null
    Write-Host 'Se desinstalo el inicio nuevo; no se cambio el inicio predeterminado.'
    return $false
  }
  return $true
}

function Set-AppleHome {
  Device @('shell', "cmd package set-home-activity --user 0 $script:HomeActivity") | Out-Null
  Device @('shell', 'pm disable-user --user 0 com.google.android.tvlauncher') | Out-Null
  Device @('shell', 'pm disable-user --user 0 com.google.android.tungsten.setupwraith') | Out-Null
  Device @('shell', "cmd package set-home-activity --user 0 $script:HomeActivity") | Out-Null
  Device @('shell', "settings put secure screensaver_components $script:ScreenSaver") | Out-Null
  Device @('shell', 'settings put secure screensaver_enabled 1') | Out-Null
  Device @('shell', "cmd package compile -m speed -f $script:AppId") | Out-Null
  Device @('shell', 'input keyevent KEYCODE_HOME') | Out-Null
}

function Set-FasterAnimations {
  Device @('shell', 'settings put global window_animation_scale 0.5') | Out-Null
  Device @('shell', 'settings put global transition_animation_scale 0.5') | Out-Null
  Device @('shell', 'settings put global animator_duration_scale 0.5') | Out-Null
  Device @('shell', 'cmd package compile -m speed-profile -f com.mihir.tvhome') | Out-Null
  Device @('shell', 'pm trim-caches 512M') | Out-Null
}

function Disable-SelectedApps([switch]$Uninstall) {
  foreach ($package in $script:PackageList) {
    if ($Uninstall) {
      Device @('shell', "am force-stop $package") | Out-Null
      $result = (Device @('shell', "pm uninstall -k --user 0 $package") 2>&1 | Out-String).Trim()
    } else {
      $result = (Device @('shell', "pm disable-user --user 0 $package") 2>&1 | Out-String).Trim()
    }
    Write-Host "  $package -> $result"
  }
}

function Download-Wallpapers {
  Add-Type -AssemblyName System.Drawing
  $folder = Join-Path $script:DataDir 'fotos'
  New-Item -ItemType Directory -Force -Path $folder | Out-Null
  $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $parameters = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $parameters.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]82)
  $index = 0
  foreach ($name in $script:PhotoList) {
    $index++
    $output = Join-Path $folder ('{0:D2}.jpg' -f $index)
    if (Test-Path $output) { continue }
    $url = 'https://commons.wikimedia.org/wiki/Special:FilePath/' + [Uri]::EscapeDataString($name) + '?width=1920'
    $temp = Join-Path $folder 'tmp.jpg'
    $image = $null; $bitmap = $null; $graphics = $null
    try {
      Invoke-WebRequest $url -OutFile $temp -UserAgent 'TVCasaJulia/1.0' -UseBasicParsing
      $image = [System.Drawing.Image]::FromFile($temp)
      $width = 1280; $height = 720
      $ratio = [Math]::Max($width / $image.Width, $height / $image.Height)
      $sourceWidth = [int]($width / $ratio); $sourceHeight = [int]($height / $ratio)
      $sourceX = [int](($image.Width - $sourceWidth) / 2); $sourceY = [int](($image.Height - $sourceHeight) / 2)
      $bitmap = New-Object System.Drawing.Bitmap($width, $height)
      $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
      $graphics.InterpolationMode = 'HighQualityBicubic'
      $graphics.DrawImage($image, (New-Object System.Drawing.Rectangle(0, 0, $width, $height)), (New-Object System.Drawing.Rectangle($sourceX, $sourceY, $sourceWidth, $sourceHeight)), 'Pixel')
      $bitmap.Save($output, $codec, $parameters)
      Write-Host "  Descargada: $name"
    } catch {
      Write-Host "  No se pudo descargar: $name ($($_.Exception.Message))" -ForegroundColor Yellow
    } finally {
      if ($graphics) { $graphics.Dispose() }
      if ($bitmap) { $bitmap.Dispose() }
      if ($image) { $image.Dispose() }
      Remove-Item $temp -Force -ErrorAction SilentlyContinue
    }
  }
  return $folder
}

function Copy-WallpapersToTV([string]$Folder) {
  $destination = '/sdcard/Android/data/com.mihir.tvhome/files/wallpapers'
  Device @('shell', "mkdir -p $destination; rm -f $destination/*.jpg") | Out-Null
  Device @('push', "$Folder\.", "$destination/") | Out-Null
  $count = ((Device @('shell', "ls $destination 2>/dev/null | grep -c jpg")) | Out-String).Trim()
  if ($count -eq '0' -or -not $count) {
    $destination = '/sdcard/Pictures/InicioTV'
    Device @('shell', "mkdir -p $destination; rm -f $destination/*.jpg") | Out-Null
    Device @('push', "$Folder\.", "$destination/") | Out-Null
    $count = ((Device @('shell', "ls $destination 2>/dev/null | grep -c jpg")) | Out-String).Trim()
  }
  Write-Host "Fotos copiadas a la tele: $count"
}

function Apply-All {
  Write-Host 'Esta opcion cambia el inicio, desactiva/quita aplicaciones y ajusta animaciones.' -ForegroundColor Yellow
  if ((Read-Host 'Continuar? (s/n)').Trim().ToLowerInvariant() -ne 's') { return }
  Save-DeviceState
  Install-Launcher
  if (-not (Confirm-Launcher)) { return }
  Write-Host 'Ajustando inicio, animaciones y aplicaciones...'
  Set-AppleHome
  Set-FasterAnimations
  Disable-SelectedApps -Uninstall
  $folder = Download-Wallpapers
  Copy-WallpapersToTV $folder
  Device @('shell', 'input keyevent KEYCODE_HOME') | Out-Null
  Write-Host 'Configuracion completa. La copia para deshacer esta en la carpeta local del usuario.' -ForegroundColor Green
}

function Speed-Up {
  Save-DeviceState
  Set-FasterAnimations
  Disable-SelectedApps
  Device @('shell', 'am kill-all') | Out-Null
  Device @('reboot') | Out-Null
  Write-Host 'Cambios aplicados. La tele se reiniciara.' -ForegroundColor Green
}

function Restore-Changes {
  $state = $null
  if (Test-Path $script:StateFile) {
    try { $state = Get-Content $script:StateFile -Raw | ConvertFrom-Json } catch { }
  }
  if ($state -and $state.installed) {
    $disabled = @($state.disabled)
    foreach ($package in $script:PackageList) {
      if ($state.installed -contains $package) {
        Device @('shell', "cmd package install-existing --user 0 $package") | Out-Null
        if ($disabled -contains $package) { Device @('shell', "pm disable-user --user 0 $package") | Out-Null }
        else { Device @('shell', "pm enable $package") | Out-Null }
      } else {
        Device @('shell', "pm uninstall -k --user 0 $package") | Out-Null
      }
    }
    if ($state.windowAnimation -match '^\d+(\.\d+)?$') { Device @('shell', "settings put global window_animation_scale $($state.windowAnimation)") | Out-Null }
    if ($state.transitionAnimation -match '^\d+(\.\d+)?$') { Device @('shell', "settings put global transition_animation_scale $($state.transitionAnimation)") | Out-Null }
    if ($state.animatorDuration -match '^\d+(\.\d+)?$') { Device @('shell', "settings put global animator_duration_scale $($state.animatorDuration)") | Out-Null }
  } else {
    foreach ($package in $script:PackageList) {
      Device @('shell', "cmd package install-existing --user 0 $package") | Out-Null
      Device @('shell', "pm enable $package") | Out-Null
    }
    Device @('shell', 'settings put global window_animation_scale 1.0') | Out-Null
    Device @('shell', 'settings put global transition_animation_scale 1.0') | Out-Null
    Device @('shell', 'settings put global animator_duration_scale 0.6') | Out-Null
  }
  Device @('shell', 'pm enable com.google.android.tvlauncher') | Out-Null
  Device @('shell', 'pm enable com.google.android.tungsten.setupwraith') | Out-Null
  Device @('shell', 'cmd package set-home-activity --user 0 com.google.android.tvlauncher/.MainActivity') | Out-Null
  Device @('uninstall', $script:AppId) | Out-Null
  Device @('shell', 'input keyevent KEYCODE_HOME') | Out-Null
  Device @('reboot') | Out-Null
  Write-Host 'Restauracion solicitada. La tele se reiniciara.' -ForegroundColor Green
}

function Update-ScreenSaver {
  Install-Launcher
  Device @('shell', "settings put secure screensaver_components $script:ScreenSaver") | Out-Null
  Device @('shell', 'settings put secure screensaver_enabled 1') | Out-Null
  Device @('shell', 'input keyevent KEYCODE_HOME') | Out-Null
  Write-Host 'Salvapantallas actualizado.' -ForegroundColor Green
}

function Write-DeviceReport {
  $report = Join-Path $script:DataDir 'diagnostico.txt'
  $sections = @(
    @('modelo', 'getprop ro.product.model; getprop ro.product.manufacturer; getprop ro.build.version.release'),
    @('pantalla', 'wm size; wm density'),
    @('animaciones', 'settings get global window_animation_scale; settings get global transition_animation_scale; settings get global animator_duration_scale'),
    @('almacenamiento', 'df -h /data'),
    @('inicio actual', 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME'),
    @('apps desactivadas', 'pm list packages -d'),
    @('apps instaladas', 'pm list packages -3'),
    @('errores recientes', 'logcat -d -b crash -t 200')
  )
  foreach ($section in $sections) {
    "===== $($section[0]) =====" | Out-File $report -Append -Encoding utf8
    (Device @('shell', $section[1]) 2>&1 | Out-String) | Out-File $report -Append -Encoding utf8
  }
  Write-Host "Informe guardado en $report"
}

function Show-Menu {
  Clear-Host
  Write-Host 'freeTV_TCL' -ForegroundColor Cyan
  Write-Host 'Herramienta comunitaria no oficial para televisores TCL.'
  Write-Host "Tele conectada: $(if ($script:Ip) { $script:Ip } else { 'se preguntara al elegir una accion' })"
  Write-Host ''
  Write-Host '1. Aplicar configuracion completa'
  Write-Host '2. Acelerar la tele'
  Write-Host '3. Deshacer cambios'
  Write-Host '4. Instalar inicio estilo Apple'
  Write-Host '5. Volver al inicio de Google'
  Write-Host '6. Actualizar inicio y salvapantallas'
  Write-Host '7. Quitar aplicaciones seleccionadas'
  Write-Host '8. Crear diagnostico'
  Write-Host '9. Conectar y analizar sin cambiar la tele'
  Write-Host '0. Salir'
}

try {
  while ($true) {
    Show-Menu
    $choice = (Read-Host 'Elige una opcion').Trim()
    if ($choice -eq '0') { break }
    if ($choice -notin @('1','2','3','4','5','6','7','8','9')) { continue }
    try {
      if (-not (Connect-Device)) { Pause-Menu; continue }
      switch ($choice) {
        '1' { Apply-All }
        '2' { Speed-Up }
        '3' { Restore-Changes }
        '4' { Install-Launcher; if (Confirm-Launcher) { Set-AppleHome; Write-Host 'Inicio Apple activado.' -ForegroundColor Green } }
        '5' {
          Device @('shell', 'pm enable com.google.android.tvlauncher') | Out-Null
          Device @('shell', 'pm enable com.google.android.tungsten.setupwraith') | Out-Null
          Device @('shell', 'cmd package set-home-activity --user 0 com.google.android.tvlauncher/.MainActivity') | Out-Null
          Device @('uninstall', $script:AppId) | Out-Null
          Device @('shell', 'input keyevent KEYCODE_HOME') | Out-Null
          Write-Host 'Inicio de Google restaurado.'
        }
        '6' { Update-ScreenSaver }
        '7' { Save-DeviceState; Disable-SelectedApps -Uninstall; Write-Host 'Aplicaciones quitadas para el usuario actual.' }
        '8' { Write-DeviceReport }
        '9' { Write-DeviceReport; Write-Host 'Analisis terminado. No se hicieron cambios de configuracion.' }
      }
    } catch {
      Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Pause-Menu
  }
} finally {
  try { Stop-Transcript | Out-Null } catch { }
}