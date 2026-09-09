# Registra a task elevada PBO-Runner (dispatcher)
$ErrorActionPreference = "Continue"
$out = "C:\Workspace\tools-pbo\task.txt"
try {
  $a = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Workspace\tools-pbo\exec.ps1"
  $p = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
  $s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
  Register-ScheduledTask -TaskName "PBO-Runner" -Action $a -Principal $p -Settings $s -Force
  "REGISTRADO OK" | Out-File $out
} catch {
  "ERRO: $($_.Exception.Message)" | Out-File $out
}
