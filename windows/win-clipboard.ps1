# Windows Native Clipboard
param(
    [string]$Mode = "paste",
    [string]$Content = ""
)

if ($Mode -eq "copy") {
    Set-Clipboard -Value $Content
    Write-Output "Copied to Windows clipboard!"
} else {
    Get-Clipboard
}
