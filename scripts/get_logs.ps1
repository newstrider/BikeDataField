$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$rootDir = (Resolve-Path "$scriptDir\..").Path
Set-Location $rootDir

Write-Host "Searching for Garmin crash logs and debug outputs..." -ForegroundColor Cyan

$shell = New-Object -ComObject Shell.Application
$computer = $shell.NameSpace(17) # My Computer

$garminDevice = $null
foreach ($item in $computer.Items()) {
    if ($item.Name -match "Forerunner" -or $item.Name -match "Garmin") {
        $garminDevice = $item
        break
    }
}

if ($null -eq $garminDevice) {
    Write-Host "Could not detect Garmin watch via MTP." -ForegroundColor Red
    Exit
}

Write-Host "Found Device: $($garminDevice.Name)" -ForegroundColor Green

# Destination local folder
$localLogDir = Join-Path $rootDir "logs"
if (-not (Test-Path $localLogDir)) { New-Item -ItemType Directory -Path $localLogDir | Out-Null }
$localFolder = $shell.NameSpace($localLogDir)

$foundAny = $false

function SearchLogs($folder) {
    global $foundAny, $localFolder
    foreach ($item in $folder.Items()) {
        if ($item.Name -match "CIQ_LOG" -or $item.Name -match "ERR_LOG" -or ($item.Name -match ".TXT" -and $item.Size -gt 0) -or ($item.Name -match ".YML")) {
             Write-Host "Found possible log: $($item.Path)" -ForegroundColor Yellow
             $localFolder.CopyHere($item, 16) # 16 = Respond 'Yes to All'
             $foundAny = $true
        }
        if ($item.IsFolder) {
            SearchLogs($item.GetFolder())
        }
    }
}

# Start recursive search from device root
SearchLogs($garminDevice.GetFolder())

if ($foundAny) {
    Write-Host "Success! Logs copied to the '\logs' folder in your project." -ForegroundColor Green
} else {
    Write-Host "No log files found on the device." -ForegroundColor Red
}
