# Windows Native Credential Manager via cmdkey
param(
    [Parameter(Mandatory=$true)]
    [string]$Action,
    [string]$Target = "",
    [string]$Username = "",
    [string]$Password = ""
)

if ($Action -eq "set") {
    cmdkey /generic:$Target /user:$Username /pass:$Password
    Write-Output "Stored credential in Windows Credential Manager: $Target ($Username)"
} elseif ($Action -eq "delete") {
    cmdkey /delete:$Target
    Write-Output "Deleted credential: $Target"
} elseif ($Action -eq "list") {
    cmdkey /list
}
