# Checa erros WHEA e eventos criticos do sistema (modo de falha tipico de CO agressivo)
# Uso: .\checar-whea.ps1 -Minutos 120
param(
  [int]$Minutos = 60
)
$ErrorActionPreference = "Continue"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "Pedindo elevacao (admin) - confirme o UAC..."
  Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"","-Minutos",$Minutos
  exit
}

Write-Host "=== uptime do boot atual ==="
$os = Get-CimInstance Win32_OperatingSystem
Write-Host ("boot: {0} | uptime: {1}" -f $os.LastBootUpTime, ((Get-Date) - $os.LastBootUpTime))

Write-Host ""
Write-Host "=== WHEA-Logger (ultimas $Minutos min) ==="
$w = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=(Get-Date).AddMinutes(-$Minutos)} -ErrorAction SilentlyContinue
if ($w) {
  $w | ForEach-Object { Write-Host ("WHEA: {0} id={1}" -f $_.TimeCreated, $_.Id) }
  Write-Host "=> Se o APIC ID do evento apontar um nucleo, alivie o offset DELE em 5 pontos (ou all-core)."
} else {
  Write-Host "nenhum WHEA"
}

Write-Host ""
Write-Host "=== Eventos criticos/erro (ultimas $Minutos min) ==="
$ev = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=(Get-Date).AddMinutes(-$Minutos)} -ErrorAction SilentlyContinue
if ($ev) {
  $ev | Select-Object -First 15 | ForEach-Object { Write-Host ("id={0} prov={1} {2}" -f $_.Id, $_.ProviderName, $_.TimeCreated.ToString('HH:mm:ss')) }
} else {
  Write-Host "nenhum evento critico"
}

Write-Host ""
Write-Host "=== Referencia rapida ==="
Write-Host "id=41  Kernel-Power  : maquina travou/rebootou sem shutdown limpo"
Write-Host "id=6008 EventLog     : shutdown inesperado"
Write-Host "id=18/19 WHEA-Logger : erro de hardware da CPU (offset CO agressivo demais)"
Write-Host "id=42/107 Kernel-Power : sleep/retomada (normal)"
