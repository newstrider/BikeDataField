$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$rootDir = (Resolve-Path "$scriptDir\..").Path
Set-Location $rootDir

Write-Host "Looking for Garmin watch (MTP Mode)..." -ForegroundColor Cyan

$shell = New-Object -ComObject Shell.Application
$computer = $shell.NameSpace(17) # 17 is ssfDRIVES (My Computer)

$garminDevice = $null
foreach ($item in $computer.Items()) {
    if ($item.Name -match "Forerunner" -or $item.Name -match "Garmin" -or $item.Name -match "fr165") {
        $garminDevice = $item
        break
    }
}

if ($null -eq $garminDevice) {
    Write-Host "Could not automatically detect the Garmin watch via MTP." -ForegroundColor Red
    Write-Host "Please ensure it's plugged in and you can open it in 'This PC' in Windows Explorer."
    Write-Host "Alternatively, you can manually copy 'bin\BikeDataField.prg' to the 'GARMIN\APPS' folder on your watch." -ForegroundColor Yellow
    Exit
}

Write-Host "Found device: $($garminDevice.Name)" -ForegroundColor Green
$garminFolder = $garminDevice.GetFolder()

# MTP structures usually look like: Garmin Forerunner X -> Primary/Internal Storage -> GARMIN -> APPS
$internalStorage = $null
foreach ($item in $garminFolder.Items()) {
    if ($item.Name -match "Primary" -or $item.Name -match "Internal") {
        $internalStorage = $item.GetFolder()
        break
    }
}

if ($null -eq $internalStorage) {
    $internalStorage = $garminFolder
}

$garminDir = $null
foreach ($item in $internalStorage.Items()) {
    if ($item.Name -match "GARMIN") {
        $garminDir = $item.GetFolder()
        break
    }
}

$appsDir = $null
if ($null -ne $garminDir) {
    foreach ($item in $garminDir.Items()) {
        if ($item.Name -match "APPS") {
            $appsDir = $item.GetFolder()
            break
        }
    }
}

if ($null -eq $appsDir) {
    Write-Host "Could not find the GARMIN\APPS folder structure inside the device." -ForegroundColor Red
    Write-Host "Please manually copy 'bin\BikeDataField.prg' to the 'GARMIN\APPS' folder on your watch." -ForegroundColor Yellow
    Exit
}

$prgPath = Join-Path $rootDir "bin\BikeDataField.prg"
if (-not (Test-Path $prgPath)) {
    Write-Host "Cannot find compiled app at $prgPath. Please run build.ps1 first." -ForegroundColor Yellow
    Exit
}

Write-Host "Transferring BikeDataField.prg to $($garminDevice.Name) -> GARMIN\APPS..." -ForegroundColor Cyan

# Windows Shell CopyHere
# Flags: 4 (No progress dialog) + 16 (Yes to all) = 20
try {
    $appsDir.CopyHere($prgPath, 20)
    Write-Host "Sideload complete! You can open the 'GARMIN/APPS' folder on your watch to verify if you want." -ForegroundColor Green
    Write-Host "You can safely disconnect your Forerunner 165 now."
} catch {
    Write-Host "There was an error copying the file system natively." -ForegroundColor Red
    Write-Host "Please open Windows Explorer and manually drag 'bin\BikeDataField.prg' into the watch's 'GARMIN\APPS' folder." -ForegroundColor Yellow
}
