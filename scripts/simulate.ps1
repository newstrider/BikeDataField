$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$rootDir = (Resolve-Path "$scriptDir\..").Path
Set-Location $rootDir

# Automatically inject the Garmin SDK into PATH if not found
if ((Get-Command monkeydo -ErrorAction SilentlyContinue) -eq $null) {
    $sdkBase = "$env:APPDATA\Garmin\ConnectIQ\Sdks"
    if (Test-Path $sdkBase) {
        $latestSdk = Get-ChildItem -Path $sdkBase -Directory | Sort-Object CreationTime -Descending | Select-Object -First 1
        if ($latestSdk) {
            $env:PATH += ";$($latestSdk.FullName)\bin"
            Write-Host "Automatically using SDK from: $($latestSdk.FullName)" -ForegroundColor DarkGray
        }
    }
}


$prgPath = Join-Path $rootDir "bin\BikeDataField.prg"
if (-not (Test-Path $prgPath)) {
    Write-Host "App not found. Please run build.ps1 first to compile the project." -ForegroundColor Yellow
    Exit
}

Write-Host "Starting Connect IQ Simulator... (If it isn't already open)" -ForegroundColor Cyan
Start-Process connectiq -NoNewWindow
Start-Sleep -Seconds 3

Write-Host "Launching BikeDataField on Simulator for device: fr165..." -ForegroundColor Cyan
monkeydo bin\BikeDataField.prg fr165
