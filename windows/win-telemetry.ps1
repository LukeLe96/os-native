# Windows Host & Hardware Telemetry
Write-Output "=== WINDOWS HOST & SYSTEM TELEMETRY ==="
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

Write-Output "- Computer: $env:COMPUTERNAME"
Write-Output "- OS: $($os.Caption) (Version: $($os.Version), Build: $($os.BuildNumber))"
Write-Output "- CPU: $($cpu.Name)"
$totalMemMB = [math]::Round($os.TotalVisibleMemorySize / 1024)
$freeMemMB = [math]::Round($os.FreePhysicalMemory / 1024)
Write-Output "- Memory: Free ${freeMemMB}MB / Total ${totalMemMB}MB"
Write-Output "- Uptime: $((Get-Date) - $os.LastBootUpTime)"
