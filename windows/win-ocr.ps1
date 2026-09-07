# Windows Native OCR using WinRT Windows.Media.Ocr (Built into Windows 10 & 11)
param(
    [Parameter(Mandatory=$true)]
    [string]$ImagePath,
    [string]$Language = "en-US"
)

[Windows.Globalization.Language, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime] | Out-Null

$asyncOp = [Windows.Storage.StorageFile]::GetFileFromPathAsync((Resolve-Path $ImagePath).Path)
$file = $asyncOp.GetResults()
$stream = $file.OpenAsync([Windows.Storage.FileAccessMode]::Read).GetResults()
$decoder = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream).GetResults()
$bitmap = $decoder.GetSoftwareBitmapAsync().GetResults()

$ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new($Language))
if ($null -eq $ocrEngine) {
    $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
}

$result = $ocrEngine.RecognizeAsync($bitmap).GetResults()
Write-Output $result.Text
