# Windows Native Virus & Malware Scanner using built-in Windows Defender CLI (MpCmdRun.exe)
param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

$mpCmdRun = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
if (-not (Test-Path $mpCmdRun)) {
    $mpCmdRun = "$env:ProgramData\Microsoft\Windows Defender\Platform\*\MpCmdRun.exe"
    $mpCmdRun = (Get-ChildItem $mpCmdRun 2>$null | Select-Object -Last 1).FullName
}

if ($mpCmdRun -and (Test-Path $mpCmdRun)) {
    Write-Output "Scanning file with Windows Defender: $FilePath"
    $resolved = (Resolve-Path $FilePath).Path
    & $mpCmdRun -Scan -ScanType 3 -File $resolved -DisableRemediation
    if ($LASTEXITCODE -eq 0) {
        Write-Output "RESULT: CLEAN (No threats detected)"
    } else {
        Write-Warning "RESULT: THREAT DETECTED or Scan Error (Exit code: $LASTEXITCODE)"
    }
} else {
    Write-Error "Windows Defender MpCmdRun.exe not found."
}
