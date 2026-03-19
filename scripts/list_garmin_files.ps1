$shell = New-Object -ComObject Shell.Application
$computer = $shell.NameSpace(17) # My Computer

Write-Host "Searching for Garmin MTP devices..." -ForegroundColor Cyan

function ListItems($folder, $depth) {
    if ($depth -gt 4) { return }
    $indent = "  " * $depth
    foreach ($item in $folder.Items()) {
        Write-Host "$indent$($item.Name)" -ForegroundColor Gray
        if ($item.IsFolder) {
            ListItems($item.GetFolder(), ($depth + 1))
        }
    }
}

foreach ($item in $computer.Items()) {
    if ($item.Name -match "Forerunner" -or $item.Name -match "Garmin") {
        Write-Host "Found device: $($item.Name)" -ForegroundColor Green
        ListItems($item.GetFolder(), 0)
    }
}
