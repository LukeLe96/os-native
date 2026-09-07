# Windows Native TTS using System.Speech.Synthesis
param(
    [Parameter(Mandatory=$true)]
    [string]$Text,
    [string]$OutputFile = ""
)

Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

if ($OutputFile -ne "") {
    $synth.SetOutputToWaveFile($OutputFile)
    $synth.Speak($Text)
    $synth.Dispose()
    Write-Output "Generated audio file: $OutputFile"
} else {
    $synth.Speak($Text)
    $synth.Dispose()
}
