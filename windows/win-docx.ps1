# Windows Native Docx text reader via System.IO.Compression
param(
    [Parameter(Mandatory=$true)]
    [string]$DocxPath
)

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $DocxPath).Path)
$entry = $zip.GetEntry("word/document.xml")
if ($entry) {
    $stream = $entry.Open()
    $reader = New-Object System.IO.StreamReader($stream)
    $xml = $reader.ReadToEnd()
    $reader.Close()
    $stream.Close()
    $zip.Dispose()
    # Strip XML tags
    $cleanText = $xml -replace '<[^>]+>', ' ' -replace '\s+', ' '
    Write-Output $cleanText.Trim()
} else {
    $zip.Dispose()
    Write-Error "Invalid docx structure: word/document.xml not found."
}
