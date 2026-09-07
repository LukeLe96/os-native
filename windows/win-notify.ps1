# Windows Native Toast Notification via PowerShell
param(
    [string]$Title = "Tahi Agent",
    [string]$Message = "Task Completed"
)

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
$template = [Windows.UI.Notifications.ToastTemplateType]::ToastText02
$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($template)
$textNodes = $xml.GetElementsByTagName("text")
$textNodes.Item(0).AppendChild($xml.CreateTextNode($Title)) | Out-Null
$textNodes.Item(1).AppendChild($xml.CreateTextNode($Message)) | Out-Null

$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Tahi Agent").Show($toast)
Write-Output "Windows toast notification sent: [$Title] $Message"
