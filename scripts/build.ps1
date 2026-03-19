$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$rootDir = (Resolve-Path "$scriptDir\..").Path
Set-Location $rootDir

# Automatically inject the Garmin SDK into PATH if not found
if ((Get-Command monkeyc -ErrorAction SilentlyContinue) -eq $null) {
    $sdkBase = "$env:APPDATA\Garmin\ConnectIQ\Sdks"
    if (Test-Path $sdkBase) {
        $latestSdk = Get-ChildItem -Path $sdkBase -Directory | Sort-Object CreationTime -Descending | Select-Object -First 1
        if ($latestSdk) {
            $env:PATH += ";$($latestSdk.FullName)\bin"
            Write-Host "Automatically using SDK from: $($latestSdk.FullName)" -ForegroundColor DarkGray
        }
    }
}

Write-Host "Building BikeDataField for Forerunner 165 (fr165)..." -ForegroundColor Cyan
if (-not (Test-Path "bin")) {
    New-Item -ItemType Directory -Path "bin" | Out-Null
}

# Run the Monkey C compiler
monkeyc -d fr165 -f monkey.jungle -y developer_key -o bin\BikeDataField.prg --debug-log-level 3

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build successful! Application compiled to: bin\BikeDataField.prg" -ForegroundColor Green
} else {
    Write-Host "Build failed. Make sure you have the Connect IQ SDK configured and 'monkeyc' is available in your PATH." -ForegroundColor Red
}
