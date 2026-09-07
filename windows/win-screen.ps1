# Windows Native Screen Capture using .NET System.Drawing
param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,
    [string]$Rect = ""
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if ($Rect -ne "") {
    $parts = $Rect -split ","
    $x = [int]$parts[0]
    $y = [int]$parts[1]
    $w = [int]$parts[2]
    $h = [int]$parts[3]
    $bounds = [System.Drawing.Rectangle]::new($x, $y, $w, $h)
} else {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
}

$bmp = [System.Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)

$bmp.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bmp.Dispose()
Write-Output "Screenshot saved: $OutputPath"
